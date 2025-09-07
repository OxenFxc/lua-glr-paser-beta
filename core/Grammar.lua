-- Grammar.lua
-- 文法定义和处理模块

local Grammar = {}
Grammar.__index = Grammar

function Grammar:new()
    local self = setmetatable({}, Grammar)
    self.productions = {}      -- 产生式列表 {{lhs, rhs1, rhs2, ...}, ...}
    self.nonterminals = {}     -- 非终结符集合
    self.terminals = {}        -- 终结符集合
    self.start_symbol = nil    -- 起始符号
    self.first_sets = {}       -- FIRST集
    self.follow_sets = {}      -- FOLLOW集
    return self
end

function Grammar:add_production(lhs, rhs)
    if not self.start_symbol then
        self.start_symbol = lhs
    end

    table.insert(self.productions, {lhs, table.unpack(rhs)})
    self.nonterminals[lhs] = true

    -- 识别终结符和非终结符
    for _, symbol in ipairs(rhs) do
        if not self.nonterminals[symbol] then
            self.terminals[symbol] = true
        end
    end
end

function Grammar:compute_first_sets()
    local first = {}

    -- 初始化FIRST集
    for nt, _ in pairs(self.nonterminals) do
        first[nt] = {}
    end
    for t, _ in pairs(self.terminals) do
        first[t] = {[t] = true}
    end
    first[""] = {[""] = true}  -- epsilon

    local changed = true
    local iterations = 0
    local max_iterations = 100  -- 防止无限循环

    while changed and iterations < max_iterations do
        changed = false
        iterations = iterations + 1

        for _, prod in ipairs(self.productions) do
            local lhs = prod[1]
            local rhs = {table.unpack(prod, 2)}

            if #rhs == 0 then
                -- epsilon产生式
                if not first[lhs][""] then
                    first[lhs][""] = true
                    changed = true
                end
            else
                local i = 1
                while i <= #rhs do
                    local symbol = rhs[i]
                    local symbol_first = first[symbol]

                    if symbol_first then
                        -- 添加非epsilon符号
                        for sym, _ in pairs(symbol_first) do
                            if sym ~= "" and not first[lhs][sym] then
                                first[lhs][sym] = true
                                changed = true
                            end
                        end

                        -- 如果当前符号不能推导出epsilon，继续下一个
                        if not symbol_first[""] then
                            break
                        end
                    else
                        -- 终结符
                        if not first[lhs][symbol] then
                            first[lhs][symbol] = true
                            changed = true
                        end
                        break
                    end
                    i = i + 1
                end

                -- 如果所有符号都能推导出epsilon，添加epsilon到lhs
                if i > #rhs and not first[lhs][""] then
                    first[lhs][""] = true
                    changed = true
                end
            end
        end
    end

    if iterations >= max_iterations then
        error("FIRST set computation exceeded maximum iterations")
    end

    self.first_sets = first
    return first
end

function Grammar:compute_follow_sets()
    local follow = {}
    local first = self.first_sets

    -- 初始化FOLLOW集
    for nt, _ in pairs(self.nonterminals) do
        follow[nt] = {}
    end
    follow[self.start_symbol]["$"] = true

    local changed = true
    local iterations = 0
    local max_iterations = 100

    while changed and iterations < max_iterations do
        changed = false
        iterations = iterations + 1

        for _, prod in ipairs(self.productions) do
            local lhs = prod[1]
            local rhs = {table.unpack(prod, 2)}

            for i, symbol in ipairs(rhs) do
                if self.nonterminals[symbol] then
                    -- 计算后缀的FIRST集
                    local suffix_first = {}
                    local has_epsilon = true

                    for j = i + 1, #rhs do
                        local next_symbol = rhs[j]
                        local next_first = first[next_symbol] or {[next_symbol] = true}

                        for sym, _ in pairs(next_first) do
                            if sym ~= "" then
                                suffix_first[sym] = true
                            end
                        end

                        if not next_first[""] then
                            has_epsilon = false
                            break
                        end
                    end

                    -- 添加后缀FIRST到当前符号的FOLLOW
                    for sym, _ in pairs(suffix_first) do
                        if not follow[symbol][sym] then
                            follow[symbol][sym] = true
                            changed = true
                        end
                    end

                    -- 如果后缀可以为epsilon或这是最后一个符号，添加lhs的FOLLOW
                    if has_epsilon or i == #rhs then
                        for sym, _ in pairs(follow[lhs]) do
                            if not follow[symbol][sym] then
                                follow[symbol][sym] = true
                                changed = true
                            end
                        end
                    end
                end
            end
        end
    end

    if iterations >= max_iterations then
        error("FOLLOW set computation exceeded maximum iterations")
    end

    self.follow_sets = follow
    return follow
end

function Grammar:get_productions_for_symbol(symbol)
    local productions = {}
    for _, prod in ipairs(self.productions) do
        if prod[1] == symbol then
            table.insert(productions, prod)
        end
    end
    return productions
end

function Grammar:to_string()
    local lines = {}
    for _, prod in ipairs(self.productions) do
        local rhs = {}
        for i = 2, #prod do
            table.insert(rhs, prod[i])
        end
        table.insert(lines, string.format("%s -> %s", prod[1], table.concat(rhs, " ")))
    end
    return table.concat(lines, "\n")
end

return Grammar
