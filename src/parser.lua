require "token"
local utils = require "utils"
local error_msg = utils.error_msg

local expect = { T_KEYWORD }

local expectations = {
	INVALID_TOKEN = function(prev, token)
		return {
			msg = "unhandled token " .. token_name(token.type),
			warning = false
		}
	end
}

expectations[T_INDENT] = function(prev, token)
	expect = { T_IDENTIFIER, T_KEYWORD }
end

expectations[T_SEPARATOR] = function(prev, token)
	expect = { T_IDENTIFIER, T_LITERAL, T_SEPARATOR }
	if token.value == ":" then
		table.insert(expect, T_INDENT)
	end
end

expectations[T_IDENTIFIER] = function(prev, token)
	if prev.type == T_SEPARATOR and prev.value == ":" then
		expect = { T_INDENT }
		return
	end
	expect = { T_OPERATOR, T_SEPARATOR }
end

expectations[T_KEYWORD] = function(prev, token)
	expect = { T_IDENTIFIER }
end

expectations[T_OPERATOR] = function(prev, token)
	expect = { T_LITERAL, T_IDENTIFIER }
end

expectations[T_LITERAL] = function(prev, token)
	expect = { T_IDENTIFIER, T_KEYWORD, T_SEPARATOR }
end

local function parse(tokens)
	local prev = false
	for _, v in ipairs(tokens) do
		local met = false
		for _, ttype in ipairs(expect) do
			-- print("expect", token_name(ttype))
			if ttype == v.type then
				-- print("hit")
				met = ttype
				break
			end
		end
		if not met then
			error_msg("unexpected " .. token_name(v.type), v.raw, v.posinfo, false, #tostring(v.value))
			for _, v in ipairs(expect) do
				print("expected: " .. token_name(v) .. " after " .. prev.value .. " (" .. token_name(prev.type) .. ")")
			end
			break
		end
		local fn = expectations[met] or expectations.INVALID_TOKEN
		local err = fn(prev, v)
		if err then
			error_msg(err.msg, v.raw, v.posinfo, err.warning, #tostring(v.value))
			if not err.warning then
				break
			end
		end
		print(token_name(v.type), met)
		-- if v.type == T_SEPARATOR and v.value == "(" then
		-- 	if prev and prev.type == T_IDENTIFIER then
		-- 		print("function call", prev.value .. "()")
		-- 	end
		-- end
		prev = v
	end
end

return {
	parse = parse
}
