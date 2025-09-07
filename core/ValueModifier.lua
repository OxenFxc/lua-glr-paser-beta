-- core/ValueModifier.lua
-- 值修改系统，支持循环对解析值进行修改

local ASTNode = require("core.ASTNode")

local ValueModifier = {}
ValueModifier.__index = ValueModifier

function ValueModifier.new()
    local self = setmetatable({}, ValueModifier)

    -- 修改规则存储
    self.modification_rules = {}

    -- 修改历史
    self.modification_history = {}

    -- 循环上下文
    self.loop_context = {
        current_iteration = 0,
        max_iterations = 1000,
        loop_variables = {},
        break_condition = nil
    }

    -- 类型转换规则
    self.type_conversion_rules = {
        [ASTNode.DATA_TYPES.NUMBER] = {
            [ASTNode.DATA_TYPES.STRING] = function(value) return tostring(value) end,
            [ASTNode.DATA_TYPES.BOOLEAN] = function(value) return value ~= 0 end
        },
        [ASTNode.DATA_TYPES.STRING] = {
            [ASTNode.DATA_TYPES.NUMBER] = function(value) return tonumber(value) or 0 end,
            [ASTNode.DATA_TYPES.BOOLEAN] = function(value) return value ~= "" end
        },
        [ASTNode.DATA_TYPES.BOOLEAN] = {
            [ASTNode.DATA_TYPES.NUMBER] = function(value) return value and 1 or 0 end,
            [ASTNode.DATA_TYPES.STRING] = function(value) return value and "true" or "false" end
        }
    }

    return self
end

-- 添加修改规则
function ValueModifier:add_modification_rule(condition_func, modification_func, priority)
    table.insert(self.modification_rules, {
        condition = condition_func,
        modification = modification_func,
        priority = priority or 1,
        enabled = true
    })

    -- 按优先级排序
    table.sort(self.modification_rules, function(a, b)
        return a.priority > b.priority
    end)
end

-- 应用修改规则到单个节点
function ValueModifier:modify_node(node)
    if not node then return node end

    local original_node = node:clone()

    -- 应用所有匹配的规则
    for _, rule in ipairs(self.modification_rules) do
        if rule.enabled and rule.condition(node) then
            local success, result = pcall(rule.modification, node, self.loop_context)
            if success and result then
                node = result
                self:record_modification(original_node, node, rule)
            end
        end
    end

    -- 递归修改子节点
    for i, child in ipairs(node.children) do
        node.children[i] = self:modify_node(child)
    end

    return node
end

