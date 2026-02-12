-- Utils.lua
-- 工具函数模块

local Utils = {}

function Utils.deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[Utils.deepcopy(orig_key, copies)] = Utils.deepcopy(orig_value, copies)
            end
            setmetatable(copy, Utils.deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Utils.table_equals(a, b, visited)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end

    visited = visited or {}
    if visited[a] == b then return true end
    visited[a] = b

    local count_a = 0
    for k, v in pairs(a) do
        count_a = count_a + 1
        local found = false
        if type(k) == 'table' then
            -- For table keys, we need to find a matching key in b
            for kb, vb in pairs(b) do
                if Utils.table_equals(k, kb, visited) and Utils.table_equals(v, vb, visited) then
                    found = true
                    break
                end
            end
        else
            if Utils.table_equals(v, b[k], visited) then
                found = true
            end
        end
        if not found then return false end
    end

    local count_b = 0
    for _ in pairs(b) do count_b = count_b + 1 end

    return count_a == count_b
end

function Utils.set_to_list(set)
    local list = {}
    for key in pairs(set) do
        table.insert(list, key)
    end
    table.sort(list)
    return list
end

function Utils.list_to_set(list)
    local set = {}
    for _, value in ipairs(list) do
        set[value] = true
    end
    return set
end

function Utils.merge_sets(set1, set2)
    local result = Utils.deepcopy(set1)
    for key in pairs(set2) do
        result[key] = true
    end
    return result
end

function Utils.print_table(t, indent)
    indent = indent or ""
    if type(t) ~= 'table' then
        print(indent .. tostring(t))
        return
    end

    print(indent .. "{")
    for k, v in pairs(t) do
        if type(v) == 'table' then
            io.write(indent .. "  " .. tostring(k) .. " = ")
            Utils.print_table(v, indent .. "  ")
        else
            print(indent .. "  " .. tostring(k) .. " = " .. tostring(v))
        end
    end
    print(indent .. "}")
end

function Utils.time_function(func, ...)
    local start_time = os.clock()
    local results = {func(...)}
    local end_time = os.clock()
    return end_time - start_time, table.unpack(results)
end

function Utils.measure_memory(func, ...)
    local start_mem = collectgarbage("count")
    local results = {func(...)}
    local end_mem = collectgarbage("count")
    return end_mem - start_mem, table.unpack(results)
end

function Utils.format_number(num, decimals)
    decimals = decimals or 0
    local fmt = "%." .. decimals .. "f"
    return string.format(fmt, num)
end

function Utils.split_string(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    table.insert(result, string.sub(str, from))
    return result
end

function Utils.trim_string(str)
    return str:match("^%s*(.-)%s*$")
end

function Utils.escape_string(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

return Utils
