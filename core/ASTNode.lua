-- core/ASTNode.lua
-- AST节点系统，支持类型和值的键值结构

local ASTNode = {}
ASTNode.__index = ASTNode

-- 节点类型枚举
ASTNode.TYPES = {
    -- 程序结构
    PROGRAM = "program",
    STATEMENT = "statement",
    BLOCK = "block",

    -- 声明和赋值
    DECLARATION = "declaration",
    ASSIGNMENT = "assignment",

    -- 表达式
    EXPRESSION = "expression",
    LITERAL = "literal",
    IDENTIFIER = "identifier",
    BINARY_OP = "binary_operation",
    UNARY_OP = "unary_operation",

    -- 函数相关
    FUNCTION_DEF = "function_definition",
    FUNCTION_CALL = "function_call",
    CLOSURE = "closure",
    PARAMETER = "parameter",
    ARGUMENT = "argument",

    -- 控制流
    IF_STATEMENT = "if_statement",
    LOOP_STATEMENT = "loop_statement",
    CONTROL_FLOW = "control_flow",

    -- 循环类型
    WHILE_LOOP = "while_loop",
    FOR_LOOP = "for_loop",
    REPEAT_LOOP = "repeat_loop",

    -- 数组和对象
    ARRAY_LITERAL = "array_literal",
    OBJECT_LITERAL = "object_literal",
    INDEX_ACCESS = "index_access",
    MEMBER_ACCESS = "member_access"
}

-- 数据类型枚举
ASTNode.DATA_TYPES = {
    NUMBER = "number",
    STRING = "string",
    BOOLEAN = "boolean",
    NIL = "nil",
    FUNCTION = "function",
    ARRAY = "array",
    OBJECT = "object",
    ANY = "any"
}

function ASTNode.new(node_type, properties)
    local self = setmetatable({}, ASTNode)

    -- 基本属性
    self.type = node_type
    self.properties = properties or {}

    -- 位置信息（用于调试）
    self.line = nil
    self.column = nil

    -- 键值存储系统
    self.key_value_store = {}

    -- 子节点
    self.children = {}

    -- 元数据
    self.metadata = {
        data_type = ASTNode.DATA_TYPES.ANY,
        is_constant = false,
        scope_level = 0,
        dependencies = {},
        side_effects = {}
    }

    return self
end

-- 键值存储方法
function ASTNode:set_value(key, value, value_type)
    self.key_value_store[key] = {
        value = value,
        type = value_type or ASTNode.DATA_TYPES.ANY,
        timestamp = os.time()
    }
end

function ASTNode:get_value(key)
    local entry = self.key_value_store[key]
    return entry and entry.value
end

function ASTNode:get_value_type(key)
    local entry = self.key_value_store[key]
    return entry and entry.type
end

function ASTNode:get_value_entry(key)
    return self.key_value_store[key]
end

function ASTNode:has_key(key)
    return self.key_value_store[key] ~= nil
end

function ASTNode:remove_key(key)
    self.key_value_store[key] = nil
end

function ASTNode:get_all_keys()
    local keys = {}
    for key, _ in pairs(self.key_value_store) do
        table.insert(keys, key)
    end
    return keys
end

-- 子节点管理
function ASTNode:add_child(child)
    if child and child.type then
        table.insert(self.children, child)
        child.parent = self
    end
end

function ASTNode:remove_child(index)
    if index >= 1 and index <= #self.children then
        table.remove(self.children, index)
    end
end

function ASTNode:get_child(index)
    return self.children[index]
end

function ASTNode:get_children()
    return self.children
end

function ASTNode:get_child_count()
    return #self.children
end

-- 元数据管理
function ASTNode:set_data_type(data_type)
    self.metadata.data_type = data_type
end

function ASTNode:get_data_type()
    return self.metadata.data_type
end

function ASTNode:set_constant(is_constant)
    self.metadata.is_constant = is_constant
end

function ASTNode:is_constant()
    return self.metadata.is_constant
end

function ASTNode:set_scope_level(level)
    self.metadata.scope_level = level
end

function ASTNode:get_scope_level()
    return self.metadata.scope_level
end

function ASTNode:add_dependency(dependency)
    table.insert(self.metadata.dependencies, dependency)
end

function ASTNode:get_dependencies()
    return self.metadata.dependencies
end

function ASTNode:add_side_effect(effect)
    table.insert(self.metadata.side_effects, effect)
end

