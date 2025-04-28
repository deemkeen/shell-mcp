#!/usr/bin/env bash

# uses git with provided parameters implementation

# git_cli function
git_cli_impl() {
    local params=$1

    # Implement your tool logic here
    # It is only possible to use one "echo" at the end of the function
    local output=$(git $params)
    echo -n "$output" | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "git_cli" \
    "uses git with provided parameters" \
    "params:string" \
    "git_cli_impl"
