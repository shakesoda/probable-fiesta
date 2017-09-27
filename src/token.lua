local utils = require "utils"

local i = 0
local function id()
	i = i + 1
	return i
end

local tokens = {
	-- lexer tokens
	T_IDENTIFIER = id(),
	T_KEYWORD = id(),
	T_LITERAL = id(),
	T_SEPARATOR = id(),
	T_OPERATOR = id(),
	T_INDENT = id(),
	T_DEDENT = id()
}

local names = utils.invert(tokens)

function token_name(v)
	return names[v]
end

for k, v in pairs(tokens) do
	_G[k] = v
end
