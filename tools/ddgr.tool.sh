#!/usr/bin/env bash

# DDGR Tool Implementation

# Addition function
ddgr_impl() {
    local query=$1
    # Calculate sum
    local output=$(ddgr --np -C -x $query)
    echo -n $output | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "duck_duck_go_searcher" \
    "searches with duck duck go search engine for a given query" \
    "query:string" \
    "ddgr_impl"
