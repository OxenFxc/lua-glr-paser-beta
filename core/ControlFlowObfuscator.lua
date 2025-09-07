-- core/ControlFlowObfuscator.lua
-- 控制流混淆准备系统

local ASTNode = require("core.ASTNode")

local ControlFlowObfuscator = {}
ControlFlowObfuscator.__index = ControlFlowObfuscator

function ControlFlowObfuscator.new()
    local self = setmetatable({}, ControlFlowObfuscator)

    -- 混淆配置
    self.config = {
        enable_loop_flattening = true,
        enable_condition_obfuscation = true,
        enable_function_inlining = false,
        enable_dead_code_insertion = true,
        max_obfuscation_level = 3
    }

    -- 混淆统计
    self.stats = {
        loops_flattened = 0,
        conditions_obfuscated = 0,
        functions_inlined = 0,
        dead_code_inserted = 0,
        control_flow_complexity = 0
    }

    -- 混淆模式
    self.modes = {
        LIGHT = 1,
        MEDIUM = 2,
        HEAVY = 3
    }

    return self
end

-- 设置混淆配置
function ControlFlowObfuscator:set_config(config)
    for key, value in pairs(config) do
        if self.config[key] ~= nil then
            self.config[key] = value
        end
    end
end

-- 循环展平混淆
function ControlFlowObfuscator:flatten_loops(ast_root)
    if not self.config.enable_loop_flattening then return ast_root end

    local function traverse_and_flatten(node)
        if node.type == ASTNode.TYPES.LOOP_STATEMENT then
            local flattened = self:create_flattened_loop(node)
            if flattened then
                self.stats.loops_flattened = self.stats.loops_flattened + 1
                return flattened
            end
        end

        -- 递归处理子节点
        for i, child in ipairs(node.children) do
            node.children[i] = traverse_and_flatten(child)
        end

        return node
    end

    return traverse_and_flatten(ast_root)
end

-- 创建展平后的循环
function ControlFlowObfuscator:create_flattened_loop(loop_node)
    -- 将循环转换为条件跳转结构
    local loop_var = ASTNode.create_identifier("_loop_" .. tostring(math.random(1000, 9999)))
    local condition = loop_node:get_child(1)  -- 循环条件
    local body = loop_node:get_child(2)  -- 循环体

    -- 创建循环变量初始化
    local loop_init = ASTNode.new(ASTNode.TYPES.ASSIGNMENT)
    loop_init:set_value("target", loop_var)
    loop_init:set_value("value", ASTNode.create_literal(true, ASTNode.DATA_TYPES.BOOLEAN))

    -- 创建条件判断和跳转
    local condition_check = ASTNode.new(ASTNode.TYPES.IF_STATEMENT)
    condition_check:add_child(condition)
    condition_check:add_child(body)
    condition_check:add_child(ASTNode.new(ASTNode.TYPES.STATEMENT))  -- else分支

    -- 创建循环包装器
    local loop_wrapper = ASTNode.new(ASTNode.TYPES.BLOCK)
    loop_wrapper:add_child(loop_init)
    loop_wrapper:add_child(condition_check)

    return loop_wrapper
end

-- 条件混淆
function ControlFlowObfuscator:obfuscate_conditions(ast_root)
    if not self.config.enable_condition_obfuscation then return ast_root end

    local function traverse_and_obfuscate(node)
        if node.type == ASTNode.TYPES.IF_STATEMENT then
            local obfuscated = self:create_obfuscated_condition(node)
            if obfuscated then
                self.stats.conditions_obfuscated = self.stats.conditions_obfuscated + 1
                return obfuscated
            end
        end

        -- 递归处理子节点
        for i, child in ipairs(node.children) do
            node.children[i] = traverse_and_obfuscate(child)
        end

        return node
    end

    return traverse_and_obfuscate(ast_root)
end

-- 创建混淆后的条件
function ControlFlowObfuscator:create_obfuscated_condition(if_node)
    local condition = if_node:get_child(1)
    local then_branch = if_node:get_child(2)
    local else_branch = if_node:get_child_count() > 2 and if_node:get_child(3)

    -- 创建随机变量
    local rand_var = ASTNode.create_identifier("_cond_" .. tostring(math.random(1000, 9999)))
    local rand_value = math.random()

    -- 创建混淆表达式：(condition && random_var > threshold)
    local threshold = ASTNode.create_literal(rand_value, ASTNode.DATA_TYPES.NUMBER)
    local rand_access = ASTNode.create_binary_op(rand_var, ">", threshold)
    local obfuscated_condition = ASTNode.create_binary_op(condition, "and", rand_access)

    -- 创建变量初始化
    local var_init = ASTNode.new(ASTNode.TYPES.ASSIGNMENT)
    var_init:set_value("target", rand_var)
    var_init:set_value("value", ASTNode.create_literal(rand_value + 0.1, ASTNode.DATA_TYPES.NUMBER))

    -- 创建新的if语句
    local new_if = ASTNode.new(ASTNode.TYPES.IF_STATEMENT)
    new_if:add_child(obfuscated_condition)
    new_if:add_child(then_branch)
    if else_branch then
        new_if:add_child(else_branch)
    end

    -- 创建包装块
    local wrapper = ASTNode.new(ASTNode.TYPES.BLOCK)
    wrapper:add_child(var_init)
    wrapper:add_child(new_if)

    return wrapper
end

