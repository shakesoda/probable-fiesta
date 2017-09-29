
local expecting_block = false
local block_comment = false

local function strip_scomment(line)
	local pos = line:find("//")
	if pos then
		return line:sub(1, pos-1)
	end
	return line
end

local function strip_bcomment(line)
	local begin = false

	local pos = line:find "/%*"
	while pos do
		local pos2 = line:find "%*/"
		if pos2 then
			line = line:sub(1, pos-1) .. line:sub(pos2+2)
			pos = line:find "/%*"
			block_comment = false
		else
			block_comment = true
			line = line:sub(1, pos-1)
			break
		end
	end

	-- clean up line contents after opening a block comment
	if begin then
		line = line:sub(1, begin-1)
	end

	return line
end

local function strip_comments(line)
	line = strip_scomment(line)
	line = strip_bcomment(line)

	line = line:gsub("[%s]+$", "") -- EOL spaces
	line = line:gsub("[ ]+", " ") -- redundant spaces

	return line
end

local function is_empty(line)
	return #line == 0 or not line:find("[^%s]+") or block_comment
end

local function clean(source)
	expecting_block = false
	block_comment = false

	local lines = {}
	local _end = source:find("\n")
	local _start = 1

	-- detect crlf
	local skip = 1
	if _end and source:sub(_end+1, _end+1) == "\r" then
		skip = 2
	end

	local remap = {}
	local i = 1
	while _end do
		local line = source:sub(_start, _end-1)
		line = strip_comments(line)
		if not is_empty(line) then
			table.insert(lines, line)
			table.insert(remap, i)
		end
		i = i + 1
		_start = _end + skip
		_end = source:find("\n", _start)
	end

	if #lines == 0 then
		local body = strip_comments(source)
		return body, { body }, remap
	end

	return table.concat(lines, "\n"), lines, remap
end

function split(str, pat)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

local function trim(s)
	local from = s:match "^%s*()"
	return from > #s and "" or s:match(".*%S", from)
end

local function print_r(t, level)
	level = level or 0
	local indent = string.rep(" ", level * 2)
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indent .. tostring(k) .. " = {")
			print_r(v, level + 1)
			print(indent .. "}")
		else
			print(string.format("%s%s = %s", indent, k, v))
		end
	end
end

local function invert(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[v] = k
	end
	return ret
end


local bold = ""
local normal = ""
local red = ""
local green = ""
local yellow = ""
local dim = ""
local blue = ""

-- this check might not work on windows
local has_tput = io.popen("tput sgr0 2> /dev/null"):read(0) ~= nil
if has_tput then
	local function readout(s)
		return io.popen("tput " .. s):read("*a")
	end
	normal = readout("sgr0")
	dim = readout("dim")
	bold = readout("bold")
	red = readout("setaf 1")
	blue = readout("setaf 4")
	green = readout("setaf 2")
	yellow = readout("setaf 3")
end

local function error_msg(msg, line, posinfo, warning, len)
	len = len and len-1 or 0

	local tline = trim(line)
	local diff = #line - #tline
	if warning then
		print(bold .. yellow .. "warning: " .. normal .. msg .. string.format(" on line %d, col %d:", posinfo.row, posinfo.col))
	else
		print(bold .. red .. "error: " .. normal .. msg .. string.format(" on line %d, col %d:", posinfo.row, posinfo.col))
	end
	local sel = posinfo.col - posinfo.indent

	print(tline:sub(1,sel-1) .. bold .. tline:sub(sel, sel+len) .. normal .. tline:sub(sel+len+1) )
	print(bold .. string.rep("~", posinfo.col-1-diff) .."^" .. normal)
end

return {
	bold = bold,
	dim = dim,
	normal = normal,
	green = green,
	red = red,
	blue = blue,
	yellow = yellow,
	clean = clean,
	split = split,
	trim = trim,
	invert = invert,
	print_r = print_r,
	error_msg = error_msg
}
