//go:build linux

package main

import (
	sys_context "context"
	"flag"
	"fmt"
	"net/http"
	_ "net/http/pprof"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cjlapao/lxc-agent/internal/api"
	"github.com/cjlapao/lxc-agent/internal/auth"
	"github.com/cjlapao/lxc-agent/internal/cache"
	"github.com/cjlapao/lxc-agent/internal/caddy"
	"github.com/cjlapao/lxc-agent/internal/capsule"
	"github.com/cjlapao/lxc-agent/internal/config"
	"github.com/cjlapao/lxc-agent/internal/context"
	"github.com/cjlapao/lxc-agent/internal/database"
	"github.com/cjlapao/lxc-agent/internal/database/stores"
	"github.com/cjlapao/lxc-agent/internal/docker"
	"github.com/cjlapao/lxc-agent/internal/encryption"
	"github.com/cjlapao/lxc-agent/internal/events"
	"github.com/cjlapao/lxc-agent/internal/executor"
	"github.com/cjlapao/lxc-agent/internal/logging"
	"github.com/cjlapao/lxc-agent/internal/lxc"
	"github.com/cjlapao/lxc-agent/internal/message_processor"
	"github.com/cjlapao/lxc-agent/internal/validation"
	"github.com/cjlapao/lxc-agent/pkg/version"
)

// Version is set at build time via ldflags
var Version = "unknown"

const (
	// AppName is the name of the application
	AppName = "Container Agent"
)

func main() {
	// Initialize configuration service first
	if err := config.Initialize(); err != nil {
		fmt.Printf("Error initializing config: %v\n", err)
		os.Exit(1)
	}

	// Initialize logging service
	logging.Initialize()

	// Display startup banner with version information
	version.ShowStartupBanner(Version, AppName)

	logging.Info("Starting Container Agent...")

	// Define command line flags
	var (
		showVersion = flag.Bool("version", false, "Show version information")
		showHelp    = flag.Bool("help", false, "Show help information")
	)

	// Parse command line arguments
	flag.Parse()

	// Handle version flag
	if *showVersion {
		version.ShowVersionFlag(Version, AppName)
		os.Exit(0)
	}

	// Handle help flag
	if *showHelp {
		showUsage()
		os.Exit(0)
	}

	cfg := config.GetInstance().Get()

	// Initialize services
	if err := run(cfg); err != nil {
		logging.Errorf("Error: %v", err)
		os.Exit(1)
	}
}

// initializeDatabase initializes the database service
func initializeDatabase(cfg *config.Config) error {
	logging.Info("Initializing database service...")
	storagePath, err := config.GetInstance().GetStoragePath()
	if err != nil {
		return fmt.Errorf("failed to get storage path: %w", err)
	}
	var dbConfig database.Config
	if cfg.Get(config.DatabaseTypeKey).GetString() == "postgres" {
		dbConfig.Type = database.PostgreSQL
		dbConfig.Host = cfg.Get(config.DatabaseHostKey).GetString()
		dbConfig.Port = cfg.Get(config.DatabasePortKey).GetInt()
		dbConfig.Database = cfg.Get(config.DatabaseDatabaseKey).GetString()
		dbConfig.Username = cfg.Get(config.DatabaseUsernameKey).GetString()
		dbConfig.Password = cfg.Get(config.DatabasePasswordKey).GetString()
		dbConfig.SSLMode = cfg.Get(config.DatabaseSSLModeKey).GetBool()
		if dbConfig.Database == "" {
			return fmt.Errorf("database name is required")
		}
		if dbConfig.Username == "" {
			return fmt.Errorf("database username is required")
		}
		if dbConfig.Password == "" {
			return fmt.Errorf("database password is required")
		}
		if dbConfig.Host == "" {
			return fmt.Errorf("database host is required")
		}
		if dbConfig.Port == 0 {
			dbConfig.Port = 5432
		}
	} else {
		dbConfig.Type = database.SQLite
		dbConfig.StoragePath = storagePath

	}
	dbConfig.Debug = cfg.Get(config.DebugKey).GetBool()

	if err := database.Initialize(&dbConfig); err != nil {
		return fmt.Errorf("failed to initialize database: %w", err)
	}
	logging.Info("Database service initialized successfully")
	return nil
}

