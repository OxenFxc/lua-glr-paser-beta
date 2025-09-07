-- Tokenizer.lua
-- 分词器模块

local Tokenizer = {}
Tokenizer.__index = Tokenizer

function Tokenizer:new()
    local self = setmetatable({}, Tokenizer)
    self.rules = {}  -- 分词规则列表 {pattern, token_type}
    return self
end

function Tokenizer:add_rule(pattern, token_type)
    table.insert(self.rules, {pattern = pattern, type = token_type})
end

function Tokenizer:add_simple_rules()
    -- 添加基本的数学运算符规则
    self:add_rule("%(", "LPAREN")
    self:add_rule("%)", "RPAREN")
    self:add_rule("%+", "PLUS")
    self:add_rule("%-", "MINUS")
    self:add_rule("%*", "MULTIPLY")
    self:add_rule("%/", "DIVIDE")
    self:add_rule("%^", "POWER")
    self:add_rule("=", "EQUALS")
    self:add_rule(";", "SEMICOLON")
end

function Tokenizer:add_keyword(keyword)
    -- 为关键字添加规则（需要转义特殊字符）
    local escaped = keyword:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    self:add_rule("^" .. escaped .. "%s*", keyword:upper())
end

function Tokenizer:add_number_rule()
    -- 添加数字规则
    self:add_rule("^%d+%.?%d*", "NUMBER")
end

function Tokenizer:add_identifier_rule()
    -- 添加标识符规则（字母开头，后跟字母数字或下划线）
    self:add_rule("^%a[%w_]*", "IDENTIFIER")
end

function Tokenizer:add_whitespace_rule()
    -- 添加空白字符跳过规则
    self:add_rule("^%s+", "WHITESPACE")
end

function Tokenizer:tokenize(input)
    local tokens = {}
    local pos = 1

    while pos <= #input do
        local matched = false

        for _, rule in ipairs(self.rules) do
            local pattern = rule.pattern
            local token_type = rule.type

            local start_pos, end_pos = input:find(pattern, pos)

            if start_pos == pos then
                local matched_text = input:sub(start_pos, end_pos)

                -- 跳过空白字符
                if token_type ~= "WHITESPACE" then
                    table.insert(tokens, {
                        type = token_type,
                        value = matched_text,
                        position = pos
                    })
                end

                pos = end_pos + 1
                matched = true
                break
            end
        end

        if not matched then
            error(string.format("Unexpected character at position %d: '%s'",
                               pos, input:sub(pos, pos)))
        end
    end

    -- 添加结束标记
    table.insert(tokens, {
        type = "EOF",
        value = "",
        position = #input + 1
    })

    return tokens
end

-- 预定义的简单分词器
function Tokenizer.create_simple()
    local tokenizer = Tokenizer:new()
    tokenizer:add_whitespace_rule()
    tokenizer:add_simple_rules()
    tokenizer:add_number_rule()
    tokenizer:add_identifier_rule()
    return tokenizer
end

-- 数学表达式分词器
function Tokenizer.create_math()
    local tokenizer = Tokenizer:new()
    tokenizer:add_whitespace_rule()
    tokenizer:add_simple_rules()
    tokenizer:add_number_rule()
    tokenizer:add_identifier_rule()
    return tokenizer
end

-- 编程语言分词器
function Tokenizer.create_programming()
    local tokenizer = Tokenizer:new()
    tokenizer:add_whitespace_rule()

    -- 关键字（必须在标识符之前）
    local keywords = {"if", "then", "else", "while", "for", "function", "end",
                     "local", "return", "true", "false", "nil", "and", "or", "not"}
    for _, keyword in ipairs(keywords) do
        tokenizer:add_keyword(keyword)
    end

    -- 运算符（按长度降序排列）
    tokenizer:add_rule("==", "EQUALS_EQUALS")
    tokenizer:add_rule("~=", "NOT_EQUALS")
    tokenizer:add_rule("<=", "LESS_EQUALS")
    tokenizer:add_rule(">=", "GREATER_EQUALS")
    tokenizer:add_rule("<", "LESS")
    tokenizer:add_rule(">", "GREATER")
    tokenizer:add_simple_rules()

    -- 字符串字面量
    tokenizer:add_rule("^\"[^\"]*\"", "STRING")
    tokenizer:add_rule("^'[^']*'", "STRING")

    -- 注释
    tokenizer:add_rule("^%-%-[^\n]*", "COMMENT")

    -- 数字（在标识符之前）
    tokenizer:add_number_rule()

    -- 标识符（最后匹配）
    tokenizer:add_identifier_rule()

    return tokenizer
end

function Tokenizer:print_tokens(tokens)
    print("Tokens:")
    for i, token in ipairs(tokens) do
        print(string.format("%d: %s '%s' at %d",
                          i, token.type, token.value, token.position))
    end
end

return Tokenizer
