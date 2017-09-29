require "token"
local utils = require "utils"
local error_msg = utils.error_msg

local dump_vars = false

local expect = { T_KEYWORD }
local globals
local paren_depth = 0
local current_node

local expectations = {
	INVALID_TOKEN = function(prev, token, next)
		return {
			msg = "unhandled token " .. token_name(token.type),
			warning = false
		}
	end
}

local function next_statement(reason)
	assert(reason)
	if paren_depth > 0 then
		local top = current_node[#current_node]
		top = top.tokens[#top.tokens]
		error_msg("expected closing ')' before end of statement", top.raw, top.posinfo)
	end
	table.insert(current_node, { tokens = {}, cause = reason })
end

expectations[T_INDENT] = function(prev, token, next)
	next_statement(token.type)
	expect = { T_IDENTIFIER, T_KEYWORD }
end

expectations[T_DEDENT] = function(prev, token, next)
	next_statement(token.type)
	expect = { T_IDENTIFIER, T_KEYWORD }
end

expectations[T_SEPARATOR] = function(prev, token, next, future)
	expect = { T_LITERAL, T_SEPARATOR, T_KEYWORD }
	if token.value == ":" then
		table.insert(expect, T_INDENT)
		table.insert(expect, T_IDENTIFIER)
	end
	if token.value == "," then
		table.insert(expect, T_IDENTIFIER)
	end
	if token.value == "(" then
		table.insert(expect, T_IDENTIFIER)
	end
	if token.value == ")" or token.value == "]" then
		table.insert(expect, T_DEDENT)
		if paren_depth == 0 and next and next.type ~= T_IDENTIFIER and future and future.type == T_SEPARATOR and future.value == "(" then
			table.insert(expect, T_IDENTIFIER)
		end
	end
end

expectations[T_IDENTIFIER] = function(prev, token, next, future)
	if prev.type == T_SEPARATOR and prev.value == ":" then
		token.type = PT_TYPE
		expect = { T_INDENT }
		return
	end
	expect = { T_OPERATOR, T_SEPARATOR, T_KEYWORD }
	if prev.type == T_LITERAL then
		next_statement(token.type)
		return
	end
	if prev.type == T_DEDENT
		or prev.type == T_IDENTIFIER
		or prev.type == T_SEPARATOR then
		table.insert(expect, T_KEYWORD)
	end
	if prev.type == token.type
		and next and next.type == T_SEPARATOR
		and next.value == "(" then
		next_statement(token.type)
		-- print(token.value, token_name(prev.type), token_name(token.type), token_name(next.type))
	end
	if future and next
		and next.type == T_IDENTIFIER
		and future.type == T_SEPARATOR
		and future.value == "(" then
		table.insert(expect, T_IDENTIFIER)
		return
	end
	if paren_depth == 0 then
		-- table.insert(expect, T_IDENTIFIER)
	end
end

expectations[T_KEYWORD] = function(prev, token, next)
	next_statement(token.type)
	expect = { T_IDENTIFIER }
end

expectations[T_OPERATOR] = function(prev, token, next)
	expect = { T_LITERAL, T_IDENTIFIER }
end

expectations[T_LITERAL] = function(prev, token, next)
	expect = { T_IDENTIFIER, T_KEYWORD, T_SEPARATOR, T_OPERATOR, T_DEDENT }
end

local function prepare_tree(tokens)
	local prev = { value = "<beginning of file>", type = T_INVALID }
	for ti, v in ipairs(tokens) do
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
		local err = fn(prev, v, tokens[ti+1], tokens[ti+2])
		if err then
			error_msg(err.msg, v.raw, v.posinfo, err.warning, #tostring(v.value))
			if not err.warning then
				break
			end
		end
		if v.type == T_SEPARATOR then
			if v.value == "(" then
				paren_depth = paren_depth + 1
			elseif v.value == ")" then
				paren_depth = paren_depth - 1
				if paren_depth < 0 then
					error_msg("')' does not match a corresponding '('", v.raw, v.posinfo, false)
					break
				end
			end
		end
		if v.type == T_INDENT then
			for i = 1, v.value do
				current_node = {
					parent = current_node
				}
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
end

local function dump_ast(t, level)
	level = level or -1 -- there's no tokens on level 0
	local pad = string.rep(" ", level * 4)

	if dump_vars and t.locals then
		for k, v in ipairs(t.locals) do
			print(utils.normal..pad .. string.format(
				utils.dim.."LOCAL %s%s = %s"..utils.normal,
				(v.data_type and (v.data_type .. " ") or ""),
				v.value,
				v.data_value or 0
			))
		end
	end

	for k, v in pairs(t) do
		if k == "tokens" and #v > 0 then
			local str = ""
			local ttype = {
				[T_OPERATOR] = "",
				[T_SEPARATOR] = utils.dim .."",
				[T_KEYWORD] = utils.blue .. "",
				[T_LITERAL] = utils.red .. "#",
				[T_IDENTIFIER] = utils.green .. "decl " .. utils.bold .. "$",
				[PT_FUNCTION] = utils.yellow .. utils.bold .. "def ",
				[PT_TYPE] = utils.blue .. "ret ",
				[PT_CALL] = utils.yellow .. "call @",
				[PT_VARIABLE] = utils.green .. "$",
				[PT_COND] = utils.red .. ""
			}
			-- print(pad .. utils.dim .. utils.green .. "; " .. utils.trim(v[1].raw) .. utils.normal)
			for i, token in ipairs(v) do
				local pre = ttype[token.type] or "?"
				str = str .. pre .. token.value .. utils.normal
				if i < #v then
					str = str .. " "
				end
				if token.type == PT_CALL then
					for j, arg in ipairs(token.args) do
						str = str .. (arg.value or "unknown") .. "(" .. (arg.data_type or "unknown") .. ")"
						if j < #token.args then
							str = str .. ", "
						end
					end
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

local function scan_r(t, cb)
	if t.tokens then
		cb(t.tokens, t)
	end
	for k, v in ipairs(t) do
		if type(v) == "table" and k ~= "parent" then
			scan_r(v, cb)
		end
	end
end

local function find_lonely_identifiers(tokens)
	if #tokens == 1 then
		local token = tokens[1]
		if token.type == T_IDENTIFIER then
			error_msg("ignoring lone identifier", token.raw, token.posinfo, true, #token.value)
			table.remove(tokens)
		end
	end
end

local function find_functions(tokens)
	local functionify_next = false
	for i=#tokens,2,-1 do
		local token = tokens[i]
		local nextt = tokens[i-1]
		if token.type == T_IDENTIFIER and nextt.type == T_KEYWORD then
			if nextt.value == "function" then
				nextt.type = PT_FUNCTION
				nextt.value = token.value
				table.remove(tokens, i)
			end
		end
	end
end

local function find_calls(tokens)
	if #tokens < 3 then
		return
	end
	for i=1,#tokens do
		local call = tokens[i]
		if call.type == T_IDENTIFIER then
			local open = tokens[i+1]
			if open and open.type == T_SEPARATOR and open.value == "(" then
				call.type = PT_CALL
				call.args = {}
				local tree = call.args
				for j=i+2,#tokens do
					local token = tokens[j]
					if token.type == T_SEPARATOR then
						if token.value == "(" then
							local parent = tree
							tree = {}
							-- tree.type = PT_FUNCTION
							tree.parent = parent
						elseif token.value == ")" then
							if tree.parent then
								table.insert(tree.parent, tree)
								tree = tree.parent
							else
								break
							end
						end
					else
						table.insert(tree, token)
					end
				end
				-- print("call " .. call.value .. " takes " .. #tree .. " args")
				for j, v in ipairs(tree) do
					if v.type == PT_TYPE then
						print(j, v.data_type, v.value)
					end
				end
				break
			end
		end
	end
end

local function find_variables(tokens, t)
	local set_after = false
	local set_global = false
	for i, token in ipairs(tokens) do
		if token.type == T_KEYWORD and token.value == "global" then
			set_global = true
		end
		if token.type == T_OPERATOR then
			set_after = true
		end
		if token.type == T_KEYWORD and (token.value == "if") then
			set_after = true
			token.type = PT_COND
		end
		if set_after and token.type == T_IDENTIFIER then
			token.type = PT_VARIABLE
		end
		if token.type == T_IDENTIFIER then
			if set_global then
				table.insert(globals, token)
			else
				t.locals = t.locals or {}
				table.insert(t.locals, token)
			end
		end
	end
end

local function find_double_identifiers(tokens)
	if #tokens < 2 then
		if tokens[1] then
			error_msg("statement does nothing", tokens[1].raw, tokens[1].posinfo, true)
		end
	end
	for i=2,#tokens do
		-- if 
	end
end

local function parse(tokens)
	current_node = {}
	globals = {}

	-- validate and build tree
	prepare_tree(tokens)
	scan_r(current_node, find_lonely_identifiers)
	scan_r(current_node, find_double_identifiers)
	scan_r(current_node, find_functions)
	scan_r(current_node, find_calls)
	scan_r(current_node, find_variables)

	-- print(utils.dim .. utils.green .. "; = original source")
	-- print(utils.dim .. utils.green .. "; # = literal, $ = identifier, % = keyword" .. utils.normal)

	if dump_vars then
		for i, v in ipairs(globals) do
			print(utils.normal .. string.format(
				utils.red..utils.bold.."GLOBAL %s%s = %s"..utils.normal,
				(v.data_type and (v.data_type .. " ") or ""),
				v.value,
				v.data_value or 0
			))
		end
	end

	dump_ast(current_node)
end

return {
	parse = parse
}
