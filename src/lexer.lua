require "token"
local utils = require "utils"

local buf
local lines
local len = 0
local tokens = {}
local prev = false
local posinfo = {
	row = 1,
	col = 1,
	indent = 0
}

local function emit(token, value)
	prev = token
	local top = tokens[#tokens]
	if top and top.posinfo.row == posinfo.row and top.posinfo.col == posinfo.col then
		assert(false, "dupe")
		return
	end
	if top and posinfo.indent ~= top.posinfo.indent then
		local itype = (posinfo.indent > top.posinfo.indent) and T_INDENT or T_DEDENT
		table.insert(tokens, {
			type = itype,
			value = math.abs(posinfo.indent - top.posinfo.indent),
			posinfo = {
				row = posinfo.row,
				col = posinfo.col,
				indent = posinfo.indent
			}
		})
	end
	table.insert(tokens, {
		type = token,
		value = value,
		posinfo = {
			row = posinfo.row,
			col = posinfo.col,
			indent = posinfo.indent
		}
	})
end

local function set_prev(v)
	tokens[#tokens].value = v
end

local function update()
end

local function advance(expect)
	if posinfo.col + 1 > len then
		return nil
	end
	posinfo.col = posinfo.col + 1
	local current = buf:sub(posinfo.col, posinfo.col)
	if expect then
		return current == expect
	end
	return true
end

local function longest_match(t, search)
	if not search then
		return false
	end
	local found = false
	for i=1,#search do
		local v = search:sub(1, i)
		if not t[v] then
			break
		end
		found = v
	end
	return found
end

local function check_operator()
	local operators = {
		-- comparisons
		["="]  = T_OPERATOR,
		["=="] = T_OPERATOR,
		[">"]  = T_OPERATOR,
		["<"]  = T_OPERATOR,
		["<="] = T_OPERATOR,
		[">="] = T_OPERATOR,
		["!="] = T_OPERATOR,

		-- arithmetic
		["*"]  = T_OPERATOR,
		["/"]  = T_OPERATOR,
		["-"]  = T_OPERATOR,
		["+"]  = T_OPERATOR,
		["*="] = T_OPERATOR,
		["/="] = T_OPERATOR,
		["-="] = T_OPERATOR,
		["+="] = T_OPERATOR,

		-- bitops
		["&"]  = T_OPERATOR,
		["^"]  = T_OPERATOR,
		["|"]  = T_OPERATOR,
		["~"]  = T_OPERATOR,
		["&="] = T_OPERATOR,
		["^="] = T_OPERATOR,
		["|="] = T_OPERATOR,
		["~="] = T_OPERATOR,

		["("]  = T_SEPARATOR,
		[")"]  = T_SEPARATOR,

		["{"]  = T_SEPARATOR,
		["}"]  = T_SEPARATOR,
		["["]  = T_SEPARATOR,
		["]"]  = T_SEPARATOR,

		-- misc
		[":"] = T_SEPARATOR,
	}
	local operators_rev = utils.invert(operators)
	local ident = buf:sub(posinfo.col):match("^([%*=%-%+%(%)%[%]%:]+)")
	local op = longest_match(operators, ident)
	if op then
		emit(operators[op], op)
		posinfo.col = posinfo.col + #op
		return true
	end
end

local function check_keyword(ident)
	local keywords = {
		["function"] = true,
		["if"] = true,
		["let"] = true
	}
	return keywords[ident] ~= nil
end

local function check_identifier()
	local pat = "^([%a%u_][%a%u%d_]+)"
	local ident = buf:sub(posinfo.col):match(pat)
	if ident then
		if check_keyword(ident) then
			emit(T_KEYWORD, ident)
		else
			emit(T_IDENTIFIER, ident)
		end
		posinfo.col = posinfo.col + #ident
		return true
	end
end

local function check_literal()
	local check = buf:sub(posinfo.col)
	local float = "^([%-%+]?[%d]*%.?[%d]+f?)"
	local lit = check:match(float)
	if lit and #lit > 0 then
		emit(T_LITERAL, lit)
		posinfo.col = posinfo.col + #lit
		return true
	end

	local int = "^([%-%+]?[%d]+)"
	lit = check:match(int)
	if lit and #lit > 0 then
		emit(T_LITERAL, lit)
		posinfo.col = posinfo.col + #lit
		return true
	end
end

local function skip_whitespace()
	while buf:sub(posinfo.col, posinfo.col) == " " do
		posinfo.col = posinfo.col + 1
	end
end

local bold = ""
local normal = ""
local red = ""
local green = ""
local yellow = ""

-- this check might not work on windows
local has_tput = io.popen("tput sgr0 2> /dev/null"):read(0) ~= nil
if has_tput then
	local function readout(s)
		return io.popen("tput " .. s):read("*a")
	end
	normal = readout("sgr0")
	bold = readout("bold")
	red = readout("setaf 1")
	green = readout("setaf 2")
	yellow = readout("setaf 3")
end

local function error_msg(msg, line, posinfo, warning)
	local tline = utils.trim(line)
	local diff = #line - #tline
	if warning then
		print(bold .. yellow .. "warning: " .. normal .. msg .. string.format(" on line %d, col %d:", posinfo.row, posinfo.col))
	else
		print(bold .. red .. "error: " .. normal .. msg .. string.format(" on line %d, col %d:", posinfo.row, posinfo.col))
	end
	local sel = posinfo.col - posinfo.indent
	print(tline:sub(1,sel-1) .. bold .. tline:sub(sel, sel) .. normal .. tline:sub(sel+1) )
	print(bold .. string.rep("~", posinfo.col-1-diff) .."^" .. normal)
end

local function lex(source, filename)
	source, lines = utils.clean(source)
	tokens = {}
	if false then
		print("INPUT:\n```")
		for i, line in ipairs(lines) do
			print(string.format("%d%s> %s", i, string.rep(" ", 3-#tostring(i)), line))
		end
		print("```")
	end

	local errors = false

	for i, line in ipairs(lines) do
		buf = line
		len = #line

		posinfo.row = i
		posinfo.indent = #line:match("^([\t]*)")
		posinfo.col = posinfo.indent+1

		while posinfo.col < len do
			skip_whitespace()
			if not (false
				or check_identifier()
				or check_literal()
				or check_operator()
			) then
				if errors then
					print()
				end
				error_msg("unknown character '" .. line:sub(posinfo.col, posinfo.col) .. "'", line, posinfo)
				posinfo.col = posinfo.col + 1
				errors = true
			end
		end
	end

	if errors then
		return {}
	end

	for k, v in ipairs(tokens) do
		print(string.rep(" ", v.posinfo.indent*2) .. token_name(v.type), v.value)
	end

	return tokens
end

return {
	lex = lex
}
