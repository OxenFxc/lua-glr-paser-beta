-- Stack.lua
-- GLR解析栈管理模块

local Stack = {}
Stack.__index = Stack

function Stack:new()
    local self = setmetatable({}, Stack)
    self.entries = {}  -- 栈条目列表
    return self
end

function Stack:push(state_id, node)
    table.insert(self.entries, {
        state_id = state_id,
        node = node
    })
end

function Stack:pop()
    if #self.entries > 0 then
        return table.remove(self.entries)
    end
    return nil
end

function Stack:top()
    if #self.entries > 0 then
        return self.entries[#self.entries]
    end
    return nil
end

function Stack:size()
    return #self.entries
end

function Stack:is_empty()
    return #self.entries == 0
end

function Stack:clone()
    local new_stack = Stack:new()
    for _, entry in ipairs(self.entries) do
        table.insert(new_stack.entries, {
            state_id = entry.state_id,
            node = entry.node
        })
    end
    return new_stack
end

function Stack:equals(other)
    if not other or getmetatable(other) ~= Stack then
        return false
    end

    if #self.entries ~= #other.entries then
        return false
    end

    for i, entry in ipairs(self.entries) do
        local other_entry = other.entries[i]
        if entry.state_id ~= other_entry.state_id then
            return false
        end
        -- 这里可以添加更复杂的节点比较逻辑
    end

    return true
end

function Stack:to_string()
    local parts = {}
    for i, entry in ipairs(self.entries) do
        table.insert(parts, string.format("(%d, %s)", entry.state_id,
                         entry.node and entry.node.type or "nil"))
    end
    return "[" .. table.concat(parts, ", ") .. "]"
end

-- GLRStack 类用于管理多个并行栈
local GLRStack = {}
GLRStack.__index = GLRStack

function GLRStack:new()
    local self = setmetatable({}, GLRStack)
    self.stacks = {}  -- 栈列表
    return self
end

function GLRStack:add_stack(stack)
    table.insert(self.stacks, stack)
end

function GLRStack:remove_stack(index)
    if index >= 1 and index <= #self.stacks then
        table.remove(self.stacks, index)
    end
end

function GLRStack:get_stack(index)
    return self.stacks[index]
end

function GLRStack:size()
    return #self.stacks
end

function GLRStack:clone()
    local new_glr_stack = GLRStack:new()
    for _, stack in ipairs(self.stacks) do
        new_glr_stack:add_stack(stack:clone())
    end
    return new_glr_stack
end

function GLRStack:has_stack(stack)
    for _, existing_stack in ipairs(self.stacks) do
        if existing_stack:equals(stack) then
            return true
        end
    end
    return false
end

function GLRStack:merge_stacks()
    -- 合并相同的栈以减少状态空间
    local unique_stacks = {}
    local seen = {}

    for _, stack in ipairs(self.stacks) do
        local key = stack:to_string()
        if not seen[key] then
            table.insert(unique_stacks, stack)
            seen[key] = true
        end
    end

    self.stacks = unique_stacks
end

function GLRStack:to_string()
    local parts = {}
    for i, stack in ipairs(self.stacks) do
        table.insert(parts, string.format("Stack %d: %s", i, stack:to_string()))
    end
    return table.concat(parts, "\n")
end

return {
    Stack = Stack,
    GLRStack = GLRStack
}
