-- Tokenizer.lua
-- 分词器模块

local Tokenizer = {}
Tokenizer.__index = Tokenizer

function Tokenizer:new()
    local self = setmetatable({}, Tokenizer)
    self.rules = {}  -- 分词规则列表 {pattern, type, match}
    return self
end

function Tokenizer:add_rule(pattern, token_type)
    if type(pattern) == "function" then
        table.insert(self.rules, {match = pattern, type = token_type})
    else
        table.insert(self.rules, {pattern = pattern, type = token_type})
    end
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

-- Generic function to add a rule that checks keywords
function Tokenizer:add_keyword_rule(keywords)
    self:add_rule(function(input, pos)
        local s, e = input:find("^%a[%w_]*", pos)
        if not s then return nil end

        local id = input:sub(s, e)
        -- Check if it is a keyword
        -- keywords table can be set or list. If list, convert to set?
        -- Assuming keywords is a map: keyword -> type
        if keywords[id] then
            return keywords[id], id, e + 1
        elseif keywords[id:upper()] then
             -- Try uppercase check if keywords are stored as uppercase?
             -- Usually Lua keywords are case sensitive.
             return keywords[id:upper()], id, e + 1
        else
            return "IDENTIFIER", id, e + 1
        end
    end)
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

-- Lua-style long string matcher: [=*[ ... ]=*]
function Tokenizer.match_long_string(input, pos)
    local s, e = input:find("^%[=*%[", pos)
    if not s then return nil end

    local equals = input:sub(s + 1, e - 1)
    local close = "]" .. equals .. "]"

    local cs, ce = input:find(close, e + 1, true)
    if not cs then
        error("Unclosed long string/comment starting at " .. pos)
    end

    return input:sub(s, ce), ce + 1
end

-- Lua-style string literal matcher (short strings)
function Tokenizer.match_string_literal(input, pos)
    local s, e = input:find("^[\"']", pos)
    if not s then return nil end

    local quote = input:sub(s, e)
    local current = e + 1
    while current <= #input do
        local char = input:sub(current, current)
        if char == quote then
            return input:sub(s, current), current + 1
        elseif char == "\\" then
            current = current + 2 -- Skip escaped char
        else
            current = current + 1
        end
    end

    error("Unclosed string literal starting at " .. pos)
end

function Tokenizer:tokenize(input)
    local tokens = {}
    local pos = 1

    while pos <= #input do
        local matched = false

        for _, rule in ipairs(self.rules) do
            if rule.match then
                -- Function based matcher
                -- Expected return: (type, value, new_pos) OR (value, new_pos)
                local r1, r2, r3 = rule.match(input, pos)

                local token_type, value, new_pos
                if r3 then
                    token_type = r1
                    value = r2
                    new_pos = r3
                elseif r2 then
                    token_type = rule.type
                    value = r1
                    new_pos = r2
                end

                if value then
                    if token_type ~= "WHITESPACE" and token_type ~= "COMMENT" then
                        table.insert(tokens, {
                            type = token_type,
                            value = value,
                            position = pos
                        })
                    end
                    pos = new_pos
                    matched = true
                    break
                end
            else
                -- Regex based matcher
                local pattern = rule.pattern
                local token_type = rule.type

                local start_pos, end_pos = input:find(pattern, pos)

                if start_pos == pos then
                    local matched_text = input:sub(start_pos, end_pos)

                    -- 跳过空白字符
                    if token_type ~= "WHITESPACE" and token_type ~= "COMMENT" then
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
        end

        if not matched then
            error(string.format("Unexpected character at position %d: '%s'",
                               pos, input:sub(pos, pos)))
        end
    end

    -- 添加结束标记
    table.insert(tokens, {
        type = "EOF",
        value = "$",  -- Use '$' as EOF value for compatibility with Parser
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

    -- Comments (Short and Long)
    -- Must be before simple rules because -- starts with -
    tokenizer:add_rule(function(input, pos)
        -- Check for long comment --[[ ... ]]
        local s, e = input:find("^%-%-%[=*%[", pos)
        if s then
            -- Reimplement long string logic to find the end
            local equals = input:match("^%-%-%[(=*)%[", pos)
            local close = "]" .. equals .. "]"
            local cs, ce = input:find(close, e + 1, true)
            if not cs then error("Unclosed long comment") end
            return "COMMENT", input:sub(s, ce), ce + 1
        end

        -- Check for short comment -- ...
        local s2, e2 = input:find("^%-%-[^\n]*", pos)
        if s2 then
            return "COMMENT", input:sub(s2, e2), e2 + 1
        end
        return nil
    end)

    -- 运算符（按长度降序排列）
    tokenizer:add_rule("%.%.%.", "DOTS") -- ...
    tokenizer:add_rule("%.%.", "CONCAT") -- ..
    tokenizer:add_rule("==", "EQUALS_EQUALS")
    tokenizer:add_rule("~=", "NOT_EQUALS")
    tokenizer:add_rule("<=", "LESS_EQUALS")
    tokenizer:add_rule(">=", "GREATER_EQUALS")
    tokenizer:add_rule("<", "LESS")
    tokenizer:add_rule(">", "GREATER")

    -- Other Lua operators/symbols
    tokenizer:add_rule("%[", "[")
    tokenizer:add_rule("%]", "]")
    tokenizer:add_rule("{", "{")
    tokenizer:add_rule("}", "}")
    tokenizer:add_rule("#", "#")
    tokenizer:add_rule(":", ":")
    tokenizer:add_rule(",", ",")
    tokenizer:add_rule("%.", ".") -- .

    -- Simple rules (including - and ;)
    tokenizer:add_simple_rules()

    -- 字符串字面量
    tokenizer:add_rule("^\"[^\"]*\"", "STRING")
    tokenizer:add_rule("^'[^']*'", "STRING")

    -- 数字
    tokenizer:add_number_rule()

    -- 关键字和标识符
    local keywords = {
        ["if"] = "if", ["then"] = "then", ["else"] = "else", ["elseif"] = "elseif",
        ["while"] = "while", ["do"] = "do", ["repeat"] = "repeat", ["until"] = "until",
        ["for"] = "for", ["in"] = "in", ["function"] = "function", ["end"] = "end",
        ["local"] = "local", ["return"] = "return", ["break"] = "break", ["goto"] = "goto",
        ["true"] = "true", ["false"] = "false", ["nil"] = "nil",
        ["and"] = "and", ["or"] = "or", ["not"] = "not",
        ["global"] = "global"
    }

    tokenizer:add_keyword_rule(keywords)

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