// initializeAuthStore initializes the auth store
func initializeAuthStore() (*stores.AuthDataStore, error) {
	logging.Info("Initializing auth store...")
	if err := stores.InitializeAuthDataStore(); err != nil {
		return nil, fmt.Errorf("failed to initialize auth store: %w", err)
	}
	logging.Info("Auth store initialized successfully")
	return stores.GetAuthDataStoreInstance(), nil
}

// initializeMessageStore initializes the message store
func initializeMessageStore() (*stores.MessageDataStore, error) {
	logging.Info("Initializing message store...")
	if err := stores.InitializeMessageDataStore(); err != nil {
		return nil, fmt.Errorf("failed to initialize message store: %w", err)
	}
	logging.Info("Message store initialized successfully")
	return stores.GetMessageDataStoreInstance(), nil
}

// initializeCapsuleStore initializes the capsule store
func initializeCapsuleStore() (*stores.CapsuleDataStore, error) {
	logging.Info("Initializing capsule store...")
	if err := stores.InitializeCapsuleDataStore(); err != nil {
		return nil, fmt.Errorf("failed to initialize capsule store: %w", err)
	}
	logging.Info("Capsule store initialized successfully")
	return stores.GetCapsuleDataStoreInstance(), nil
}

// initializeValidationService initializes the validation service
func initializeValidationService() {
	logging.Info("Initializing validation service...")
	validation.Initialize()
	logging.Info("Validation service initialized successfully")
}

// initializeCacheService initializes the cache service
func initializeCacheService() error {
	logging.Info("Initializing cache service...")
	if err := cache.Initialize(cache.Config{
		CleanupInterval: 5 * time.Minute,
	}); err != nil {
		return fmt.Errorf("failed to initialize cache service: %w", err)
	}
	logging.Info("Cache service initialized successfully")
	return nil
}

// initializeMessageProcessorService initializes the message processor service
func initializeMessageProcessorService(store *stores.MessageDataStore) (*message_processor.MessageProcessorService, error) {
	logging.Info("Initializing message processor service...")
	svc, err := message_processor.Initialize(store)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize message processor service: %w", err)
	}

	logging.Info("Message processor service initialized successfully")
	return svc, nil
}

// initializeEncryptionService initializes the encryption service
func initializeEncryptionService(cfg *config.Config) error {
	logging.Info("Initializing encryption service...")
	if err := encryption.Initialize(encryption.Config{
		MasterSecret: cfg.Get(config.EncryptionMasterSecretKey).GetString(),
		GlobalSecret: cfg.Get(config.EncryptionGlobalSecretKey).GetString(),
	}); err != nil {
		return fmt.Errorf("failed to initialize encryption service: %w", err)
	}
	logging.Info("Encryption service initialized successfully")
	return nil
}

// initializeAuthService initializes the auth service
func initializeAuthService(cfg *config.Config, authDataStore *stores.AuthDataStore) auth.Service {
	logging.Info("Initializing auth service...")

	authService := auth.NewService(auth.Config{
		SecretKey: cfg.Get(config.JwtAuthSecretKey).GetString(),
	}, authDataStore)
	logging.Info("Auth service initialized successfully")
	return authService
}

// initializeAPIServer initializes the API server
func initializeAPIServer(cfg *config.Config, authService auth.Service) (*api.Server, error) {
	logging.Info("Initializing API server...")
	server := api.NewServer(api.Config{
		Port:           cfg.Get(config.ServerAPIPortKey).GetInt(),
		Hostname:       cfg.Get(config.ServerBindAddressKey).GetString(),
		Prefix:         cfg.Get(config.ServerAPIPrefixKey).GetString(),
		AuthMiddleware: auth.NewRequireAuthMiddleware(authService),
	}, nil)
	logging.Info("API server initialized successfully")
	return server, nil
}

// initializeEventService initializes the event service for real-time notifications
func initializeEventService() error {
	logging.Info("Initializing event service singleton...")
	events.Initialize() // Initialize the singleton
	logging.Info("Event service singleton initialized successfully")
	return nil
}

