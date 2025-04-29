#!/usr/bin/env bash

# read_website implementation

# read_website function
read_website_impl() {
    local url=$1
    crwl "$url" -o md-fit | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "read_website" \
    "Reads contents of a website by a given url" \
    "url:string" \
    "read_website_impl"
