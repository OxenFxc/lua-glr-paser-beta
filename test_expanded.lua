local t = {1, 2, 3}
local t2 = {key = "value", ["key2"] = 123}

for i = 1, 10 do
    print(i)
end

for k, v in pairs(t) do
    print(k, v)
end

repeat
    print("hello")
until true

print(#t)
print("a" .. "b")

local function foo()
    return true and false or nil
end

foo() -- call as statement
