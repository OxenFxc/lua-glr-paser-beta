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
    glr:add_production("stat", {"do", "block", "end"})
    glr:add_production("stat", {"while", "exp", "do", "block", "end"})
    glr:add_production("stat", {"if", "exp", "then", "block", "end"})
    glr:add_production("stat", {"if", "exp", "then", "block", "else", "block", "end"})
    glr:add_production("stat", {"local", "namelist", "=", "explist"})
    glr:add_production("stat", {"global", "namelist", "=", "explist"})
    glr:add_production("stat", {"function", "id", "funcbody"})
    glr:add_production("stat", {"local", "function", "id", "funcbody"})
    glr:add_production("stat", {"global", "function", "id", "funcbody"})
    glr:add_production("stat", {"id", "(", "explist", ")"})
    glr:add_production("stat", {"id", "(", ")"})

    -- retstat
    glr:add_production("retstat", {"return", "explist"})
    glr:add_production("retstat", {"return"})

    -- varlist
    glr:add_production("varlist", {"id"})
    glr:add_production("varlist", {"varlist", ",", "id"})

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
    glr:add_production("exp", {"id"})
    glr:add_production("exp", {"exp", "+", "exp"})
    glr:add_production("exp", {"exp", "-", "exp"})
    glr:add_production("exp", {"exp", "*", "exp"})
    glr:add_production("exp", {"exp", "/", "exp"})
    glr:add_production("exp", {"exp", "==", "exp"})
    glr:add_production("exp", {"(", "exp", ")"})
    glr:add_production("exp", {"id", "(", "explist", ")"})
    glr:add_production("exp", {"id", "(", ")"})

    -- funcbody
    glr:add_production("funcbody", {"(", ")", "block", "end"})
    glr:add_production("funcbody", {"(", "namelist", ")", "block", "end"})
end

return LuaGrammar