// startEventService starts the event service in the background
func startEventService(ctx *context.ApiContext) error {
	logging.Info("Starting event service...")
	eventService := events.GetGlobalService()
	if err := eventService.Start(ctx); err != nil {
		return fmt.Errorf("failed to start event service: %w", err)
	}
	logging.Info("Event service started successfully")
	return nil
}

// initializeLxcService initializes the LXC service
func initializeLxcService() (*lxc.LxcService, error) {
	logging.Info("Initializing LXC service...")
	lxcService, err := lxc.Initialize()
	if err != nil {
		return nil, fmt.Errorf("failed to initialize LXC service: %w", err)
	}
	logging.Info("LXC service initialized successfully")
	return lxcService, nil
}

// initializeDockerService initializes the Docker service
func initializeDockerService() (*docker.DockerService, error) {
	logging.Info("Initializing Docker service...")
	dockerService, err := docker.Initialize()
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Docker service: %w", err)
	}
	logging.Info("Docker service initialized successfully")
	return dockerService, nil
}

// initializeCapsuleClientService initializes the client service
func initializeCapsuleClientService(dockerService *docker.DockerService, lxcService *lxc.LxcService, capsuleStore *stores.CapsuleDataStore) (*capsule.ClientService, error) {
	logging.Info("Initializing client service...")
	clientService, err := capsule.Initialize(dockerService, lxcService, capsuleStore)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize client service: %w", err)
	}
	logging.Info("Client service initialized successfully")
	return clientService, nil
}

// initializeCaddyService initializes the caddy service
func initializeCaddyService() (caddy.Service, error) {
	logging.Info("Initializing caddy service...")
	err := caddy.Initialize(caddy.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize caddy service: %w", err)
	}
	logging.Info("Caddy service initialized successfully")
	return caddy.GetInstance(), nil
}

