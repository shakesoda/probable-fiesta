require "token"
local utils = require "utils"
local error_msg = utils.error_msg

local expect = { T_KEYWORD }
local current_node

local expectations = {
	INVALID_TOKEN = function(prev, token)
		return {
			msg = "unhandled token " .. token_name(token.type),
			warning = false
		}
	end
}

local function next_statement(reason)
	assert(reason)
	table.insert(current_node, { tokens = {}, cause = reason })
end

expectations[T_INDENT] = function(prev, token)
	next_statement(token.type)
	expect = { T_IDENTIFIER, T_KEYWORD }
end

expectations[T_DEDENT] = function(prev, token)
	next_statement(token.type)
	expect = { T_IDENTIFIER, T_KEYWORD }
end

expectations[T_SEPARATOR] = function(prev, token)
	expect = { T_IDENTIFIER, T_LITERAL, T_SEPARATOR, T_KEYWORD }
	if token.value == ":" then
		table.insert(expect, T_INDENT)
	end
	if token.value == ")" or token.value == "]" then
		table.insert(expect, T_DEDENT)
	end
end

expectations[T_IDENTIFIER] = function(prev, token)
	if prev.type == T_SEPARATOR and prev.value == ":" then
		expect = { T_INDENT }
		return
	end
	expect = { T_OPERATOR, T_SEPARATOR, T_KEYWORD }
	if prev.type == T_LITERAL
		or prev.type == T_IDENTIFIER
		or prev.type == T_DEDENT
		or prev.type == T_SEPARATOR then
		table.insert(expect, T_KEYWORD)
	end
end

expectations[T_KEYWORD] = function(prev, token)
	next_statement(token.type)
	expect = { T_IDENTIFIER }
end

expectations[T_OPERATOR] = function(prev, token)
	expect = { T_LITERAL, T_IDENTIFIER }
end

expectations[T_LITERAL] = function(prev, token)
	expect = { T_IDENTIFIER, T_KEYWORD, T_SEPARATOR, T_OPERATOR, T_DEDENT }
end

local function parse(tokens)
	current_node = {}
	local prev = { value = "<beginning of file>", type = T_INVALID }

	for _, v in ipairs(tokens) do
		local met = false
		for _, ttype in ipairs(expect) do
			if ttype == v.type then
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

		if v.type == T_INDENT then
			for i = 1, v.value do
				local parent = current_node
				current_node = {}
				current_node.parent = parent
			end
		elseif v.type == T_DEDENT then
			for i = 1, v.value do
				table.insert(current_node.parent, current_node)
				current_node = current_node.parent
			end
		else
			local top = current_node[#current_node]
			if not top then
				top = {}
				table.insert(current_node, top)
			end
			top.tokens = top.tokens or {}
			table.insert(top.tokens, v)
		end
		prev = v
	end

	local function dump_ast(t, level)
		level = level or -1 -- there's no tokens on level 0
		local pad = string.rep(" ", level * 4)
		for k, v in pairs(t) do
			if k == "tokens" then
				local str = ""
				local ttype = {
					[T_OPERATOR] = "",
					[T_SEPARATOR] = "",
					[T_KEYWORD] = "%",
					[T_LITERAL] = "#",
					[T_IDENTIFIER] = "$"
				}
				print(pad .. "; " .. utils.trim(v[1].raw))
				for i, token in ipairs(v) do
					local pre = ttype[token.type] or "?"
					str = str .. pre .. token.value
					if i < #v then
						str = str .. " "
					end
				end
				str = str .. ""
				print(pad .. str)
			elseif type(v) == "table" and k ~= "parent"
				and v.cause ~= T_INDENT and v.cause ~= T_DEDENT
			then
				dump_ast(v, level + 1)
				local comma = tonumber(k) and tonumber(k) < #t or false
			end
		end
	end

	print("; = original source")
	print("; # = literal, $ = identifier, % = keyword")
	dump_ast(current_node)
end

return {
	parse = parse
}