-- 死代码插入
function ControlFlowObfuscator:insert_dead_code(ast_root)
    if not self.config.enable_dead_code_insertion then return ast_root end

    local function traverse_and_insert(node)
        -- 在合适的位置插入死代码
        if node.type == ASTNode.TYPES.BLOCK then
            local dead_code = self:create_dead_code_block()
            if dead_code then
                -- 在随机位置插入死代码
                local insert_pos = math.random(1, #node.children + 1)
                table.insert(node.children, insert_pos, dead_code)
                self.stats.dead_code_inserted = self.stats.dead_code_inserted + 1
            end
        end

        -- 递归处理子节点
        for i, child in ipairs(node.children) do
            node.children[i] = traverse_and_insert(child)
        end

        return node
    end

    return traverse_and_insert(ast_root)
end

-- 创建死代码块
function ControlFlowObfuscator:create_dead_code_block()
    local dead_vars = {}

    -- 创建几个死变量
    for i = 1, math.random(1, 3) do
        local var_name = "_dead_" .. tostring(math.random(1000, 9999))
        local dead_var = ASTNode.create_identifier(var_name)

        -- 创建变量声明
        local decl = ASTNode.new(ASTNode.TYPES.DECLARATION)
        decl:set_value("name", var_name)
        decl:set_value("value", ASTNode.create_literal(math.random(), ASTNode.DATA_TYPES.NUMBER))

        table.insert(dead_vars, decl)
    end

    -- 创建死代码块
    local dead_block = ASTNode.new(ASTNode.TYPES.BLOCK)
    for _, dead_var in ipairs(dead_vars) do
        dead_block:add_child(dead_var)
    end

    return dead_block
end

-- 函数内联
function ControlFlowObfuscator:inline_functions(ast_root)
    if not self.config.enable_function_inlining then return ast_root end

    -- 收集函数定义
    local function_defs = {}
    local function collect_functions(node)
        if node.type == ASTNode.TYPES.FUNCTION_DEF then
            local func_name = node:get_value("name")
            if func_name then
                function_defs[func_name] = node
            end
        end

        for _, child in ipairs(node.children) do
            collect_functions(child)
        end
    end

    collect_functions(ast_root)

    -- 内联函数调用
    local function traverse_and_inline(node)
        if node.type == ASTNode.TYPES.FUNCTION_CALL then
            local func_name = node:get_value("function_name")
            local func_def = function_defs[func_name]

            if func_def and self:should_inline_function(func_def) then
                local inlined = self:create_inlined_function(func_def, node)
                if inlined then
                    self.stats.functions_inlined = self.stats.functions_inlined + 1
                    return inlined
                end
            end
        end

        -- 递归处理子节点
        for i, child in ipairs(node.children) do
            node.children[i] = traverse_and_inline(child)
        end

        return node
    end

    return traverse_and_inline(ast_root)
end

-- 判断是否应该内联函数
function ControlFlowObfuscator:should_inline_function(func_def)
    -- 检查函数大小
    local size = self:calculate_node_size(func_def)
    return size < 50  -- 小函数才内联
end

-- 计算节点大小
function ControlFlowObfuscator:calculate_node_size(node)
    local size = 1
    for _, child in ipairs(node.children) do
        size = size + self:calculate_node_size(child)
    end
    return size
end

-- 创建内联函数
function ControlFlowObfuscator:create_inlined_function(func_def, call_node)
    -- 复制函数体
    local body = func_def:get_child(func_def:get_child_count()):clone()

    -- 这里可以实现更复杂的参数替换逻辑
    return body
end

-- 应用所有混淆技术
function ControlFlowObfuscator:obfuscate(ast_root, level)
    level = level or self.modes.MEDIUM
    self.config.max_obfuscation_level = level

    print(string.format("Starting control flow obfuscation (level %d)...", level))

    local obfuscated = ast_root

    -- 应用各种混淆技术
    obfuscated = self:flatten_loops(obfuscated)
    obfuscated = self:obfuscate_conditions(obfuscated)
    obfuscated = self:insert_dead_code(obfuscated)
    obfuscated = self:inline_functions(obfuscated)

    -- 计算控制流复杂度
    self.stats.control_flow_complexity = self:calculate_complexity(obfuscated)

    print("Control flow obfuscation completed")
    print("Stats:", self:get_stats_string())

    return obfuscated
end

-- 计算控制流复杂度
function ControlFlowObfuscator:calculate_complexity(node)
    local complexity = 0

    if node.type == ASTNode.TYPES.LOOP_STATEMENT then
        complexity = complexity + 10
    elseif node.type == ASTNode.TYPES.IF_STATEMENT then
        complexity = complexity + 5
    elseif node.type == ASTNode.TYPES.FUNCTION_DEF then
        complexity = complexity + 3
    end

    for _, child in ipairs(node.children) do
        complexity = complexity + self:calculate_complexity(child)
    end

    return complexity
end

-- 获取统计信息字符串
function ControlFlowObfuscator:get_stats_string()
    return string.format(
        "Loops flattened: %d, Conditions obfuscated: %d, Functions inlined: %d, Dead code inserted: %d, Complexity: %d",
        self.stats.loops_flattened,
        self.stats.conditions_obfuscated,
        self.stats.functions_inlined,
        self.stats.dead_code_inserted,
        self.stats.control_flow_complexity
    )
end

-- 获取统计数据
function ControlFlowObfuscator:get_stats()
    return self.stats
end

-- 重置统计数据
function ControlFlowObfuscator:reset_stats()
    self.stats = {
        loops_flattened = 0,
        conditions_obfuscated = 0,
        functions_inlined = 0,
        dead_code_inserted = 0,
        control_flow_complexity = 0
    }
end

return ControlFlowObfuscator
