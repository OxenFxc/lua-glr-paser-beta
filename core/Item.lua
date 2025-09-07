-- Item.lua
-- LR项定义模块

local Item = {}
Item.__index = Item

function Item:new(production, dot_position, lookaheads)
    local self = setmetatable({}, Item)
    self.production = production    -- {lhs, rhs1, rhs2, ...}
    self.dot_position = dot_position or 0
    self.lookaheads = lookaheads or {}
    return self
end

function Item:clone()
    local new_lookaheads = {}
    for _, la in ipairs(self.lookaheads) do
        table.insert(new_lookaheads, la)
    end
    return Item:new(self.production, self.dot_position, new_lookaheads)
end

function Item:is_complete()
    return self.dot_position >= #self.production - 1
end

function Item:next_symbol()
    if self.dot_position < #self.production - 1 then
        return self.production[self.dot_position + 2]
    end
    return nil
end

function Item:advance_dot()
    if not self:is_complete() then
        return Item:new(self.production, self.dot_position + 1, self.lookaheads)
    end
    return nil
end

function Item:equals(other)
    if not other or getmetatable(other) ~= Item then
        return false
    end

    if self.production[1] ~= other.production[1] then
        return false
    end

    if self.dot_position ~= other.dot_position then
        return false
    end

    if #self.lookaheads ~= #other.lookaheads then
        return false
    end

    -- 检查production是否相同
    if #self.production ~= #other.production then
        return false
    end
    for i, symbol in ipairs(self.production) do
        if symbol ~= other.production[i] then
            return false
        end
    end

    -- 检查lookaheads是否相同
    local la_set = {}
    for _, la in ipairs(self.lookaheads) do
        la_set[la] = true
    end
    for _, la in ipairs(other.lookaheads) do
        if not la_set[la] then
            return false
        end
    end

    return true
end

function Item:merge_lookaheads(other)
    if not other then return end

    local added = false
    local existing_set = {}
    for _, la in ipairs(self.lookaheads) do
        existing_set[la] = true
    end

    for _, la in ipairs(other.lookaheads) do
        if not existing_set[la] then
            table.insert(self.lookaheads, la)
            added = true
        end
    end

    return added
end

function Item:to_string()
    local rhs_parts = {}

    for i = 2, #self.production do
        local symbol = self.production[i]
        if i - 1 == self.dot_position then
            table.insert(rhs_parts, "•" .. symbol)
        else
            table.insert(rhs_parts, symbol)
        end
    end

    if self.dot_position >= #self.production - 1 then
        table.insert(rhs_parts, "•")
    end

    local la_parts = {}
    for _, la in ipairs(self.lookaheads) do
        table.insert(la_parts, la)
    end

    return string.format("%s -> %s {%s}",
                        self.production[1],
                        table.concat(rhs_parts, " "),
                        table.concat(la_parts, ","))
end

function Item:to_key()
    local prod_str = table.concat(self.production, ",")
    local la_str = table.concat(self.lookaheads, ",")
    return string.format("%s|%d|%s", prod_str, self.dot_position, la_str)
end

return Item
