-- core/ImprovedGLR.lua
-- 改进版GLR解析器，修复文法初始化问题

local Grammar = require("core.Grammar")
local Parser = require("parsing.Parser")
local Tokenizer = require("utils.Tokenizer")
local Utils = require("utils.Utils")
local ASTNode = require("core.ASTNode")

local ImprovedGLR = {}
ImprovedGLR.__index = ImprovedGLR

function ImprovedGLR.new()
    local self = setmetatable({}, ImprovedGLR)

    -- 初始化组件
    self.grammar = Grammar:new()
    self.parser = nil  -- 延迟初始化
    self.tokenizer = Tokenizer.create_simple()

    -- 解析状态
    self.is_built = false

    -- 调试信息
    self.debug_mode = false

    return self
end

-- 添加产生式
function ImprovedGLR:add_production(lhs, rhs)
    self.grammar:add_production(lhs, rhs)
    self.is_built = false  -- 标记需要重新构建
    return self
end

-- 批量添加产生式
function ImprovedGLR:add_productions(productions_table)
    for lhs, productions in pairs(productions_table) do
        for _, rhs in ipairs(productions) do
            self:add_production(lhs, rhs)
        end
    end
    return self
end

-- 构建解析器
function ImprovedGLR:build()
    if self.debug_mode then
        print("🔧 Building Improved GLR Parser...")
    end

    -- 验证文法
    if not self:validate_grammar() then
        error("Invalid grammar configuration")
    end

    -- 初始化解析器
    self.parser = Parser:new(self.grammar)

    -- 设置分词器
    self.parser:set_tokenizer(function(input)
        return self.tokenizer:tokenize(input)
    end)

    -- 构建自动机
    local success, err = pcall(function()
        self.parser:build_automaton()
    end)

    if not success then
        if self.debug_mode then
            print("❌ Automaton build failed: " .. err)
            print("🔍 Grammar state:")
            print("  Productions: " .. #self.grammar.productions)
            print("  Nonterminals: " .. self:count_table(self.grammar.nonterminals))
            print("  Terminals: " .. self:count_table(self.grammar.terminals))
            print("  Start symbol: " .. (self.grammar.start_symbol or "none"))
        end
        error("Failed to build automaton: " .. err)
    end

    self.is_built = true

    if self.debug_mode then
        print("✅ Improved GLR Parser built successfully")
        print("  States: " .. #self.parser.states)
        print("  Productions: " .. #self.grammar.productions)
    end

    return self
end

-- 验证文法
function ImprovedGLR:validate_grammar()
    if #self.grammar.productions == 0 then
        if self.debug_mode then
            print("⚠️  Warning: No productions defined")
        end
        return false
    end

    if not self.grammar.start_symbol then
        if self.debug_mode then
            print("⚠️  Warning: No start symbol defined")
        end
        return false
    end

    return true
end

-- 解析输入
function ImprovedGLR:parse(input)
    if not self.is_built then
        self:build()
    end

    if self.debug_mode then
        print("🔍 Parsing input: " .. input:sub(1, 50) .. (input:len() > 50 and "..." or ""))
    end

    -- 分词
    local tokens = self.tokenizer:tokenize(input)

    if self.debug_mode then
        print("📝 Tokenized input: " .. #tokens .. " tokens")
        for i, token in ipairs(tokens) do
            if i <= 5 then  -- 只显示前5个token
                print(string.format("  %d: %s (%s)", i, token.value or token, token.type or "unknown"))
            elseif i == 6 then
                print("  ... (" .. (#tokens - 5) .. " more tokens)")
                break
            end
        end
    end

    -- 解析
    local success, result = pcall(function()
        return self.parser:parse(tokens)
    end)

    if not success then
        if self.debug_mode then
            print("❌ Parse failed: " .. result)
        end
        return nil, result
    end

    if self.debug_mode then
        print("✅ Parse successful")
        if result and result[1] then
            print("📊 Result type: " .. type(result[1]))
            if type(result[1]) == "table" and result[1].type then
                print("📊 AST node type: " .. result[1].type)
            end
        end
    end

    return result
end

-- 创建简单算术表达式文法
function ImprovedGLR.create_math_grammar()
    local glr = ImprovedGLR.new()

    -- 基本表达式文法
    glr:add_productions({
        E = {
            {"E", "+", "T"},
            {"E", "-", "T"},
            {"T"}
        },
        T = {
            {"T", "*", "F"},
            {"T", "/", "F"},
            {"F"}
        },
        F = {
            {"num"},
            {"(", "E", ")"}
        }
    })

    return glr
end

-- 创建函数文法
function ImprovedGLR.create_function_grammar()
    local glr = ImprovedGLR.new()

    glr:add_productions({
        program = {
            {"statement"},
            {"statement", "program"}
        },
        statement = {
            {"function_def"},
            {"assignment", ";"},
            {"expression", ";"}
        },
        function_def = {
            {"function", "identifier", "(", "parameter_list", ")", "block", "end"}
        },
        parameter_list = {
            {},  -- 空参数
            {"identifier"},
            {"identifier", ",", "parameter_list"}
        },
        block = {
            {"{", "statement", "}"},
            {"{", "}"}
        },
        assignment = {
            {"identifier", "=", "expression"}
        },
        expression = {
            {"identifier"},
            {"number_literal"},
            {"function_call"}
        },
        function_call = {
            {"identifier", "(", "argument_list", ")"}
        },
        argument_list = {
            {},  -- 空参数
            {"expression"},
            {"expression", ",", "argument_list"}
        }
    })

    return glr
end

-- 设置调试模式
function ImprovedGLR:set_debug(enabled)
    self.debug_mode = enabled
    return self
end

-- 工具函数
function ImprovedGLR:count_table(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- 获取解析器状态
function ImprovedGLR:get_status()
    return {
        is_built = self.is_built,
        productions_count = #self.grammar.productions,
        nonterminals_count = self:count_table(self.grammar.nonterminals),
        terminals_count = self:count_table(self.grammar.terminals),
        states_count = self.parser and #self.parser.states or 0,
        start_symbol = self.grammar.start_symbol
    }
end

return ImprovedGLR
