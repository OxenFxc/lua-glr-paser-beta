-- State.lua
-- LR状态定义模块

local State = {}
State.__index = State

function State:new(id)
    local self = setmetatable({}, State)
    self.id = id or 0
    self.items = {}           -- Item列表
    self.transitions = {}     -- symbol -> state_id
    return self
end

function State:add_item(item)
    -- 检查是否已存在相同的项
    for _, existing_item in ipairs(self.items) do
        if existing_item:equals(item) then
            -- 合并lookahead
            if existing_item:merge_lookaheads(item) then
                return true  -- 有新的lookahead被添加
            end
            return false  -- 没有变化
        end
    end

    table.insert(self.items, item)
    return true
end

function State:get_items_for_symbol(symbol)
    local result = {}
    for _, item in ipairs(self.items) do
        if item:next_symbol() == symbol then
            table.insert(result, item)
        end
    end
    return result
end

function State:has_complete_items()
    for _, item in ipairs(self.items) do
        if item:is_complete() then
            return true
        end
    end
    return false
end

function State:get_complete_items()
    local complete = {}
    for _, item in ipairs(self.items) do
        if item:is_complete() then
            table.insert(complete, item)
        end
    end
    return complete
end

function State:equals(other)
    if not other or getmetatable(other) ~= State then
        return false
    end

    if #self.items ~= #other.items then
        return false
    end

    -- 检查每个item是否都存在
    for _, item in ipairs(self.items) do
        local found = false
        for _, other_item in ipairs(other.items) do
            if item:equals(other_item) then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end

    return true
end

function State:to_string()
    local lines = {string.format("State %d:", self.id)}

    for _, item in ipairs(self.items) do
        table.insert(lines, string.format("  %s", item:to_string()))
    end

    if next(self.transitions) then
        table.insert(lines, "  Transitions:")
        for symbol, state_id in pairs(self.transitions) do
            table.insert(lines, string.format("    %s -> %d", symbol, state_id))
        end
    end

    return table.concat(lines, "\n")
end

function State:to_key()
    local item_keys = {}
    for _, item in ipairs(self.items) do
        table.insert(item_keys, item:to_key())
    end
    table.sort(item_keys)
    return table.concat(item_keys, "|")
end

return State
