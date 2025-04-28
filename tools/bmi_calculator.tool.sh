#!/usr/bin/env bash

# BMI Calculator tool implementation

# Calculate BMI function
calculate_bmi_impl() {
    local weight_kg=$1
    local height_m=$2

    # Use bc for floating point calculation
    local bmi=$(echo "scale=2; $weight_kg / ($height_m * $height_m)" | bc)
    echo "BMI calculation result: $bmi" | jq -Rsa .
}

# Register the tool with the server
register_tool \
    "calculate_bmi" \
    "Calculate BMI given weight in kg and height in meters" \
    "weight_kg:float,height_m:float" \
    "calculate_bmi_impl"
