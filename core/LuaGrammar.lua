-- LuaGrammar.lua
-- Simplified Lua Grammar for GLR Parser

local LuaGrammar = {}

function LuaGrammar.define(glr)
    -- chunk ::= block
    glr:add_production("chunk", {"block"})

    -- block ::= {stat} [retstat]
    glr:add_production("block", {"stats", "retstat"})
    glr:add_production("block", {"stats"})
    glr:add_production("block", {"retstat"})
    glr:add_production("block", {})

    glr:add_production("stats", {"stat", "stats"})
    glr:add_production("stats", {"stat"})
    glr:add_production("stats", {";", "stats"})
    glr:add_production("stats", {";"})

    -- stat
    glr:add_production("stat", {"varlist", "=", "explist"})
    glr:add_production("stat", {"functioncall"})
    glr:add_production("stat", {"do", "block", "end"})
    glr:add_production("stat", {"while", "exp", "do", "block", "end"})
    glr:add_production("stat", {"repeat", "block", "until", "exp"})
    glr:add_production("stat", {"if", "exp", "then", "block", "end"})
    glr:add_production("stat", {"if", "exp", "then", "block", "else", "block", "end"})
    glr:add_production("stat", {"for", "id", "=", "exp", ",", "exp", "do", "block", "end"})
    glr:add_production("stat", {"for", "id", "=", "exp", ",", "exp", ",", "exp", "do", "block", "end"})
    glr:add_production("stat", {"for", "namelist", "in", "explist", "do", "block", "end"})
    glr:add_production("stat", {"local", "namelist", "=", "explist"})
    glr:add_production("stat", {"global", "namelist", "=", "explist"})
    glr:add_production("stat", {"function", "funcname", "funcbody"})
    glr:add_production("stat", {"local", "function", "id", "funcbody"})
    glr:add_production("stat", {"global", "function", "id", "funcbody"})

    -- retstat
    glr:add_production("retstat", {"return", "explist"})
    glr:add_production("retstat", {"return"})

    -- funcname (simplified)
    glr:add_production("funcname", {"id"})
    glr:add_production("funcname", {"funcname", ".", "id"})
    glr:add_production("funcname", {"funcname", ":", "id"})

    -- varlist
    glr:add_production("varlist", {"var"})
    glr:add_production("varlist", {"varlist", ",", "var"})

    -- var
    glr:add_production("var", {"id"})
    glr:add_production("var", {"prefixexp", "[", "exp", "]"})
    glr:add_production("var", {"prefixexp", ".", "id"})

    -- namelist
    glr:add_production("namelist", {"id"})
    glr:add_production("namelist", {"namelist", ",", "id"})

    -- explist
    glr:add_production("explist", {"exp"})
    glr:add_production("explist", {"explist", ",", "exp"})

    -- exp
    glr:add_production("exp", {"nil"})
    glr:add_production("exp", {"false"})
    glr:add_production("exp", {"true"})
    glr:add_production("exp", {"num"})
    glr:add_production("exp", {"string"})
    glr:add_production("exp", {"..."})
    glr:add_production("exp", {"functiondef"})
    glr:add_production("exp", {"prefixexp"})
    glr:add_production("exp", {"tableconstructor"})
    glr:add_production("exp", {"exp", "+", "exp"})
    glr:add_production("exp", {"exp", "-", "exp"})
    glr:add_production("exp", {"exp", "*", "exp"})
    glr:add_production("exp", {"exp", "/", "exp"})
    glr:add_production("exp", {"exp", "^", "exp"})
    glr:add_production("exp", {"exp", "%", "exp"})
    glr:add_production("exp", {"exp", "..", "exp"})
    glr:add_production("exp", {"exp", "<", "exp"})
    glr:add_production("exp", {"exp", "<=", "exp"})
    glr:add_production("exp", {"exp", ">", "exp"})
    glr:add_production("exp", {"exp", ">=", "exp"})
    glr:add_production("exp", {"exp", "==", "exp"})
    glr:add_production("exp", {"exp", "~=", "exp"})
    glr:add_production("exp", {"exp", "and", "exp"})
    glr:add_production("exp", {"exp", "or", "exp"})
    glr:add_production("exp", {"-", "exp"})
    glr:add_production("exp", {"not", "exp"})
    glr:add_production("exp", {"#", "exp"})

    -- prefixexp
    glr:add_production("prefixexp", {"var"})
    glr:add_production("prefixexp", {"functioncall"})
    glr:add_production("prefixexp", {"(", "exp", ")"})

    -- functioncall
    glr:add_production("functioncall", {"prefixexp", "args"})
    glr:add_production("functioncall", {"prefixexp", ":", "id", "args"})

    -- args
    glr:add_production("args", {"(", ")"})
    glr:add_production("args", {"(", "explist", ")"})
    glr:add_production("args", {"tableconstructor"})
    glr:add_production("args", {"string"})

    -- functiondef
    glr:add_production("functiondef", {"function", "funcbody"})

    -- funcbody
    glr:add_production("funcbody", {"(", ")", "block", "end"})
    glr:add_production("funcbody", {"(", "parlist", ")", "block", "end"})

    -- parlist
    glr:add_production("parlist", {"namelist"})
    glr:add_production("parlist", {"namelist", ",", "..."})
    glr:add_production("parlist", {"..."})

    -- tableconstructor
    glr:add_production("tableconstructor", {"{", "fieldlist", "}"})
    glr:add_production("tableconstructor", {"{", "}"})

    -- fieldlist
    glr:add_production("fieldlist", {"field"})
    glr:add_production("fieldlist", {"fieldlist", ",", "field"})
    glr:add_production("fieldlist", {"fieldlist", ";", "field"})

    -- field
    glr:add_production("field", {"[", "exp", "]", "=", "exp"})
    glr:add_production("field", {"id", "=", "exp"})
    glr:add_production("field", {"exp"})
end

return LuaGrammar
