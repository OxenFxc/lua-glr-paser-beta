-- core/EnhancedParser.lua
-- 增强版解析器，支持更好的AST构建和错误处理

local ASTNode = require("core.ASTNode")
local AdvancedGrammar = require("core.AdvancedGrammar")

local EnhancedParser = {}
EnhancedParser.__index = EnhancedParser

function EnhancedParser.new()
    local self = setmetatable({}, EnhancedParser)

    -- 初始化文法
    self.grammar = AdvancedGrammar.new():build()

    -- 解析状态
    self.current_token_index = 1
    self.tokens = {}
    self.errors = {}

    -- AST构建器
    self.ast_builder = {
        current_scope = nil,
        scopes = {},
        symbol_table = {},
        temp_counter = 0
    }

    return self
end

-- 词法分析器（简化的）
function EnhancedParser:tokenize(input)
    self.tokens = {}
    local i = 1

    while i <= #input do
        local char = input:sub(i, i)

        -- 跳过空白字符
        if char:match("%s") then
            i = i + 1
        -- 标识符和关键字
        elseif char:match("[%a_]") then
            local start = i
            while i <= #input and input:sub(i, i):match("[%w_]") do
                i = i + 1
            end
            local word = input:sub(start, i - 1)
            table.insert(self.tokens, {type = "identifier", value = word})
        -- 数字字面量
        elseif char:match("%d") then
            local start = i
            while i <= #input and input:sub(i, i):match("%d") do
                i = i + 1
            end
            local num = input:sub(start, i - 1)
            table.insert(self.tokens, {type = "number_literal", value = tonumber(num)})
        -- 字符串字面量
        elseif char == '"' then
            i = i + 1
            local start = i
            while i <= #input and input:sub(i, i) ~= '"' do
                i = i + 1
            end
            local str = input:sub(start, i - 1)
            table.insert(self.tokens, {type = "string_literal", value = str})
            i = i + 1
        -- 运算符
        elseif char:match("[+\\-*/%=<>!&|%^]") then
            local start = i
            i = i + 1
            -- 检查双字符运算符
            if i <= #input then
                local two_char = input:sub(start, i)
                if two_char:match("^[=<>!&|%+%-*/=]+$") then
                    table.insert(self.tokens, {type = "operator", value = two_char})
                else
                    table.insert(self.tokens, {type = "operator", value = char})
                    i = i - 1
                end
            else
                table.insert(self.tokens, {type = "operator", value = char})
            end
        -- 括号和分隔符
        elseif char:match("[(){}[],.;:]") then
            table.insert(self.tokens, {type = "punctuation", value = char})
            i = i + 1
        else
            -- 未知字符
            table.insert(self.tokens, {type = "unknown", value = char})
            i = i + 1
        end
    end

    -- 添加结束标记
    table.insert(self.tokens, {type = "$", value = "$"})

    return self.tokens
end

-- 解析函数
function EnhancedParser:parse(input)
    -- 词法分析
    self:tokenize(input)
    self.current_token_index = 1
    self.errors = {}

    -- 创建根节点
    local root = ASTNode.new(ASTNode.TYPES.PROGRAM)

    -- 开始解析
    local success = self:parse_program(root)

    if not success then
        self:add_error("Failed to parse program")
    end

    return root, self.errors
end

-- 解析程序
function EnhancedParser:parse_program(parent_node)
    while self.current_token_index <= #self.tokens do
        local token = self:current_token()

        if token.type == "$" then
            break
        elseif token.type == "identifier" and token.value == "function" then
            local func_node = self:parse_function_definition()
            if func_node then
                parent_node:add_child(func_node)
            end
        elseif token.type == "identifier" and (token.value == "local" or token.value == "var" or token.value == "const") then
            local decl_node = self:parse_declaration()
            if decl_node then
                parent_node:add_child(decl_node)
            end
        elseif token.type == "identifier" and token.value == "if" then
            local if_node = self:parse_if_statement()
            if if_node then
                parent_node:add_child(if_node)
            end
        elseif token.type == "identifier" and token.value == "while" then
            local loop_node = self:parse_while_loop()
            if loop_node then
                parent_node:add_child(loop_node)
            end
        elseif token.type == "identifier" then
            -- 可能是赋值语句或函数调用
            local next_token = self:peek_token()
            if next_token and next_token.value == "=" then
                local assign_node = self:parse_assignment()
                if assign_node then
                    parent_node:add_child(assign_node)
                end
            else
                local expr_node = self:parse_expression()
                if expr_node then
                    parent_node:add_child(expr_node)
                end
            end
        else
            -- 跳过未知token
            self:advance_token()
        end
    end

    return true
