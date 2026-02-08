local GLR = require("GLR")

local parser = GLR.create_lua_grammar()
parser:build()

local input = [[
global x = 10
]]

print("Parsing input:")
print(input)

local success, result = pcall(function() return parser:parse(input) end)

if success then
    print("Success")
else
    print("Failed: " .. tostring(result))
end
