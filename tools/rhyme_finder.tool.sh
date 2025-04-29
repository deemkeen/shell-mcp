#!/usr/bin/env bash

# function
rhyme_finder_impl() {
    local word=$1
    echo -n "https://rifme.net/r/$word/1" | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "rhyme_finder" \
    "Constructs an url, where you can find a rhyme to a given word" \
    "word:string" \
    "rhyme_finder_impl"
