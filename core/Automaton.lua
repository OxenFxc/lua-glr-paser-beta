-- Automaton.lua
-- LR自动机构建模块

local Automaton = {}
Automaton.__index = Automaton

local Grammar = require("core.Grammar")
local Item = require("core.Item")
local State = require("core.State")

function Automaton:new(grammar, verbose)
    local self = setmetatable({}, Automaton)
    self.grammar = grammar
    self.verbose = verbose or false
    self.states = {}          -- 状态列表
    self.state_map = {}       -- state_key -> state_id，用于检测重复状态
    self.start_state = nil
    self.lookahead_debug_file = nil
    return self
end

function Automaton:build()
    if self.verbose then
        print("Building LR automaton...")
    end

    -- 计算FIRST和FOLLOW集
    self.grammar:compute_first_sets()
    self.grammar:compute_follow_sets()

    -- 创建初始状态
    local initial_items = self:create_initial_items()
    local initial_state = State:new(0)
    for _, item in ipairs(initial_items) do
        initial_state:add_item(item)
    end

    table.insert(self.states, initial_state)
    self.state_map[initial_state:to_key()] = 0
    self.start_state = initial_state

    -- 构建状态图
    local state_queue = {0}
    local processed = {}
    local queue_iterations = 0
    local max_queue_iterations = 1000  -- 防止状态队列无限循环
    local start_time = os.clock()

    if self.verbose then
        print("Starting state graph construction...")
    end

    while #state_queue > 0 and queue_iterations < max_queue_iterations do
        queue_iterations = queue_iterations + 1
        local state_id = table.remove(state_queue, 1)

        if processed[state_id] then
            goto continue
        end
        processed[state_id] = true

        -- 每50次迭代输出一次调试信息
        if self.verbose and queue_iterations % 50 == 0 then
            print(string.format("Processed %d states, %d remaining in queue", queue_iterations, #state_queue))
        end

        local state = self.states[state_id + 1]  -- Lua数组从1开始

        -- 按符号分组转换
        local transitions = {}

        for _, item in ipairs(state.items) do
            local next_symbol = item:next_symbol()
            if next_symbol then
                if not transitions[next_symbol] then
                    transitions[next_symbol] = {}
                end
                table.insert(transitions[next_symbol], item)
            end
        end

        -- 为每个转换创建新状态
        for symbol, items in pairs(transitions) do
            local new_items = {}

            -- 前移点位置
            for _, item in ipairs(items) do
                local advanced = item:advance_dot()
                if advanced then
                    table.insert(new_items, advanced)
                end
            end

            -- 计算闭包
            local closure_items = self:compute_closure(new_items)

            -- 检查状态是否已存在
            local new_state = State:new()
            for _, item in ipairs(closure_items) do
                new_state:add_item(item)
            end

            local state_key = new_state:to_key()
            local existing_state_id = self.state_map[state_key]

            if not existing_state_id then
                -- 创建新状态
                existing_state_id = #self.states
                new_state.id = existing_state_id
                table.insert(self.states, new_state)
                self.state_map[state_key] = existing_state_id
                table.insert(state_queue, existing_state_id)
            end

            -- 添加转换
            state.transitions[symbol] = existing_state_id
        end

        ::continue::
    end

    -- 状态队列处理结束
    self:monitor_loop_performance("State Graph Construction", start_time, queue_iterations, #self.states, max_queue_iterations)

    -- 关闭调试文件
    if self.lookahead_debug_file then
        self.lookahead_debug_file:close()
        self.lookahead_debug_file = nil
    end

    if self.verbose then
        print(string.format("Built automaton with %d states", #self.states))
    end
    return self.states
end

function Automaton:create_initial_items()
    local items = {}

    -- 添加增广起始产生式
    local augmented_start = self.grammar.start_symbol .. "'"
    table.insert(self.grammar.productions, 1, {augmented_start, self.grammar.start_symbol})
    self.grammar.nonterminals[augmented_start] = true

    -- 创建初始项
    local initial_item = Item:new({augmented_start, self.grammar.start_symbol}, 0, {"$"})
    table.insert(items, initial_item)

    return self:compute_closure(items)
end

function Automaton:compute_closure(items)
    local closure_items = {}
    for _, item in ipairs(items) do
        table.insert(closure_items, item:clone())
    end

    local changed = true
    local iterations = 0
    local max_iterations = 200  -- 增加最大迭代次数以处理复杂文法

    -- 循环调试信息
    local initial_item_count = #closure_items
    local start_time = os.clock()

    if self.verbose then
        print(string.format("Starting closure computation with %d initial items", initial_item_count))
    end

    while changed and iterations < max_iterations do
        changed = false
        iterations = iterations + 1

        -- 每10次迭代输出一次调试信息
        if self.verbose and iterations % 10 == 0 then
            print(string.format("Closure iteration %d: %d items", iterations, #closure_items))
        end

        local new_items = {}

        for _, item in ipairs(closure_items) do
            local next_symbol = item:next_symbol()
            if next_symbol and self.grammar.nonterminals[next_symbol] then
                -- 为非终结符找到所有产生式
                local productions = self.grammar:get_productions_for_symbol(next_symbol)

                for _, prod in ipairs(productions) do
                    -- 计算lookahead
                    local lookaheads = self:compute_lookahead(item, prod)

                    local new_item = Item:new(prod, 0, lookaheads)

                    -- 检查是否已存在
                    local exists = false
                    for _, existing in ipairs(closure_items) do
                        if existing:equals(new_item) then
                            exists = true
                            break
                        end
                    end

                    if not exists then
                        table.insert(new_items, new_item)
                        changed = true
                    end
                end
            elseif not next_symbol and item:is_complete() then
                -- 处理完整的项：查找引用此非终结符的产生式
                local lhs_symbol = item.production[1]
                if self.grammar.nonterminals[lhs_symbol] then
                    -- 查找所有引用lhs_symbol的产生式
                    for ref_lhs, ref_prods in pairs(self.grammar.productions) do
                        for _, ref_prod in ipairs(ref_prods) do
                            -- 检查ref_prod是否包含lhs_symbol
                            for i, symbol in ipairs(ref_prod) do
                                if symbol == lhs_symbol then
                                    -- 创建新项：ref_lhs -> ... • lhs_symbol ...
                                    local new_prod = {}
                                    for _, s in ipairs(ref_prod) do
                                        table.insert(new_prod, s)
                                    end

                                    -- 计算lookahead：使用当前项的lookaheads
                                    local lookaheads = {}
                                    for _, la in ipairs(item.lookaheads) do
                                        table.insert(lookaheads, la)
                                    end

                                    local new_item = Item:new(new_prod, i-1, lookaheads)

                                    -- 检查是否已存在
                                    local exists = false
                                    for _, existing in ipairs(closure_items) do
                                        if existing:equals(new_item) then
                                            exists = true
                                            break
                                        end
                                    end

                                    if not exists then
                                        table.insert(new_items, new_item)
                                        changed = true
                                    end
                                    break -- 只为每个产生式创建一个项
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 添加新项到闭包
        for _, item in ipairs(new_items) do
            table.insert(closure_items, item)
        end
    end

    -- 循环结束处理
    self:monitor_loop_performance("Closure Computation", start_time, iterations, #closure_items, max_iterations)

    -- 特殊处理：修正终结符产生式的lookahead
    local terminal_fixes = 0
    for _, item in ipairs(closure_items) do
        if #item.production == 2 and not self.grammar.nonterminals[item.production[2]] and item.dot_position == 1 then
            -- 这是一个完整的终结符产生式，如 F -> num •
            -- 使用 FOLLOW(item.production[1]) 作为lookahead
            local follow_set = self.grammar.follow_sets[item.production[1]]
            if follow_set then
                local old_count = #item.lookaheads
                item.lookaheads = {}
                for sym, _ in pairs(follow_set) do
                    table.insert(item.lookaheads, sym)
                end
                terminal_fixes = terminal_fixes + 1
                if self.verbose and old_count ~= #item.lookaheads then
                    print(string.format("   Fixed %s: %d -> %d lookaheads", item:to_string(), old_count, #item.lookaheads))
                end
            end
        end
    end

    if self.verbose and terminal_fixes > 0 then
        print(string.format("✅ Applied terminal lookahead fixes to %d items", terminal_fixes))
    end

    return closure_items
end

function Automaton:compute_lookahead(item, prod)
    -- 对于LR(1)项 A -> α • B β {L}，新项 B -> • γ 的lookahead是 FIRST(β L)

    -- 调试：记录函数调用
    if self.verbose and prod[1] == "F" and prod[2] == "num" then
        if not self.lookahead_debug_file then
            self.lookahead_debug_file = io.open("debug_compute_lookahead.log", "a")
        end
        local debug_file = self.lookahead_debug_file
        if debug_file then
            debug_file:write(string.format("compute_lookahead called: item=%s, prod={%s}\n",
                item:to_string(), table.concat(prod, ", ")))
        end
    end

    -- 获取β（点后的符号）
    local beta = {}
    local next_pos = item.dot_position + 2
    if next_pos <= #item.production then
        for i = next_pos, #item.production do
            table.insert(beta, item.production[i])
        end
    end

    -- 计算 FIRST(β L)
    local beta_L = {}
    for _, sym in ipairs(beta) do
        table.insert(beta_L, sym)
    end
    for _, la in ipairs(item.lookaheads) do
        table.insert(beta_L, la)
    end

    local first_beta_L = self:first_of_symbols(beta_L)

    -- 提取非epsilon符号作为lookahead
    local lookaheads = {}
    for sym, _ in pairs(first_beta_L) do
        if sym ~= "" then
            table.insert(lookaheads, sym)
        end
    end

    -- 如果 FIRST(β L) 包含epsilon，则也包含原始的L
    if first_beta_L[""] then
        for _, la in ipairs(item.lookaheads) do
            table.insert(lookaheads, la)
        end
    end


    -- 去重
    local unique_lookaheads = {}
    for _, la in ipairs(lookaheads) do
        unique_lookaheads[la] = true
    end

    lookaheads = {}
    for la, _ in pairs(unique_lookaheads) do
        table.insert(lookaheads, la)
    end

    return lookaheads
end

-- 循环性能监控
function Automaton:monitor_loop_performance(operation_name, start_time, iterations, item_count, max_limit)
    local end_time = os.clock()
    local duration = end_time - start_time

    if iterations >= max_limit then
        print(string.rep("!", 50))
        print(string.format("🚨 PERFORMANCE WARNING: %s", operation_name))
        print(string.format("   Reached maximum limit: %d iterations", max_limit))
        print(string.format("   Final item count: %d", item_count))
        print(string.format("   Duration: %.4f seconds", duration))
        print(string.format("   Average time per iteration: %.6f seconds", duration / iterations))
        print("   Possible causes:")
        print("   - Complex grammar with many productions")
        print("   - Large number of non-terminal symbols")
        print("   - Deep recursion in grammar rules")
        print(string.rep("!", 50))
    else
        if self.verbose then
            print(string.format("📊 %s Performance:", operation_name))
            print(string.format("   Iterations: %d", iterations))
            print(string.format("   Final item count: %d", item_count))
            print(string.format("   Duration: %.4f seconds", duration))
            if iterations > 0 then
                print(string.format("   Average time per iteration: %.6f seconds", duration / iterations))
            end
        end
    end
end

function Automaton:first_of_symbols(symbols)
    local first = {}

    if #symbols == 0 then
        first[""] = true
        return first
    end

    for i, symbol in ipairs(symbols) do
        local symbol_first = self.grammar.first_sets[symbol] or {[symbol] = true}

        for sym, _ in pairs(symbol_first) do
            if sym ~= "" then
                first[sym] = true
            end
        end

        if not symbol_first[""] then
            break
        end

        if i == #symbols then
            first[""] = true
        end
    end

    return first
end

function Automaton:print_states()
    for _, state in ipairs(self.states) do
        print(state:to_string())
        print()
    end
end

return Automaton
