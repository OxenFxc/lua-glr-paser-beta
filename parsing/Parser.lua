-- Parser.lua
-- GLR解析器核心算法模块

local Parser = {}
Parser.__index = Parser

local Automaton = require("core.Automaton")
local StackModule = require("parsing.Stack")
local Stack = StackModule.Stack
local GLRStack = StackModule.GLRStack

function Parser:new(grammar)
    local self = setmetatable({}, Parser)
    self.grammar = grammar
    self.automaton = Automaton:new(grammar)
    self.states = nil
    return self
end

function Parser:build_automaton()
    self.states = self.automaton:build()
    return self.states
end

function Parser:parse(input)
    if not self.states then
        self:build_automaton()
    end

    local tokens = self:tokenize(input)
    -- 注意：结束标记"$"应该由分词器添加

    -- 初始化GLR栈
    local glr_stack = GLRStack:new()
    local initial_stack = Stack:new()
    initial_stack:push(0, nil)  -- 初始状态
    glr_stack:add_stack(initial_stack)

    for i, token in ipairs(tokens) do
        print(string.format("Processing token %d/%d: %s", i, #tokens, token))
        print(string.format("Current stacks: %d", glr_stack:size()))
        for j, stack in ipairs(glr_stack.stacks) do
            print(string.format("  Stack %d: %s", j, stack:to_string()))
        end

        local new_glr_stack = GLRStack:new()

        -- 对每个当前栈进行处理
        for _, current_stack in ipairs(glr_stack.stacks) do
            local current_state_id = current_stack:top().state_id
            local current_state = self.states[current_state_id + 1]

            print(string.format("  Processing stack with state %d", current_state_id))

            -- 先尝试规约，再尝试移进
            local has_reductions = false

            -- 尝试规约
            local reductions = self:get_possible_reductions(current_stack, token)
            print(string.format("  Found %d possible reductions", #reductions))
            for _, reduction in ipairs(reductions) do
                print(string.format("    Reduction: %s", reduction:to_string()))
                local reduced_stack = self:perform_reduction(current_stack, reduction)
                if reduced_stack then
                    print(string.format("    Reduced to state %d", reduced_stack:top().state_id))
                    if not new_glr_stack:has_stack(reduced_stack) then
                        new_glr_stack:add_stack(reduced_stack)
                        has_reductions = true
                    end
                else
                    print("    Reduction failed")
                end
            end

            -- 尝试移进
            if current_state.transitions[token] then
                local target_state_id = current_state.transitions[token]
                print(string.format("  Shift to state %d", target_state_id))
                print(string.format("  Target state exists: %s", self.states[target_state_id + 1] and "yes" or "no"))
                local new_stack = current_stack:clone()
                local node = {type = "terminal", value = token}
                new_stack:push(target_state_id, node)

                if not new_glr_stack:has_stack(new_stack) then
                    new_glr_stack:add_stack(new_stack)
                end
            else
                print("  No shift transition for token")
            end

        -- 如果没有规约也没有移进，检查是否是错误状态
        if not has_reductions and not current_state.transitions[token] then
            -- 检查是否是终结符（不是$）
            if token ~= "$" then
                print(string.format("  ERROR: No transition for token '%s' in state %d", token, current_state_id))

                -- 改进的错误恢复策略
                local recovery_success = false

                -- 策略1: 尝试插入缺失的同步token
                if token == "+" or token == "-" or token == "*" or token == "/" then
                    print("  Attempting error recovery by inserting missing operator")

                    -- 查找可能的同步点（括号、分号等）
                    local sync_tokens = {")", ";", "end"}
                    for _, sync_token in ipairs(sync_tokens) do
                        if current_state.transitions[sync_token] then
                            print(string.format("  Found sync token '%s', attempting recovery", sync_token))
                            -- 这里可以实现更复杂的同步恢复逻辑
                            recovery_success = true
                            break
                        end
                    end
                end

                -- 策略2: 跳过当前token并继续（原有策略）
                if not recovery_success then
                    print("  Attempting error recovery by skipping token")
                    -- 检查是否可以跳过多个token到达同步点
                    local tokens_ahead = {}
                    local token_index = current_token_index
                    while token_index <= #self.tokens and #tokens_ahead < 3 do
                        if self.tokens[token_index] ~= token then -- 跳过当前错误token
                            table.insert(tokens_ahead, self.tokens[token_index])
                        end
                        token_index = token_index + 1
                    end

                    for _, future_token in ipairs(tokens_ahead) do
                        if current_state.transitions[future_token] then
                            print(string.format("  Found recovery point with token '%s'", future_token))
                            break
                        end
                    end
                end

                -- 不添加任何栈，继续处理下一个token（错误恢复）
            else
                print("  Reached end of input, keeping original stack")
                if not new_glr_stack:has_stack(current_stack) then
                    new_glr_stack:add_stack(current_stack)
                end
            end
        end
        end

        -- 合并相同的栈
        new_glr_stack:merge_stacks()

        glr_stack = new_glr_stack

        if glr_stack:size() == 0 then
            return nil, string.format("Parse error at token %d (%s)", i, token)
        end
    end

    -- 收集成功解析的结果
    local results = {}
    print(string.format("Collecting results from %d stacks", glr_stack:size()))

    for i, stack in ipairs(glr_stack.stacks) do
        print(string.format("Checking stack %d: size=%d", i, stack:size()))

        -- 检查栈顶是否是接受状态
        local top_entry = stack:top()
        if top_entry then
            print(string.format("  Top entry: state=%d, node_type=%s",
                       top_entry.state_id,
                       top_entry.node and top_entry.node.type or "nil"))
        end

        -- 查找包含接受状态的栈（S' -> S• 的状态）
        local has_accept_item = false
        local state = self.states[top_entry.state_id + 1]
        if state then
            for _, item in ipairs(state.items) do
                if item.production[1] == self.grammar.start_symbol .. "'" and
                   item.dot_position == #item.production - 1 then
                    has_accept_item = true
                    print("  Found accept item in stack")
                    break
                end
            end
        end

        if has_accept_item and top_entry and top_entry.node then
            print("  Adding result from stack " .. i)
            table.insert(results, top_entry.node)
        elseif top_entry and top_entry.node and stack:size() >= 2 then
            -- 备选方案：如果栈包含最终结果
            print("  Adding result as fallback from stack " .. i)
            table.insert(results, top_entry.node)
        end
    end

    print(string.format("Collected %d results", #results))
    return results
end

function Parser:get_possible_reductions(stack, lookahead)
    local reductions = {}
    local top_entry = stack:top()

    if not top_entry then return reductions end

    local state = self.states[top_entry.state_id + 1]
    local complete_items = state:get_complete_items()

    for _, item in ipairs(complete_items) do
        -- 检查lookahead是否在当前项的lookahead集合中
        local valid_lookahead = false
        for _, la in ipairs(item.lookaheads) do
            if la == lookahead or la == "$" then
                valid_lookahead = true
                break
            end
        end

        -- 如果没有找到匹配的lookahead，但这是结束标记，尝试所有规约
        if not valid_lookahead and lookahead == "$" then
            valid_lookahead = true
        end

        if valid_lookahead then
            table.insert(reductions, item)
        end
    end

    return reductions
end

function Parser:perform_reduction(stack, item)
    local prod = item.production
    local rhs_length = #prod - 1

    if stack:size() < rhs_length then
        return nil
    end

    -- 收集RHS节点
    local rhs_nodes = {}
    local temp_stack = stack:clone()

    for i = 1, rhs_length do
        local entry = temp_stack:pop()
        if entry and entry.node then
            table.insert(rhs_nodes, 1, entry.node)  -- 反转顺序以保持正确顺序
        else
            -- 如果缺少节点，创建占位符
            table.insert(rhs_nodes, 1, {type = "error", value = "missing_node"})
        end
    end

    -- 创建新节点
    local new_node = {
        type = "nonterminal",
        symbol = prod[1],
        children = rhs_nodes
    }

    -- 找到goto状态
    local current_state_id = temp_stack:top().state_id
    local current_state = self.states[current_state_id + 1]

    if not current_state then
        print(string.format("ERROR: State %d not found", current_state_id))
        return nil
    end

    local goto_state_id = current_state.transitions[prod[1]]

    if goto_state_id then
        print(string.format("  Goto %s -> state %d", prod[1], goto_state_id))
        temp_stack:push(goto_state_id, new_node)
        return temp_stack
    else
        print(string.format("  No goto transition for %s in state %d", prod[1], current_state_id))
        -- 尝试查找可能的goto状态
        for symbol, state_id in pairs(current_state.transitions) do
            if symbol ~= "$" and self.grammar.nonterminals[symbol] then
                print(string.format("  Found possible goto: %s -> %d", symbol, state_id))
            end
        end
    end

    return nil
end

function Parser:tokenize(input)
    -- 默认分词器，按空格分割
    local tokens = {}
    for word in string.gmatch(input, "%S+") do
        table.insert(tokens, word)
    end
    return tokens
end

function Parser:set_tokenizer(tokenizer_func)
    -- 将函数包装成方法
    self.tokenize = function(self, input)
        return tokenizer_func(input)
    end
end

function Parser:print_parse_tree(node, indent)
    indent = indent or ""
    if node.type == "terminal" then
        print(indent .. node.value)
    elseif node.type == "nonterminal" then
        print(indent .. node.symbol)
        if node.children then
            for _, child in ipairs(node.children) do
                self:print_parse_tree(child, indent .. "  ")
            end
        end
    else
        print(indent .. tostring(node))
    end
end

function Parser:print_automaton()
    if self.automaton then
        self.automaton:print_states()
    else
        print("Automaton not built yet")
    end
end

return Parser
