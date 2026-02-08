-- Add local directories to package.path
package.path = package.path .. ";./?.lua;./core/?.lua;./utils/?.lua"

local GLR = require("GLR")

local grammar_type = "lua"
local input_file = nil
local output_file = nil

local valid_grammars = {lua=true, math=true, simple=true, programming=true}

if arg[3] then
    grammar_type = arg[1]
    input_file = arg[2]
    output_file = arg[3]
elseif arg[2] then
    if valid_grammars[arg[1]] then
        grammar_type = arg[1]
        input_file = arg[2]
    else
        input_file = arg[1]
        output_file = arg[2]
    end
elseif arg[1] then
    input_file = arg[1]
end

if not input_file then
    print("Usage: lua run_parser.lua [grammar_type] <input_file> [output_file]")
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

parser:set_verbose(false)

if not output_file then
    print("Building parser for grammar: " .. grammar_type)
end
parser:build()

if not output_file then
    print("Parsing input from: " .. input_file)
end
local success, result = pcall(function() return parser:parse(input) end)

if success then
    if result and #result > 0 then
        if output_file then
            local f = io.open(output_file, "w")
            if not f then
                print("Error: Could not open output file " .. output_file)
                os.exit(1)
            end
            f:write(parser:tree_to_string(result[1]))
            f:close()
            print("Parse Success! Output written to " .. output_file)
        else
            print("Parse Success!")
            parser:print_tree(result[1])
        end
    else
         print("Parse Failed: No parse tree generated.")
         os.exit(1)
    end
else
    print("Parse Error: " .. tostring(result))
    os.exit(1)
end
