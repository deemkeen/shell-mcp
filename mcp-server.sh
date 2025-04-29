#!/usr/bin/env bash

# Shell MCP Server PoC implementation

# Server configuration
APP_NAME="Shell MCP"
SERVER_VERSION="1.0.0"
PROTOCOL_VERSION="2024-11-05"

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
LOG_FILE="$SCRIPT_DIR/mcp_server.log"

# Logging function
log_request() {
    echo "$(date '+%Y/%m/%d %H:%M:%S.%N' | cut -c1-26) $*" >> "$LOG_FILE"
}

# Function to create a new tool
create_new_tool() {
    local tool_name="$1"
    local tool_description="$2"
    local tool_parameters="$3"

    # Create the file path
    local tool_file="$TOOLS_DIR/${tool_name}.tool.sh"

    # Check if the file already exists
    if [ -f "$tool_file" ]; then
        echo "Error: Tool '$tool_name' already exists at $tool_file"
        return 1
    fi

    # Create function name (remove any non-alphanumeric characters and append _impl)
    local function_name="${tool_name//[^a-zA-Z0-9_]/_}_impl"

    # Create parameter variables for the implementation function
    local param_vars=""
    local param_assignments=""
    local counter=1

    IFS=',' read -ra param_array <<< "$tool_parameters"
    for param in "${param_array[@]}"; do
        # Parse parameter name and type (name:type format)
        local param_name=${param%%:*}
        local param_type=${param#*:}

        if [ $counter -gt 1 ]; then
            param_vars="$param_vars, "
        fi
        param_vars="$param_vars\$$counter"

        param_assignments="$param_assignments
    local $param_name=\$$counter"

        counter=$((counter + 1))
    done

    # Create the tool file
    cat > "$tool_file" << EOF
#!/usr/bin/env bash

# $tool_description implementation

# $tool_name function
$function_name() {$param_assignments

    # Implement your tool logic here
    # It is only possible to use one "echo" at the end of the function
    echo "Tool '$tool_name' was called with parameters: $param_vars"
}

# Register the tool with the server
register_tool \\
    "$tool_name" \\
    "$tool_description" \\
    "$tool_parameters" \\
    "$function_name"
EOF

    # Make the file executable
    chmod +x "$tool_file"

    echo "Successfully created new tool: $tool_file"
    return 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --add-tool)
                if [[ $# -lt 4 ]]; then
                    echo "Error: --add-tool requires NAME, DESCRIPTION, and PARAMETERS arguments"
                    echo "Usage: $0 --add-tool NAME DESCRIPTION PARAMETERS"
                    echo "Example: $0 --add-tool calculator \"A simple calculator\" \"num1:int,num2:int\""
                    exit 1
                fi
                create_new_tool "$2" "$3" "$4"
                exit $?
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --add-tool NAME DESCRIPTION PARAMETERS   Create a new tool"
                echo "  --help, -h                               Show this help message"
                echo ""
                echo "Without options, the MCP server will start normally."
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
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
    echo "{\"content\":[{\"type\":\"text\",\"text\":"$result"}],\"isError\":false}"
}

# Main server loop
main() {

    local temp_dir=$(mktemp -d)
    cd "${temp_dir}"

    # Parse command-line arguments if any
    parse_arguments "$@"

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
main "$@"
