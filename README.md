# LXC Agent

A Go-based agent for managing LXC (Linux Containers) using the go-lxc package.

## Features

- Container lifecycle management (create, start, stop, destroy)
- Container listing and information retrieval
- Thread-safe container operations
- Comprehensive error handling
- Unit tests included

## Prerequisites

- Go 1.21 or later
- LXC installed and configured on your system
- Proper permissions to manage LXC containers

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd lxc-agent
```

2. Install dependencies:
```bash
go mod tidy
```

3. Build the project:
```bash
go build -o lxc-agent ./cmd/main.go
```

## Usage

### Running the Agent

```bash
./lxc-agent
```

### Using the Agent Programmatically

```go
package main

import (
    "log"
    "lxc-agent/internal/agent"
)

func main() {
    // Create a new agent
    lxcAgent, err := agent.New()
    if err != nil {
        log.Fatal(err)
    }

    // List all containers
    containers, err := lxcAgent.ListContainers()
    if err != nil {
        log.Fatal(err)
    }

    // Create a new container
    err = lxcAgent.CreateContainer("my-container", "ubuntu")
    if err != nil {
        log.Fatal(err)
    }

    // Start the container
    err = lxcAgent.StartContainer("my-container")
    if err != nil {
        log.Fatal(err)
    }
}
```

## Project Structure

```
lxc-agent/
├── cmd/
│   └── main.go              # Application entry point
├── internal/
│   └── agent/
│       ├── agent.go         # Main agent implementation
│       └── agent_test.go    # Unit tests
├── pkg/
│   └── types/
│       └── types.go         # Common types and interfaces
├── .vscode/
│   └── launch.json          # VS Code debug configuration
├── go.mod                   # Go module file
├── go.sum                   # Go module checksums
├── .gitignore              # Git ignore file
└── README.md               # This file
```

## Development

### Running Tests

```bash
go test ./...
```

### Debugging

The project includes VS Code launch configurations for debugging:
- "Launch LXC Agent" - Debug the main application
- "Debug Tests" - Debug unit tests

### Code Style

This project follows standard Go conventions and uses:
- `gofmt` for code formatting
- `golint` for code linting
- `go vet` for code analysis

## API Reference

### Agent Methods

- `New() (*Agent, error)` - Create a new agent instance
- `Start() error` - Initialize and start the agent
- `ListContainers() ([]string, error)` - List all available containers
- `GetContainer(name string) (*lxc.Container, error)` - Get a container by name
- `CreateContainer(name, template string) error` - Create a new container
- `StartContainer(name string) error` - Start a container
- `StopContainer(name string) error` - Stop a container
- `DestroyContainer(name string) error` - Destroy a container

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Troubleshooting

### Common Issues

1. **Permission denied errors**: Ensure your user has proper permissions to manage LXC containers
2. **LXC not found**: Make sure LXC is properly installed and configured on your system
3. **Container creation fails**: Verify that the specified template is available

### Debug Mode

Run the agent with debug logging:
```bash
DEBUG=true ./lxc-agent
```

## Security Considerations

- The agent requires elevated privileges to manage LXC containers
- Always validate container names and configurations
- Consider implementing authentication for remote access
- Regularly update dependencies for security patches # lxc-agents-poc
