#!/bin/bash
set -e

# Clone Lua if not exists
if [ ! -d "tmp_lua" ]; then
    echo "Cloning Lua..."
    git clone https://github.com/lua/lua.git tmp_lua
fi

# Build Lua
echo "Building Lua..."
cd tmp_lua
make all
cd ..

# Run Parser Test
echo "Running Parser Test..."
./tmp_lua/lua run_parser.lua test_parser_features.lua

echo "Verification Successful!"