-- 循环修改节点列表
function ValueModifier:modify_nodes_with_loop(nodes, loop_config)
    loop_config = loop_config or {}

    self.loop_context.current_iteration = 0
    self.loop_context.max_iterations = loop_config.max_iterations or 1000
    self.loop_context.loop_variables = loop_config.variables or {}
    self.loop_context.break_condition = loop_config.break_condition

    local modified_nodes = {}

    for i, node in ipairs(nodes) do
        self.loop_context.current_iteration = i

        -- 检查循环变量
        for var_name, var_config in pairs(self.loop_context.loop_variables) do
            if var_config.update_func then
                var_config.current_value = var_config.update_func(var_config.current_value, i)
            end
        end

        -- 检查中断条件
        if self.loop_context.break_condition and
           self.loop_context.break_condition(self.loop_context) then
            print(string.format("Loop terminated at iteration %d due to break condition", i))
            break
        end

        -- 修改节点
        local modified_node = self:modify_node(node)
        table.insert(modified_nodes, modified_node)

        -- 调试输出
        if loop_config.debug and i % (loop_config.debug_interval or 10) == 0 then
            print(string.format("Loop iteration %d/%d completed", i, #nodes))
        end
    end

    return modified_nodes
end

-- 批量修改AST节点
function ValueModifier:modify_ast(ast_root, config)
    config = config or {}

    print("Starting AST modification...")

    local start_time = os.time()

    -- 收集所有节点
    local all_nodes = self:collect_all_nodes(ast_root)

    print(string.format("Collected %d nodes for modification", #all_nodes))

    -- 应用循环修改
    local modified_nodes = self:modify_nodes_with_loop(all_nodes, config)

    -- 重建AST结构
    local modified_ast = self:rebuild_ast_structure(ast_root, modified_nodes)

    local end_time = os.time()
    print(string.format("AST modification completed in %d seconds", end_time - start_time))

    return modified_ast
end

-- 收集AST中的所有节点
function ValueModifier:collect_all_nodes(root)
    local nodes = {}

    local function traverse(node)
        table.insert(nodes, node)
        for _, child in ipairs(node.children) do
            traverse(child)
        end
    end

    traverse(root)
    return nodes
end

-- 重建AST结构
function ValueModifier:rebuild_ast_structure(original_root, modified_nodes)
    -- 创建节点映射
    local node_map = {}
    for i, node in ipairs(modified_nodes) do
        node_map[modified_nodes[i]] = node
    end

    -- 重建结构
    local function rebuild(node)
        local new_node = node_map[node] or node:clone()

        new_node.children = {}
        for _, child in ipairs(node.children) do
            local new_child = rebuild(child)
            new_node:add_child(new_child)
        end

        return new_node
    end

    return rebuild(original_root)
end

-- 记录修改历史
function ValueModifier:record_modification(original, modified, rule)
    table.insert(self.modification_history, {
        timestamp = os.time(),
        original = original,
        modified = modified,
        rule = rule,
        iteration = self.loop_context.current_iteration
    })
end

-- 获取修改历史
function ValueModifier:get_modification_history()
    return self.modification_history
end

-- 类型转换
function ValueModifier:convert_type(value, from_type, to_type)
    if from_type == to_type then
        return value
    end

    local converter = self.type_conversion_rules[from_type] and
                     self.type_conversion_rules[from_type][to_type]

    if converter then
        return converter(value)
    else
        print(string.format("Warning: No conversion rule from %s to %s", from_type, to_type))
        return value
    end
end

-- 启用/禁用修改规则
function ValueModifier:enable_rule(index, enabled)
    if self.modification_rules[index] then
        self.modification_rules[index].enabled = enabled
    end
end

-- 获取修改统计
function ValueModifier:get_modification_stats()
    local stats = {
        total_rules = #self.modification_rules,
        enabled_rules = 0,
        total_modifications = #self.modification_history,
        modifications_by_rule = {}
    }

    for _, rule in ipairs(self.modification_rules) do
        if rule.enabled then
            stats.enabled_rules = stats.enabled_rules + 1
        end
    end

    for _, record in ipairs(self.modification_history) do
        local rule_id = tostring(record.rule)
        stats.modifications_by_rule[rule_id] = (stats.modifications_by_rule[rule_id] or 0) + 1
    end

    return stats
end

-- 预定义修改规则
function ValueModifier:add_predefined_rules()
    -- 常量折叠规则
    self:add_modification_rule(
        function(node)
            return node.type == ASTNode.TYPES.BINARY_OP and
                   node:get_child(1):is_constant() and
                   node:get_child(2):is_constant()
        end,
        function(node, context)
            local left = node:get_child(1):get_value("value")
            local right = node:get_child(2):get_value("value")
            local op = node:get_value("operator")

            local result
            if op == "+" then result = left + right
            elseif op == "-" then result = left - right
            elseif op == "*" then result = left * right
            elseif op == "/" then result = left / right
            else return node end

            local literal_node = ASTNode.create_literal(result, ASTNode.DATA_TYPES.NUMBER)
            literal_node:set_constant(true)
            return literal_node
        end,
        10
    )

    -- 死代码消除规则
    self:add_modification_rule(
        function(node)
            return node.type == ASTNode.TYPES.IF_STATEMENT and
                   node:get_child(1):is_constant() and
                   not node:get_child(1):get_value("value")
        end,
        function(node, context)
            -- 如果条件永远为false，返回空语句
            return ASTNode.new(ASTNode.TYPES.STATEMENT)
        end,
        8
    )

    -- 循环变量优化规则
    self:add_modification_rule(
        function(node)
            return node.type == ASTNode.TYPES.IDENTIFIER and
                   node:get_value("name") and
                   node:get_value("is_loop_variable")
        end,
        function(node, context)
            local var_name = node:get_value("name")

            -- 从context中查找循环变量
            if context and context.loop_variables and context.loop_variables[var_name] then
                local var_config = context.loop_variables[var_name]

                if var_config and var_config.current_value then
                    local literal_node = ASTNode.create_literal(
                        var_config.current_value,
                        var_config.type or ASTNode.DATA_TYPES.ANY
                    )
                    literal_node:set_constant(true)
                    return literal_node
                end
            end

            return node
        end,
        5
    )

    print("Predefined modification rules added")
end

return ValueModifier
