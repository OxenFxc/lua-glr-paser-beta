local GLR = require("GLR")
local parser = GLR.create_math_grammar()
parser:build()
local input = "1 + 2 * 3"
local result = parser:parse(input)
if result then
    local output = parser:render(result[1])
    print("Input: " .. input)
    print("Output: " .. output)
else
    print("Parse failed")
end
