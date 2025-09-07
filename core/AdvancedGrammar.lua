-- core/AdvancedGrammar.lua
-- 高级编程语言文法，支持函数、闭包、循环控制

local Grammar = require("core.Grammar")

local AdvancedGrammar = {}
AdvancedGrammar.__index = AdvancedGrammar

function AdvancedGrammar.new()
    local self = setmetatable({}, AdvancedGrammar)

    -- 创建基础文法
    self.grammar = Grammar:new()

    -- 定义非终结符
    local nonterminals = {
        "program", "statement", "expression", "function_def", "closure",
        "loop_statement", "if_statement", "assignment", "declaration",
        "block", "parameter_list", "argument_list", "type_specifier",
        "literal", "identifier", "operator", "control_flow"
    }

    -- 在Grammar中，非终结符和终结符是通过add_production自动识别的
    -- 这里我们定义所有需要的终结符符号，供后续使用
    self.terminals = {
        "function", "end", "if", "then", "else", "elseif", "while", "for", "do",
        "repeat", "until", "return", "local", "var", "const", "type",
        "number", "string", "boolean", "nil", "true", "false",
        "identifier", "number_literal", "string_literal",
        "+", "-", "*", "/", "%", "^", "=", "==", "~=", "<", "<=", ">", ">=",
        "and", "or", "not", "(", ")", "[", "]", "{", "}", ",", ".", ":",
        ";", "->", "=>", "||", "&&", "!", "++", "--", "+=", "-=", "*=", "/="
    }

    self:define_productions()
    return self
end

