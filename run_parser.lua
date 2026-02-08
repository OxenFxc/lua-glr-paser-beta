-- Add local directories to package.path
package.path = package.path .. ";./?.lua;./core/?.lua;./utils/?.lua"

local GLR = require("GLR")

local arg1 = arg[1]
local arg2 = arg[2]

local grammar_type = "lua"
local input_file = nil

if arg2 then
    grammar_type = arg1
    input_file = arg2
elseif arg1 then
    -- Assume it's the input file, default grammar to lua
    input_file = arg1
else
    print("Usage: lua run_parser.lua [grammar_type] <input_file>")
    os.exit(1)
end

-- Read input file
local f = io.open(input_file, "r")
if not f then
    print("Error: Could not open file " .. input_file)
    os.exit(1)
end
local input = f:read("*a")
f:close()

local parser
if grammar_type == "lua" then
    parser = GLR.create_lua_grammar()
elseif grammar_type == "math" then
    parser = GLR.create_math_grammar()
elseif grammar_type == "simple" then
    parser = GLR.create_simple_grammar()
elseif grammar_type == "programming" then
    parser = GLR.create_programming_grammar()
else
    print("Error: Unknown grammar type " .. grammar_type)
    os.exit(1)
end

print("Building parser for grammar: " .. grammar_type)
parser:build()

print("Parsing input from: " .. input_file)
local success, result = pcall(function() return parser:parse(input) end)

if success then
    if result and #result > 0 then
        print("Parse Success!")
        parser:print_tree(result[1])
    else
         print("Parse Failed: No parse tree generated.")
         os.exit(1)
    end
else
    print("Parse Error: " .. tostring(result))
    os.exit(1)
end