func run(cfg *config.Config) error {
	logging.Info("Initializing application...")

	// Start memory profiling server for debugging
	if cfg.Get(config.DebugKey).GetBool() {
		go func() {
			logging.Info("Starting memory profiling server on :6060")
			pprofServer := &http.Server{
				Addr:           ":6060",
				Handler:        nil, // Use default mux for pprof
				ReadTimeout:    30 * time.Second,
				WriteTimeout:   30 * time.Second,
				IdleTimeout:    60 * time.Second,
				MaxHeaderBytes: 1 << 20, // 1MB
			}
			if err := pprofServer.ListenAndServe(); err != nil {
				logging.WithError(err).Error("Failed to start profiling server")
			}
		}()
	}

	if err := initializeEncryptionService(cfg); err != nil {
		return err
	}

	// Initializing database services
	if err := initializeDatabase(cfg); err != nil {
		return err
	}

	authDataStore, err := initializeAuthStore()
	if err != nil {
		return err
	}

	capsuleStore, err := initializeCapsuleStore()
	if err != nil {
		return err
	}

	messageDataStore, err := initializeMessageStore()
	if err != nil {
		return err
	}

	initializeValidationService()

	if err := initializeCacheService(); err != nil {
		return err
	}

	// Initialize event service singleton
	if err := initializeEventService(); err != nil {
		return err
	}

	// Initialize message processor service
	messageProcessorService, err := initializeMessageProcessorService(messageDataStore)
	if err != nil {
		return err
	}

	// Initialize auth service
	authService := initializeAuthService(cfg, authDataStore)

	// Initialize LXC service
	lxcService, err := initializeLxcService()
	if err != nil {
		return err
	}

	// Initialize Docker service
	dockerService, err := initializeDockerService()
	if err != nil {
		return err
	}

	// Initialize caddy service
	_, err = initializeCaddyService()
	if err != nil {
		return err
	}

	// Initialize API server
	server, err := initializeAPIServer(cfg, authService)
	if err != nil {
		return err
	}

	logging.Info("Registering routes...")
	// Register health check routes
	server.RegisterRoutes(api.NewHandler())
	// Register auth routes
	server.RegisterRoutes(auth.NewApiHandler(authService, authDataStore))
	// Register event routes using the global singleton
	server.RegisterRoutes(events.NewApiHandler(events.GetGlobalService(), authService))
	// Register LXC routes
	server.RegisterRoutes(lxc.NewApiHandler(lxcService))
	// Register message routes
	server.RegisterRoutes(message_processor.NewApiHandler(message_processor.GetInstance()))
	// Register Docker routes
	server.RegisterRoutes(docker.NewApiHandler(dockerService))
	// Register capsule routes
	server.RegisterRoutes(capsule.NewCapsuleApiHandler(capsuleStore, dockerService, lxcService))
	backgroundCtx := sys_context.Background()
	ctx := context.New(backgroundCtx)
	// Start event service
	if err := startEventService(ctx); err != nil {
		return err
	}

	systemInfo := executor.NewSystemInfo(executor.NewExecutor())
	networkIP, err := systemInfo.GetNetworkIP(backgroundCtx)
	if err != nil {
		return err
	}
	cfg.Set(config.NetworkIPKey, networkIP)
	logging.Infof("Network IP: %s", cfg.Get(config.NetworkIPKey).GetString())

	// TODO: Create initial test messages if in debug mode
	// if cfg.Get(config.DebugKey).GetBool() {
	//
	// }

	// TODO: Seed demo data
	// if cfg.Get(config.SeedDemoDataKey).GetBool() {
	//
	// }

	// Registering workers
	messageProcessorService.RegisterWorker(ctx, message_processor.NewEmailWorker())
	messageProcessorService.RegisterWorker(ctx, message_processor.NewNotificationWorker())
	messageProcessorService.RegisterWorker(ctx, capsule.NewInstallCapsuleWorker(dockerService, lxcService, capsuleStore))
	messageProcessorService.Start(ctx)

	// Registering Capsule client service
	clientService, err := initializeCapsuleClientService(dockerService, lxcService, capsuleStore)
	if err != nil {
		return err
	}
	clientService.StartMonitoring(ctx)

	// Initialize and start stats monitor service
	statsMonitor, err := capsule.InitializeStatsMonitor(dockerService, lxcService, capsuleStore)
	if err != nil {
		return err
	}

	// Get stats configuration
	statsInterval := config.GetInstance().Get().GetInt("stats.interval_seconds", 1)

	statsMonitor.Start(ctx, capsule.StatsMonitorConfig{
		Interval:    time.Duration(statsInterval) * time.Second,
		MonitorType: capsule.MonitorTypeCapsule,
	})

	// Start server in a goroutine
	go func() {
		if err := server.Start(); err != nil {
			logging.Errorf("Server error: %v", err)
		}
	}()

	logging.Info("All services started successfully")

	// Wait for interrupt signal
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	// Shutdown gracefully
	logging.Info("Shutting down gracefully...")
	shutdownCtx, cancel := sys_context.WithTimeout(backgroundCtx, 30*time.Second)
	defer cancel()

	// Stop event service
	logging.Info("Stopping event service...")
	if err := events.GetGlobalService().Stop(); err != nil {
		logging.Errorf("Error stopping event service: %v", err)
	} else {
		logging.Info("Event service stopped successfully")
	}

	// Stop API server
	logging.Info("Stopping API server...")
	if err := server.Stop(shutdownCtx); err != nil {
		logging.Errorf("Error shutting down server: %v", err)
		return fmt.Errorf("error shutting down server: %w", err)
	}

	logging.Info("Application shutdown completed successfully")
	return nil
}

func showUsage() {
	fmt.Printf("%s - A command line tool for container management\n\n", AppName)
	fmt.Println("Usage:")
	fmt.Printf("  %s [options]\n\n", AppName)
	fmt.Println("Options:")
	fmt.Println("  --help              Show this help message")
	fmt.Println("  --version           Show version information")
	fmt.Println("  --config <path>     Path to configuration file (JSON or YAML)")
	fmt.Println("  --port <port>       Port to run the API server on")
	fmt.Println("  --hostname <host>   Hostname to run the API server on")
	fmt.Println()
	fmt.Println("Environment variables:")
	fmt.Println()
	fmt.Println("Configuration file formats supported: JSON, YAML")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Printf("  %s --version\n", AppName)
	fmt.Printf("  %s --config config.yaml\n", AppName)
	fmt.Printf("  %s --username admin --password secret\n", AppName)
}
