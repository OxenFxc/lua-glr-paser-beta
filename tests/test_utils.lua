local Utils = require("utils.Utils")

local function assert_eq(actual, expected, message)
    if type(actual) == "table" and type(expected) == "table" then
        if not Utils.table_equals(actual, expected) then
            error(string.format("%s: tables not equal\nActual: %s\nExpected: %s",
                message or "Assertion failed", tostring(actual), tostring(expected)))
        end
    else
        if actual ~= expected then
            error(string.format("%s: %s ~= %s",
                message or "Assertion failed", tostring(actual), tostring(expected)))
        end
    end
end

local function test_deepcopy()
    print("Testing deepcopy...")

    -- Basic types
    assert_eq(Utils.deepcopy(1), 1)
    assert_eq(Utils.deepcopy("hi"), "hi")
    assert_eq(Utils.deepcopy(true), true)
    assert_eq(Utils.deepcopy(nil), nil)

    -- Simple table
    local t1 = {a = 1, b = 2}
    local c1 = Utils.deepcopy(t1)
    assert(t1 ~= c1)
    assert_eq(c1, t1)

    -- Nested table
    local t2 = {a = {b = 1, c = {d = 2}}}
    local c2 = Utils.deepcopy(t2)
    assert(t2 ~= c2)
    assert(t2.a ~= c2.a)
    assert(t2.a.c ~= c2.a.c)
    assert_eq(c2, t2)

    -- Metatable
    local mt = {__index = {z = 100}}
    local t3 = setmetatable({a = 1}, mt)
    local c3 = Utils.deepcopy(t3)
    assert(getmetatable(c3) ~= mt)
    assert_eq(getmetatable(c3), mt)
    assert_eq(c3.z, 100)

    -- Table keys
    local key = {k = 1}
    local t4 = {[key] = "value"}
    local c4 = Utils.deepcopy(t4)
    local c4_key = next(c4)
    assert(c4_key ~= key)
    assert_eq(c4_key, key)
    assert_eq(c4[c4_key], "value")

    print("deepcopy tests (without circular) passed!")
end

local function test_deepcopy_circular()
    print("Testing deepcopy with circular references...")
    local t = {name = "circular"}
    t.self = t

    local c = Utils.deepcopy(t)

    assert(c ~= t, "Copy should be a different reference")
    assert(c.self == c, "Circular reference should be preserved in copy")
    assert(c.name == "circular", "Values should be preserved")
    print("deepcopy circular tests passed!")
end

local function test_table_equals()
    print("Testing table_equals...")
    assert(Utils.table_equals({1, 2}, {1, 2}))
    assert(not Utils.table_equals({1, 2}, {1, 3}))
    assert(Utils.table_equals({a = 1, b = {c = 2}}, {a = 1, b = {c = 2}}))
    assert(not Utils.table_equals({a = 1, b = {c = 2}}, {a = 1, b = {c = 3}}))
    assert(not Utils.table_equals({1, 2}, {1, 2, 3}))
    print("table_equals tests passed!")
end

local function test_set_utils()
    print("Testing set utilities...")
    local list = {"a", "b", "c"}
    local set = Utils.list_to_set(list)
    assert(set.a and set.b and set.c)

    local back_list = Utils.set_to_list(set)
    assert_eq(#back_list, 3)
    assert_eq(back_list[1], "a")
    assert_eq(back_list[2], "b")
    assert_eq(back_list[3], "c")

    local set2 = {c = true, d = true}
    local merged = Utils.merge_sets(set, set2)
    assert(merged.a and merged.b and merged.c and merged.d)
    print("set utilities tests passed!")
end

local function test_string_utils()
    print("Testing string utilities...")
    assert_eq(Utils.trim_string("  hello  "), "hello")

    local parts = Utils.split_string("a,b,c", ",")
    assert_eq(#parts, 3)
    assert_eq(parts[1], "a")
    assert_eq(parts[2], "b")
    assert_eq(parts[3], "c")

    assert_eq(Utils.escape_string("a.b*c?"), "a%.b%*c%?")
    print("string utilities tests passed!")
end

local function test_other_utils()
    print("Testing other utilities...")
    assert_eq(Utils.format_number(1.2345, 2), "1.23")
    assert_eq(Utils.format_number(1, 2), "1.00")
    print("other utilities tests passed!")
end

-- Run all tests
local function run_all()
    test_table_equals()
    test_deepcopy()
    test_deepcopy_circular()
    test_set_utils()
    test_string_utils()
    test_other_utils()
    print("\nAll tests passed successfully!")
end

run_all()
