#!/usr/bin/env bash

# Calculator tool implementation

# Addition function
addition_impl() {
    local num1=$1
    local num2=$2

    # Calculate sum
    local sum=$((num1 + num2))
    echo -n "sum of two numbers is $sum" | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "addition" \
    "addition of two numbers" \
    "num1:int,num2:int" \
    "addition_impl"
