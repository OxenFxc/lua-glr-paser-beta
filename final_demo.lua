local GLR = require("GLR")

print("Initializing GLR Parser with Lua Grammar...")
local parser = GLR.create_lua_grammar()

print("Building Automaton...")
parser:build()

local input = [[
local function factorial(n)
    if n == 0 then
        return 1
    else
        return n * factorial(n - 1)
    end
end

local x = factorial(5)
]]

print("\nParsing input:")
print(input)

local success, result = pcall(function() return parser:parse(input) end)

if success and result and #result > 0 then
    print("\nParse Success!")
    print("Parse Tree:")
    parser:print_tree(result[#result])
else
    print("\nParse Failed!")
    if not success then print("Error: " .. tostring(result)) end
end
