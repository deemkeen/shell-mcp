# Shell MCP (Model Control Protocol)

A lightweight Bash implementation of an MCP server that allows creating and using custom command-line tools via a JSON-RPC interface.

## Overview

Shell MCP provides a simple framework to create, manage, and use custom command-line tools. The server loads tools from the `tools` directory and makes them available through a standardized interface.

## Getting Started

### Running the Server

To start the MCP server with the default configuration:

```bash
./mcp-server.sh
```

The server will load all tools from the `tools` directory and begin listening for commands via stdin.

## Adding New Tools

Shell MCP includes a CLI option to easily create new tools.

### Command Line Options

```bash
# Create a new tool
./mcp-server.sh --add-tool NAME DESCRIPTION "PARAM1:TYPE,PARAM2:TYPE"

# Show help information
./mcp-server.sh --help
```

### Example: Creating a New Tool

```bash
# Create a new multiplication tool
./mcp-server.sh --add-tool multiply "Multiplies two numbers" "num1:int,num2:int"
```

This will generate a new tool file at `tools/multiply.tool.sh` with a basic implementation template.

### Contributing Your Own Tools

We welcome contributions from the community! You can create your own general-purpose tools and submit them as pull requests.

Guidelines for contributing tools:

1. Tools should be general-purpose and useful to a wide audience
2. Follow the existing pattern for tool implementation
3. Include clear documentation within your tool file
4. Make sure your tool works correctly before submitting
5. Submit a pull request with your tool added to the `tools` directory

### Tool Structure

Each tool consists of:

1. A function that implements the tool's logic
2. A call to `register_tool` to make the tool available to the server

Here's an example of a simple tool implementation:

```bash
#!/usr/bin/env bash

# Addition tool implementation

# Function that performs the addition
addition_impl() {
    local num1=$1
    local num2=$2
    
    # Calculate the sum
    local sum=$((num1 + num2))
    echo "sum of two numbers is $sum"
}

# Register the tool with the server
register_tool \
    "addition" \
    "addition of two numbers" \
    "num1:int,num2:int" \
    "addition_impl"
```

## Important Notes for Tool Development

1. Each tool function should accept parameters in the order they are defined
2. Tools must use a single `echo` statement at the end to return their result
3. Parameter types are for documentation only - all parameters are passed as strings
4. Make the tool file executable with `chmod +x` after creating it manually

## Project Structure

```
shell-mcp/
├── mcp-server.sh       # Main server script
├── tools/              # Directory containing all tools
│   ├── addition.tool.sh    # Example tool
│   ├── bmi_calculator.tool.sh  # Example tool
│   └── pokemon_fetcher.tool.sh # Example tool
└── mcp_server.log     # Server log file (created when server runs)
```

## Protocol

The server implements a simplified JSON-RPC interface with the following methods:

- `initialize`: Initializes the server and returns its capabilities
- `tools/list`: Lists all available tools with their descriptions and parameters
- `tools/call`: Calls a specific tool with the provided arguments
- `resources/list`: Lists available resources (not implemented)
- `prompts/list`: Lists available prompts (not implemented)

## Requirements

- Bash 4.0 or higher
- `jq` for JSON processing

## License

This project is open source and available under the MIT License.