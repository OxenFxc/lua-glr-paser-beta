-- GLR.lua
-- GLR解析器主入口模块

local GLR = {}

-- 导入所有模块
local Grammar = require("core.Grammar")
local LuaGrammar = require("core.LuaGrammar")
local Parser = require("parsing.Parser")
local Tokenizer = require("utils.Tokenizer")
local Utils = require("utils.Utils")

-- 创建GLR解析器实例
function GLR.new()
    local self = setmetatable({}, {__index = GLR})
    self.grammar = Grammar:new()
    self.parser = Parser:new(self.grammar)
    self.tokenizer = Tokenizer.create_simple()
    return self
end

-- 添加产生式
function GLR:add_production(lhs, rhs)
    self.grammar:add_production(lhs, rhs)
    return self
end

-- 设置分词器
function GLR:set_tokenizer(tokenizer)
    self.tokenizer = tokenizer
    self.parser:set_tokenizer(function(input)
        local tokens = self.tokenizer:tokenize(input)
        local values = {}
        for _, token in ipairs(tokens) do
            if token.type ~= "EOF" then
                table.insert(values, token.value)
            end
        end
        return values
    end)
    return self
end

-- 使用预定义分词器
function GLR:use_simple_tokenizer()
    self.tokenizer = Tokenizer.create_simple()

    -- 设置分词器函数
    self.parser:set_tokenizer(function(input)
        local tokens = self.tokenizer:tokenize(input)
        local values = {}
        for _, token in ipairs(tokens) do
            if token.type ~= "EOF" and token.type ~= "WHITESPACE" then
                table.insert(values, token.value)
            end
        end
        table.insert(values, "$")  -- 添加结束标记
        return values
    end)

    return self
end

-- 自定义分词方法
function GLR:tokenize_math(input)
    if not self.tokenizer then
        error("Tokenizer not initialized")
    end

    local tokens = self.tokenizer:tokenize(input)
    local values = {}
    for _, token in ipairs(tokens) do
        if token.type ~= "EOF" and token.type ~= "WHITESPACE" then
            -- 将数字token映射为"num"
            if token.type == "NUMBER" then
                table.insert(values, "num")
            else
                table.insert(values, token.value)
            end
        end
    end
    table.insert(values, "$")  -- 添加结束标记
    return values
end

function GLR:use_math_tokenizer()
    self.tokenizer = Tokenizer.create_math()

    -- 设置分词器函数
    self.parser:set_tokenizer(function(input)
        return self:tokenize_math(input)
    end)

    return self
end

function GLR:tokenize_programming(input)
    local tokens = self.tokenizer:tokenize(input)
    local values = {}
    for _, token in ipairs(tokens) do
        if token.type ~= "EOF" and token.type ~= "WHITESPACE" and token.type ~= "COMMENT" then
            if token.type == "NUMBER" then
                table.insert(values, "num")
            elseif token.type == "IDENTIFIER" then
                table.insert(values, "id")
            elseif token.type == "STRING" then
                table.insert(values, "string")
            else
                table.insert(values, token.value)
            end
        end
    end
    table.insert(values, "$")  -- 添加结束标记
    return values
end

function GLR:use_programming_tokenizer()
    self.tokenizer = Tokenizer.create_programming()

    -- 设置分词器函数
    self.parser:set_tokenizer(function(input)
        return self:tokenize_programming(input)
    end)

    return self
end

-- 构建自动机
function GLR:build()
    print("Building GLR parser...")
    local success, err = pcall(function()
        self.parser:build_automaton()
    end)

    if not success then
        error("Failed to build automaton: " .. err)
    end

    print("GLR parser built successfully")
    return self
end

-- 解析输入
function GLR:parse(input)
    if not self.parser.states then
        self:build()
    end

    print("Parsing input: " .. input)
    local success, result, err = pcall(function()
        return self.parser:parse(input)
    end)

    if not success then
        error("Parse error: " .. result)
    end

    if not result then
        error("Parse failed: " .. (err or "Unknown error"))
    end

    return result
end

-- 打印解析树
function GLR:print_tree(tree, indent)
    indent = indent or ""
    if type(tree) == "table" and tree.type == "terminal" then
        print(indent .. tree.value)
    elseif type(tree) == "table" and tree.type == "nonterminal" then
        print(indent .. tree.symbol)
        if tree.children then
            for _, child in ipairs(tree.children) do
                self:print_tree(child, indent .. "  ")
            end
        end
    else
        print(indent .. tostring(tree))
    end
end

-- 打印所有解析树
function GLR:print_parse_trees(trees)
    if not trees or #trees == 0 then
        print("No parse trees found")
        return
    end

    print(string.format("Found %d parse tree(s):", #trees))
    for i, tree in ipairs(trees) do
        print(string.format("\nParse Tree %d:", i))
        self:print_tree(tree)
    end
end

-- 打印自动机
function GLR:print_automaton()
    self.parser:print_automaton()
end

-- 打印文法
function GLR:print_grammar()
    print("Grammar:")
    print(self.grammar:to_string())
end

-- 获取文法信息
function GLR:get_grammar_info()
    return {
        productions = #self.grammar.productions,
        nonterminals = Utils.set_to_list(self.grammar.nonterminals),
        terminals = Utils.set_to_list(self.grammar.terminals),
        start_symbol = self.grammar.start_symbol
    }
end

-- 获取自动机信息
function GLR:get_automaton_info()
    if not self.parser.states then
        return {states = 0}
    end

    return {
        states = #self.parser.states,
        built = true
    }
end

-- 创建预定义的文法
function GLR.create_math_grammar()
    local glr = GLR.new()

    -- 算术表达式文法
    glr:add_production("E", {"E", "+", "T"})
    glr:add_production("E", {"E", "-", "T"})
    glr:add_production("E", {"T"})
    glr:add_production("T", {"T", "*", "F"})
    glr:add_production("T", {"T", "/", "F"})
    glr:add_production("T", {"F"})
    glr:add_production("F", {"(", "E", ")"})
    glr:add_production("F", {"num"})

    glr:use_math_tokenizer()
    return glr
end

function GLR.create_simple_grammar()
    local glr = GLR.new()

    -- 简单文法：S -> a S | a
    glr:add_production("S", {"a", "S"})
    glr:add_production("S", {"a"})

    return glr
end

function GLR.create_programming_grammar()
    local glr = GLR.new()

    -- 简化的编程语言文法（更容易解析）
    glr:add_production("Program", {"Statements"})
    glr:add_production("Statements", {"Statement", "Statements"})
    glr:add_production("Statements", {"Statement"})
    glr:add_production("Statement", {"if", "Expression", "then", "Statements", "end"})
    glr:add_production("Statement", {"if", "Expression", "then", "Statements", "else", "Statements", "end"})
    glr:add_production("Statement", {"Expression"})
    glr:add_production("Expression", {"Expression", "+", "Term"})
    glr:add_production("Expression", {"Expression", "-", "Term"})
    glr:add_production("Expression", {"Term"})
    glr:add_production("Term", {"Term", "*", "Factor"})
    glr:add_production("Term", {"Term", "/", "Factor"})
    glr:add_production("Term", {"Factor"})
    glr:add_production("Factor", {"(", "Expression", ")"})
    glr:add_production("Factor", {"num"})
    glr:add_production("Factor", {"id"})

    glr:use_programming_tokenizer()
    return glr
end

function GLR.create_lua_grammar()
    local glr = GLR.new()
    LuaGrammar.define(glr)
    glr:use_programming_tokenizer()
    return glr
end

return GLR
