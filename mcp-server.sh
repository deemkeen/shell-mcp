#!/usr/bin/env bash

# Shell MCP Server PoC implementation

# Server configuration
APP_NAME="Shell MCP"
SERVER_VERSION="1.0.0"
PROTOCOL_VERSION="2024-11-05"
LOG_FILE="mcp_server.log"

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"

# Logging function
log_request() {
    echo "$(date '+%Y/%m/%d %H:%M:%S.%N' | cut -c1-26) $*" >> "$LOG_FILE"
}

# Tool registry
declare -A TOOLS
declare -A TOOL_DESCRIPTIONS
declare -A TOOL_PARAMETERS

# Load all tools from tools directory
load_tools() {
    echo "Loading tools from $TOOLS_DIR" >> "$LOG_FILE"

    # Find all .tool.sh files in the tools directory
    for tool_file in "$TOOLS_DIR"/*.tool.sh; do
        if [ -f "$tool_file" ]; then
            echo "Loading tool: $tool_file" >> "$LOG_FILE"
            source "$tool_file"
        fi
    done

    echo "Loaded ${#TOOLS[@]} tools" >> "$LOG_FILE"
}

# Register a tool with the server
register_tool() {
    local name="$1"
    local description="$2"
    local parameters="$3"
    local implementation="$4"

    TOOLS["$name"]="$implementation"
    TOOL_DESCRIPTIONS["$name"]="$description"
    TOOL_PARAMETERS["$name"]="$parameters"

    echo "Registered tool: $name" >> "$LOG_FILE"
}

# Build JSON schema for a tool
build_tool_schema() {
    local parameters="$1"
    local properties="{}"
    local required="[]"

    if [ -n "$parameters" ]; then
        properties="{"
        required="["

        IFS=',' read -ra param_array <<< "$parameters"
        local first_prop=true
        local first_req=true

        for param in "${param_array[@]}"; do
            # Parse parameter name and type (name:type format)
            local param_name=${param%%:*}
            local param_type=${param#*:}

            # Add to properties
            if [ "$first_prop" = "false" ]; then
                properties="$properties,"
            else
                first_prop=false
            fi

            properties="$properties\"$param_name\":{\"title\":\"${param_name^}\",\"type\":\"string\"}"

            # Add to required
            if [ "$first_req" = "false" ]; then
                required="$required,"
            else
                first_req=false
            fi

            required="$required\"$param_name\""
        done

        properties="$properties}"
        required="$required]"
    fi

    echo "{\"properties\":$properties,\"required\":$required,\"type\":\"object\"}"
}

# Execute a tool
execute_tool() {
    local tool_name="$1"
    local arguments="$2"

    # Check if tool exists
    if [[ ! -v TOOLS["$tool_name"] ]]; then
        return 1
    fi

    # Get tool information
    local implementation="${TOOLS[$tool_name]}"
    local parameters="${TOOL_PARAMETERS[$tool_name]}"

    # Parse arguments from JSON
    local args=()
    IFS=',' read -ra param_array <<< "$parameters"

    for param in "${param_array[@]}"; do
        # Get parameter name (before colon)
        local param_name=${param%%:*}

        # Extract value from arguments JSON using jq
        local value=$(echo "$arguments" | jq -r ".$param_name" 2>/dev/null)

        # Add to arguments array
        args+=("$value")
    done

    # Execute the tool
    local result
    result=$($implementation "${args[@]}")

    # Return result in the required format
    echo "{\"content\":[{\"type\":\"text\",\"text\":\"\n $result\"}],\"isError\":false}"
}

# Main server loop
main() {
    echo "Starting MCP Server: $APP_NAME" >> "$LOG_FILE"

    # Load all tools
    load_tools

    # Process input from stdin
    while read -r line; do
        # Log the request
        log_request "Received request: $line"

        # Parse JSON input
        method=$(echo "$line" | jq -r '.method' 2>/dev/null)
        id=$(echo "$line" | jq -r '.id' 2>/dev/null)

        # Process based on method
        if [[ "$method" == "initialize" ]]; then
            response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"protocolVersion\":\"$PROTOCOL_VERSION\",\"capabilities\":{\"experimental\":{},\"prompts\":{\"listChanged\":false},\"resources\":{\"subscribe\":false,\"listChanged\":false},\"tools\":{\"listChanged\":false}},\"serverInfo\":{\"name\":\"$APP_NAME\",\"version\":\"$SERVER_VERSION\"}}}"

        elif [[ "$method" == "notifications/initialized" ]]; then
            # No response needed for notification
            continue

        elif [[ "$method" == "tools/list" ]]; then
            # Build tools array
            local tools_json="["
            local first=true

            for tool in "${!TOOLS[@]}"; do
                if [ "$first" = false ]; then
                    tools_json="$tools_json,"
                else
                    first=false
                fi

                # Build schema for this tool
                local schema=$(build_tool_schema "${TOOL_PARAMETERS[$tool]}")

                tools_json="$tools_json{\"name\":\"$tool\",\"description\":\"${TOOL_DESCRIPTIONS[$tool]}\",\"inputSchema\":$schema}"
            done

            tools_json="$tools_json]"
            response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"tools\":$tools_json}}"

        elif [[ "$method" == "resources/list" ]]; then
            response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resources\":[]}}"

        elif [[ "$method" == "prompts/list" ]]; then
            response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"prompts\":[]}}"

        elif [[ "$method" == "tools/call" ]]; then
            # Extract tool name and arguments
            tool_name=$(echo "$line" | jq -r '.params.name' 2>/dev/null)
            arguments=$(echo "$line" | jq -r '.params.arguments' 2>/dev/null)

            if [[ -v TOOLS["$tool_name"] ]]; then
                result=$(execute_tool "$tool_name" "$arguments")
                response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":$result}"
            else
                response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32601,\"message\":\"Tool not found: $tool_name\"}}"
            fi

        else
            # Method not found
            response="{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}"
        fi

        # Log and send the response
        if [ -n "$response" ]; then
            log_request "Sending response: $response"
            echo "$response"
        fi
    done
}

# Run the server
main