function ASTNode:get_side_effects()
    return self.metadata.side_effects
end

-- 位置信息
function ASTNode:set_position(line, column)
    self.line = line
    self.column = column
end

function ASTNode:get_position()
    return self.line, self.column
end

-- 节点操作
function ASTNode:clone()
    local cloned = ASTNode.new(self.type, self.properties)

    -- 复制键值存储
    for key, entry in pairs(self.key_value_store) do
        cloned.key_value_store[key] = {
            value = entry.value,
            type = entry.type,
            timestamp = entry.timestamp
        }
    end

    -- 复制元数据
    cloned.metadata = {
        data_type = self.metadata.data_type,
        is_constant = self.metadata.is_constant,
        scope_level = self.metadata.scope_level,
        dependencies = {},
        side_effects = {}
    }

    for _, dep in ipairs(self.metadata.dependencies) do
        table.insert(cloned.metadata.dependencies, dep)
    end

    for _, effect in ipairs(self.metadata.side_effects) do
        table.insert(cloned.metadata.side_effects, effect)
    end

    -- 递归复制子节点
    for _, child in ipairs(self.children) do
        cloned:add_child(child:clone())
    end

    cloned.line = self.line
    cloned.column = self.column

    return cloned
end

function ASTNode:to_string(indent)
    indent = indent or ""
    local result = indent .. self.type

    if self.properties and next(self.properties) then
        result = result .. " {"
        local props = {}
        for k, v in pairs(self.properties) do
            table.insert(props, string.format("%s=%s", k, tostring(v)))
        end
        result = result .. table.concat(props, ", ") .. "}"
    end

    -- 添加键值信息
    if next(self.key_value_store) then
        result = result .. " ["
        local kv_pairs = {}
        for key, entry in pairs(self.key_value_store) do
            table.insert(kv_pairs, string.format("%s:%s=%s", key, entry.type, tostring(entry.value)))
        end
        result = result .. table.concat(kv_pairs, ", ") .. "]"
    end

    -- 添加元数据
    if self.metadata.data_type ~= ASTNode.DATA_TYPES.ANY then
        result = result .. string.format(" <%s>", self.metadata.data_type)
    end

    result = result .. "\n"

    -- 添加子节点
    for _, child in ipairs(self.children) do
        result = result .. child:to_string(indent .. "  ")
    end

    return result
end

-- 便利构造函数
function ASTNode.create_literal(value, value_type)
    local node = ASTNode.new(ASTNode.TYPES.LITERAL)
    node:set_value("value", value, value_type or ASTNode.DATA_TYPES.ANY)
    node:set_data_type(value_type or ASTNode.DATA_TYPES.ANY)
    return node
end

function ASTNode.create_identifier(name)
    local node = ASTNode.new(ASTNode.TYPES.IDENTIFIER)
    node:set_value("name", name, ASTNode.DATA_TYPES.STRING)
    node:set_data_type(ASTNode.DATA_TYPES.ANY)  -- 运行时确定
    return node
end

function ASTNode.create_binary_op(left, operator, right)
    local node = ASTNode.new(ASTNode.TYPES.BINARY_OP)
    node:set_value("operator", operator, ASTNode.DATA_TYPES.STRING)
    node:add_child(left)
    node:add_child(right)
    return node
end

function ASTNode.create_function_def(name, parameters, body)
    local node = ASTNode.new(ASTNode.TYPES.FUNCTION_DEF)
    if name then
        node:set_value("name", name, ASTNode.DATA_TYPES.STRING)
    end
    node:set_data_type(ASTNode.DATA_TYPES.FUNCTION)

    -- 添加参数
    for _, param in ipairs(parameters) do
        node:add_child(param)
    end

    -- 添加函数体
    node:add_child(body)

    return node
end

function ASTNode.create_closure(parameters, body)
    local node = ASTNode.new(ASTNode.TYPES.CLOSURE)
    node:set_data_type(ASTNode.DATA_TYPES.FUNCTION)

    -- 添加参数
    for _, param in ipairs(parameters) do
        node:add_child(param)
    end

    -- 添加函数体
    node:add_child(body)

    return node
end

function ASTNode.create_loop(loop_type, condition, body)
    local node = ASTNode.new(ASTNode.TYPES.LOOP_STATEMENT)
    node:set_value("loop_type", loop_type, ASTNode.DATA_TYPES.STRING)

    if condition then
        node:add_child(condition)
    end

    node:add_child(body)

    return node
end

return ASTNode