function AdvancedGrammar:define_productions()
    -- 程序结构
    self.grammar:add_production("program", {"statement"})
    self.grammar:add_production("program", {"statement", "program"})

    -- 语句
    self.grammar:add_production("statement", {"function_def"})
    self.grammar:add_production("statement", {"closure"})
    self.grammar:add_production("statement", {"loop_statement"})
    self.grammar:add_production("statement", {"if_statement"})
    self.grammar:add_production("statement", {"assignment", ";"})
    self.grammar:add_production("statement", {"declaration", ";"})
    self.grammar:add_production("statement", {"expression", ";"})
    self.grammar:add_production("statement", {"control_flow", ";"})
    self.grammar:add_production("statement", {"block"})

    -- 函数定义
    self.grammar:add_production("function_def", {"function", "identifier", "(", "parameter_list", ")", "block", "end"})
    self.grammar:add_production("function_def", {"local", "function", "identifier", "(", "parameter_list", ")", "block", "end"})

    -- 闭包
    self.grammar:add_production("closure", {"function", "(", "parameter_list", ")", "block", "end"})
    self.grammar:add_production("closure", {"(", "parameter_list", ")", "->", "expression"})
    self.grammar:add_production("closure", {"(", "parameter_list", ")", "=>", "{", "block", "}"})

    -- 循环语句
    self.grammar:add_production("loop_statement", {"while", "expression", "do", "block", "end"})
    self.grammar:add_production("loop_statement", {"for", "identifier", "=", "expression", ",", "expression", "do", "block", "end"})
    self.grammar:add_production("loop_statement", {"for", "identifier", "=", "expression", ",", "expression", ",", "expression", "do", "block", "end"})
    self.grammar:add_production("loop_statement", {"repeat", "block", "until", "expression"})

    -- 条件语句
    self.grammar:add_production("if_statement", {"if", "expression", "then", "block", "end"})
    self.grammar:add_production("if_statement", {"if", "expression", "then", "block", "else", "block", "end"})
    self.grammar:add_production("if_statement", {"if", "expression", "then", "block", "elseif", "if_statement"})

    -- 赋值语句
    self.grammar:add_production("assignment", {"identifier", "=", "expression"})
    self.grammar:add_production("assignment", {"identifier", "+=", "expression"})
    self.grammar:add_production("assignment", {"identifier", "-=", "expression"})
    self.grammar:add_production("assignment", {"identifier", "*=", "expression"})
    self.grammar:add_production("assignment", {"identifier", "/=", "expression"})
    self.grammar:add_production("assignment", {"identifier", "[", "expression", "]", "=", "expression"})

    -- 声明语句
    self.grammar:add_production("declaration", {"local", "identifier", "=", "expression"})
    self.grammar:add_production("declaration", {"local", "identifier", ":", "type_specifier", "=", "expression"})
    self.grammar:add_production("declaration", {"var", "identifier", "=", "expression"})
    self.grammar:add_production("declaration", {"const", "identifier", "=", "expression"})

    -- 代码块
    self.grammar:add_production("block", {"{", "statement", "}"})
    self.grammar:add_production("block", {"{", "statement", "block", "}"})

    -- 参数列表
    self.grammar:add_production("parameter_list", {})  -- 空参数
    self.grammar:add_production("parameter_list", {"identifier"})
    self.grammar:add_production("parameter_list", {"identifier", ",", "parameter_list"})
    self.grammar:add_production("parameter_list", {"identifier", ":", "type_specifier"})
    self.grammar:add_production("parameter_list", {"identifier", ":", "type_specifier", ",", "parameter_list"})

    -- 参数传递列表
    self.grammar:add_production("argument_list", {})  -- 空参数
    self.grammar:add_production("argument_list", {"expression"})
    self.grammar:add_production("argument_list", {"expression", ",", "argument_list"})

    -- 类型说明符
    self.grammar:add_production("type_specifier", {"number"})
    self.grammar:add_production("type_specifier", {"string"})
    self.grammar:add_production("type_specifier", {"boolean"})
    self.grammar:add_production("type_specifier", {"identifier"})  -- 自定义类型

    -- 控制流
    self.grammar:add_production("control_flow", {"return", "expression"})
    self.grammar:add_production("control_flow", {"return"})
    self.grammar:add_production("control_flow", {"break"})
    self.grammar:add_production("control_flow", {"continue"})

    -- 表达式
    self.grammar:add_production("expression", {"literal"})
    self.grammar:add_production("expression", {"identifier"})
    self.grammar:add_production("expression", {"function_call"})
    self.grammar:add_production("expression", {"closure"})
    self.grammar:add_production("expression", {"(", "expression", ")"})
    self.grammar:add_production("expression", {"expression", "operator", "expression"})
    self.grammar:add_production("expression", {"not", "expression"})
    self.grammar:add_production("expression", {"-", "expression"})
    self.grammar:add_production("expression", {"expression", "[", "expression", "]"})
    self.grammar:add_production("expression", {"expression", ".", "identifier"})
    self.grammar:add_production("expression", {"expression", ":", "identifier", "(", "argument_list", ")"})

    -- 函数调用
    self.grammar:add_production("function_call", {"identifier", "(", "argument_list", ")"})
    self.grammar:add_production("function_call", {"expression", "(", "argument_list", ")"})

    -- 字面量
    self.grammar:add_production("literal", {"number_literal"})
    self.grammar:add_production("literal", {"string_literal"})
    self.grammar:add_production("literal", {"true"})
    self.grammar:add_production("literal", {"false"})
    self.grammar:add_production("literal", {"nil"})
    self.grammar:add_production("literal", {"{", "}"})
    self.grammar:add_production("literal", {"{", "expression", "}"})
    self.grammar:add_production("literal", {"[", "]"})
    self.grammar:add_production("literal", {"[", "expression", "]"})

    -- 运算符
    self.grammar:add_production("operator", {"+"})
    self.grammar:add_production("operator", {"-"})
    self.grammar:add_production("operator", {"*"})
    self.grammar:add_production("operator", {"/"})
    self.grammar:add_production("operator", {"%"})
    self.grammar:add_production("operator", {"^"})
    self.grammar:add_production("operator", {"=="})
    self.grammar:add_production("operator", {"~="})
    self.grammar:add_production("operator", {"<"})
    self.grammar:add_production("operator", {"<="})
    self.grammar:add_production("operator", {">"})
    self.grammar:add_production("operator", {">="})
    self.grammar:add_production("operator", {"and"})
    self.grammar:add_production("operator", {"or"})
    self.grammar:add_production("operator", {"&&"})
    self.grammar:add_production("operator", {"||"})
end

function AdvancedGrammar:build()
    self.grammar:compute_first_sets()
    self.grammar:compute_follow_sets()
    return self.grammar
end

function AdvancedGrammar:get_grammar()
    return self.grammar
end

return AdvancedGrammar
