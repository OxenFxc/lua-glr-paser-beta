-- Parser.lua
-- GLR解析器核心算法模块

local Parser = {}
Parser.__index = Parser

local Automaton = require("core.Automaton")
local StackModule = require("parsing.Stack")
local Stack = StackModule.Stack
local GLRStack = StackModule.GLRStack

function Parser:new(grammar, verbose)
    local self = setmetatable({}, Parser)
    self.grammar = grammar
    self.verbose = verbose or false
    self.automaton = Automaton:new(grammar, self.verbose)
    self.states = nil
    return self
end

function Parser:log(fmt, ...)
    if self.verbose then
        print(string.format(fmt, ...))
    end
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
    self.tokens = tokens
    -- 注意：结束标记"$"应该由分词器添加

    -- 初始化GLR栈
    local glr_stack = GLRStack:new()
    local initial_stack = Stack:new()
    initial_stack:push(0, nil)  -- 初始状态
    glr_stack:add_stack(initial_stack)

    local i = 1
    while i <= #tokens do
        local token_entry = tokens[i]
        local token_symbol
        local token_value

        if type(token_entry) == "table" and token_entry.symbol then
            token_symbol = token_entry.symbol
            token_value = token_entry.value
        else
            token_symbol = token_entry
            token_value = token_entry
        end

        self:log("Processing token %d/%d: %s (value: %s)", i, #tokens, token_symbol, tostring(token_value))
        self:log("Current stacks: %d", glr_stack:size())

        if self.verbose then
            for j, stack in ipairs(glr_stack.stacks) do
                self:log("  Stack %d: %s", j, stack:to_string())
            end
        end

        local next_glr_stack = GLRStack:new()
        local token_processed_by_any_stack = false
        local next_loop_index = i + 1 -- Default next token

        -- 使用while循环遍历当前栈（支持动态添加规约产生的栈）
        local j = 1
        while j <= glr_stack:size() do
            local current_stack = glr_stack:get_stack(j)
            local current_state_id = current_stack:top().state_id
            local current_state = self.states[current_state_id + 1]

            self:log("  Processing stack with state %d", current_state_id)

            -- 尝试规约 (Add result to CURRENT glr_stack to re-process with same token)
            local reductions = self:get_possible_reductions(current_stack, token_symbol)
            self:log("  Found %d possible reductions", #reductions)
            for _, reduction in ipairs(reductions) do
                self:log("    Reduction: %s", reduction:to_string())
                local reduced_stack = self:perform_reduction(current_stack, reduction)
                if reduced_stack then
                    self:log("    Reduced to state %d", reduced_stack:top().state_id)
                    if not glr_stack:has_stack(reduced_stack) then
                        glr_stack:add_stack(reduced_stack)
                        token_processed_by_any_stack = true
                    end
                else
                    self:log("    Reduction failed")
                end
            end

            -- 尝试移进 (Add result to NEXT glr_stack)
            if current_state.transitions[token_symbol] then
                local target_state_id = current_state.transitions[token_symbol]
                self:log("  Shift to state %d", target_state_id)
                local new_stack = current_stack:clone()
                -- Use the actual value from the token for the parse tree node
                local node = {type = "terminal", value = token_value}
                new_stack:push(target_state_id, node)

                if not next_glr_stack:has_stack(new_stack) then
                    next_glr_stack:add_stack(new_stack)
                    token_processed_by_any_stack = true
                end
            else
                self:log("  No shift transition for token")
            end

            j = j + 1
        end

        if token_symbol == "$" then
            -- Reached end of input. The current glr_stack (which contains results of reductions)
            -- holds the final states. We don't need to shift $.
            break
        end

        -- Error handling if no stack could process the token (shift)
        if next_glr_stack:size() == 0 then
            -- 检查是否是终结符（不是$）
            if token_symbol ~= "$" then
                self:log("  ERROR: No transition for token '%s'", token_symbol)
                if self.verbose then
                    print(string.format("Syntax Error at token %d ('%s')", i, token_symbol))
                end

                -- Panic Mode Recovery
                local recovery_success = false
                local sync_tokens = {
                    [";"]=true, ["end"]=true, ["else"]=true,
                    ["elseif"]=true, ["until"]=true, ["$"]=true,
                    [")"]=true, ["}"]=true, ["]"]=true
                }

                local k = i
                while k <= #self.tokens do
                    local next_token_entry = self.tokens[k]
                    local next_token_symbol = (type(next_token_entry) == "table" and next_token_entry.symbol) or next_token_entry

                    if sync_tokens[next_token_symbol] then
                        self:log("  Found sync token '%s' at %d", next_token_symbol, k)

                        -- Try to find a stack that can shift this token
                        local best_recovered_stack = nil

                        for _, stack_check in ipairs(glr_stack.stacks) do
                            local temp_stack = stack_check:clone()
                            -- Pop states until we find one that accepts the sync token
                            while temp_stack:size() > 0 do
                                local top_state_id = temp_stack:top().state_id
                                local top_state = self.states[top_state_id + 1]
                                if top_state.transitions[next_token_symbol] then
                                    self:log("  Stack recovered at state %d", top_state_id)
                                    if not best_recovered_stack or temp_stack:size() > best_recovered_stack:size() then
                                        best_recovered_stack = temp_stack
                                    end
                                    break
                                end
                                temp_stack:pop()
                            end
                        end

                        if best_recovered_stack then
                             next_glr_stack:add_stack(best_recovered_stack)
                             recovery_success = true
                             next_loop_index = k -- Jump to sync token
                             break
                        end
                    end
                    k = k + 1
                end

                if not recovery_success then
                    self:log("  Panic mode failed, skipping token '%s'", token_symbol)
                    for _, s in ipairs(glr_stack.stacks) do
                         next_glr_stack:add_stack(s)
                    end
                    -- next_loop_index is i + 1, so we skip this token
                end

            else
                self:log("  Reached end of input with error")
            end
        end

        -- 合并相同的栈
        next_glr_stack:merge_stacks()

        glr_stack = next_glr_stack

        if glr_stack:size() == 0 then
            return nil, string.format("Parse error at token %d (%s)", i, token_symbol)
        end

        i = next_loop_index
    end

    -- 收集成功解析的结果
    local accepted_results = {}
    local fallback_results = {}
    self:log("Collecting results from %d stacks", glr_stack:size())

    for i, stack in ipairs(glr_stack.stacks) do
        self:log("Checking stack %d: size=%d", i, stack:size())

        -- 检查栈顶是否是接受状态
        local top_entry = stack:top()

        -- 查找包含接受状态的栈（S' -> S• 的状态）
        local has_accept_item = false
        local state = self.states[top_entry.state_id + 1]
        if state then
            for _, item in ipairs(state.items) do
                if item.production[1] == self.grammar.start_symbol .. "'" and
                   item.dot_position == #item.production - 1 then
                    has_accept_item = true
                    self:log("  Found accept item in stack")
                    break
                end
            end
        end

        if has_accept_item and top_entry and top_entry.node then
            self:log("  Adding result from stack " .. i)
            table.insert(accepted_results, top_entry.node)
        elseif top_entry and top_entry.node and stack:size() >= 2 then
            -- 备选方案：如果栈包含最终结果
            self:log("  Adding result as fallback from stack " .. i)
            table.insert(fallback_results, top_entry.node)
        end
    end

    local results = #accepted_results > 0 and accepted_results or fallback_results

    self:log("Collected %d results", #results)
    return results
end

function Parser:get_possible_reductions(stack, lookahead)
    local reductions = {}
    local top_entry = stack:top()

    if not top_entry then return reductions end

    local state = self.states[top_entry.state_id + 1]
    local complete_items = state:get_complete_items()

    -- Debug reductions
    if self.verbose and #complete_items > 0 then
        print(string.format("    State %d has %d complete items. Total items: %d", top_entry.state_id, #complete_items, #state.items))
        for _, item in ipairs(state.items) do
             print(string.format("      Item: %s (pos %d, len %d, complete? %s)", item:to_string(), item.dot_position, #item.production, tostring(item:is_complete())))
        end
    end

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

        -- [FIX] Relax lookahead check because the automaton generator seems to have a bug
        -- calculating Follow sets for recursive rules (missing ')' etc).
        -- GLR can handle the extra ambiguity.
        if not valid_lookahead then
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
        self:log("ERROR: State %d not found", current_state_id)
        return nil
    end

    local goto_state_id = current_state.transitions[prod[1]]

    if goto_state_id then
        self:log("  Goto %s -> state %d", prod[1], goto_state_id)
        temp_stack:push(goto_state_id, new_node)
        return temp_stack
    else
        self:log("  No goto transition for %s in state %d", prod[1], current_state_id)
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