end

-- 解析函数定义
function EnhancedParser:parse_function_definition()
    -- 期望 'function'
    if not self:match_token("identifier", "function") then
        return nil
    end

    -- 函数名
    local func_name_token = self:current_token()
    if func_name_token.type ~= "identifier" then
        self:add_error("Expected function name")
        return nil
    end
    self:advance_token()

    -- 参数列表
    local parameters = {}
    if not self:match_token("punctuation", "(") then
        self:add_error("Expected '(' after function name")
        return nil
    end

    while not self:match_token("punctuation", ")") do
        if self:current_token().type == "identifier" then
            local param_name = self:current_token().value
            table.insert(parameters, ASTNode.create_identifier(param_name))
            self:advance_token()
        end

        if not self:match_token("punctuation", ",") then
            break
        end
    end

    -- 函数体
    local body = ASTNode.new(ASTNode.TYPES.BLOCK)
    if not self:match_token("punctuation", "{") then
        self:add_error("Expected '{' for function body")
        return nil
    end

    while not self:match_token("punctuation", "}") do
        if self:current_token().type == "identifier" and self:current_token().value == "return" then
            local return_node = self:parse_return_statement()
            if return_node then
                body:add_child(return_node)
            end
        elseif self:current_token().type == "identifier" then
            local expr = self:parse_expression()
            if expr then
                body:add_child(expr)
            end
        else
            self:advance_token()
        end
    end

    -- 匹配 'end'
    if not self:match_token("identifier", "end") then
        self:add_error("Expected 'end' for function definition")
    end

    -- 创建函数节点
    local func_node = ASTNode.create_function_def(func_name_token.value, parameters, body)
    return func_node
end

-- 解析return语句
function EnhancedParser:parse_return_statement()
    if not self:match_token("identifier", "return") then
        return nil
    end

    local return_node = ASTNode.new(ASTNode.TYPES.CONTROL_FLOW)
    return_node:set_value("type", "return")

    -- 解析返回值表达式
    local expr = self:parse_expression()
    if expr then
        return_node:add_child(expr)
    end

    -- 期望分号或语句结束
    self:match_token("punctuation", ";")

    return return_node
end

-- 解析表达式
function EnhancedParser:parse_expression()
    local token = self:current_token()

    if token.type == "number_literal" then
        self:advance_token()
        return ASTNode.create_literal(token.value, ASTNode.DATA_TYPES.NUMBER)
    elseif token.type == "string_literal" then
        self:advance_token()
        return ASTNode.create_literal(token.value, ASTNode.DATA_TYPES.STRING)
    elseif token.type == "identifier" then
        self:advance_token()
        return ASTNode.create_identifier(token.value)
    else
        -- 未知表达式
        self:add_error("Unknown expression type: " .. token.type)
        self:advance_token()
        return nil
    end
end

-- 解析赋值语句
function EnhancedParser:parse_assignment()
    local var_token = self:current_token()
    if var_token.type ~= "identifier" then
        return nil
    end
    self:advance_token()

    if not self:match_token("operator", "=") then
        return nil
    end

    local expr = self:parse_expression()
    if not expr then
        return nil
    end

    local assign_node = ASTNode.new(ASTNode.TYPES.ASSIGNMENT)
    assign_node:set_value("target", ASTNode.create_identifier(var_token.value))
    assign_node:add_child(expr)

    self:match_token("punctuation", ";")

    return assign_node
end

-- 解析声明语句
function EnhancedParser:parse_declaration()
    local decl_type = self:current_token().value
    self:advance_token()

    local var_token = self:current_token()
    if var_token.type ~= "identifier" then
        return nil
    end
    self:advance_token()

    local expr = nil
    if self:match_token("operator", "=") then
        expr = self:parse_expression()
    end

    local decl_node = ASTNode.new(ASTNode.TYPES.DECLARATION)
    decl_node:set_value("name", var_token.value)
    decl_node:set_value("declaration_type", decl_type)

    if expr then
        decl_node:set_value("value", expr)
    end

    self:match_token("punctuation", ";")

    return decl_node
end

