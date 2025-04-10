#!/usr/bin/env bash

# Pokemon information fetcher tool implementation

# Fetch Pokemon function
fetch_pokemon_impl() {
    local pokemon_name=$1
    local output=""

    # Convert to lowercase for API compatibility
    pokemon_name=$(echo "$pokemon_name" | tr '[:upper:]' '[:lower:]')

    # Use curl to fetch Pokemon data and format with jq if available
    local pokemon_data
    pokemon_data=$(curl -s "https://pokeapi.co/api/v2/pokemon/$pokemon_name")

    # Check if jq is available for prettier output
    if command -v jq &>/dev/null; then
        # Extract the most relevant information into a single output string
        output="Fetching data for Pokemon: $pokemon_name\n"
        output+="Pokemon: $pokemon_name\n"
        output+="ID: $(echo "$pokemon_data" | jq -r '.id')\n"
        output+="Height: $(echo "$pokemon_data" | jq -r '.height')\n"
        output+="Weight: $(echo "$pokemon_data" | jq -r '.weight')\n"
        output+="Types: $(echo "$pokemon_data" | jq -r '.types[].type.name' | tr '\n' ', ' | sed 's/,$//')\n"
        output+="Abilities: $(echo "$pokemon_data" | jq -r '.abilities[].ability.name' | tr '\n' ', ' | sed 's/,$//')"
    else
        # If jq is not available, just return the raw JSON
        output="Fetching data for Pokemon: $pokemon_name\n$pokemon_data"
    fi

    # Output everything with a single echo statement
    echo "$output"
}

# Register the tool with the server
register_tool \
    "fetch_pokemon" \
    "Fetch information about a Pokemon by name" \
    "pokemon_name:str" \
    "fetch_pokemon_impl"