-- 解析if语句
function EnhancedParser:parse_if_statement()
    if not self:match_token("identifier", "if") then
        return nil
    end

    local condition = self:parse_expression()
    if not condition then
        return nil
    end

    if not self:match_token("punctuation", "{") then
        return nil
    end

    local body = ASTNode.new(ASTNode.TYPES.BLOCK)
    while not self:match_token("punctuation", "}") do
        local stmt = self:parse_statement()
        if stmt then
            body:add_child(stmt)
        end
    end

    local if_node = ASTNode.new(ASTNode.TYPES.IF_STATEMENT)
    if_node:add_child(condition)
    if_node:add_child(body)

    return if_node
end

-- 解析while循环
function EnhancedParser:parse_while_loop()
    if not self:match_token("identifier", "while") then
        return nil
    end

    local condition = self:parse_expression()
    if not condition then
        return nil
    end

    if not self:match_token("punctuation", "{") then
        return nil
    end

    local body = ASTNode.new(ASTNode.TYPES.BLOCK)
    while not self:match_token("punctuation", "}") do
        local stmt = self:parse_statement()
        if stmt then
            body:add_child(stmt)
        end
    end

    local loop_node = ASTNode.create_loop("while_loop", condition, body)
    return loop_node
end

-- 解析通用语句
function EnhancedParser:parse_statement()
    local token = self:current_token()

    if token.type == "identifier" then
        if token.value == "return" then
            return self:parse_return_statement()
        elseif token.value == "if" then
            return self:parse_if_statement()
        elseif token.value == "while" then
            return self:parse_while_loop()
        elseif token.value == "function" then
            return self:parse_function_definition()
        elseif token.value == "local" or token.value == "var" or token.value == "const" then
            return self:parse_declaration()
        else
            -- 检查是否是赋值语句
            local next_token = self:peek_token()
            if next_token and next_token.value == "=" then
                return self:parse_assignment()
            else
                return self:parse_expression()
            end
        end
    end

    return nil
end

-- 工具函数
function EnhancedParser:current_token()
    if self.current_token_index <= #self.tokens then
        return self.tokens[self.current_token_index]
    end
    return {type = "$", value = "$"}
end

function EnhancedParser:peek_token()
    if self.current_token_index + 1 <= #self.tokens then
        return self.tokens[self.current_token_index + 1]
    end
    return nil
end

function EnhancedParser:advance_token()
    self.current_token_index = self.current_token_index + 1
end

function EnhancedParser:match_token(expected_type, expected_value)
    local token = self:current_token()
    if token.type == expected_type and (not expected_value or token.value == expected_value) then
        self:advance_token()
        return true
    end
    return false
end

function EnhancedParser:add_error(message)
    table.insert(self.errors, {
        message = message,
        line = self.current_token_index,
        token = self:current_token()
    })
end

-- 代码生成器
function EnhancedParser:generate_code(ast_node)
    local code = ""

    if ast_node.type == ASTNode.TYPES.PROGRAM then
        for _, child in ipairs(ast_node.children) do
            code = code .. self:generate_code(child)
        end
    elseif ast_node.type == ASTNode.TYPES.FUNCTION_DEF then
        code = code .. "function " .. ast_node:get_value("name") .. "("

        -- 参数
        local params = {}
        for _, param in ipairs(ast_node.children) do
            if param.type == ASTNode.TYPES.IDENTIFIER then
                table.insert(params, param:get_value("name"))
            end
        end
        code = code .. table.concat(params, ", ") .. ") {\n"

        -- 函数体
        for i = #ast_node.children, 1, -1 do
            local child = ast_node.children[i]
            if child.type == ASTNode.TYPES.BLOCK then
                code = code .. self:generate_code(child)
                break
            end
        end

        code = code .. "}\n"
    elseif ast_node.type == ASTNode.TYPES.BLOCK then
        for _, child in ipairs(ast_node.children) do
            code = code .. "  " .. self:generate_code(child)
        end
    elseif ast_node.type == ASTNode.TYPES.CONTROL_FLOW and ast_node:get_value("type") == "return" then
        code = code .. "return"
        if #ast_node.children > 0 then
            local return_expr = ast_node.children[1]
            if return_expr.type == ASTNode.TYPES.IDENTIFIER then
                code = code .. " " .. return_expr:get_value("name")
            elseif return_expr.type == ASTNode.TYPES.LITERAL then
                code = code .. " " .. tostring(return_expr:get_value("value"))
            end
        end
        code = code .. ";\n"
    elseif ast_node.type == ASTNode.TYPES.IDENTIFIER then
        code = code .. ast_node:get_value("name")
    elseif ast_node.type == ASTNode.TYPES.LITERAL then
        code = code .. tostring(ast_node:get_value("value"))
    end

    return code
end

return EnhancedParser
