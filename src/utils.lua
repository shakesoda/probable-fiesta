
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

	while _end do
		local line = source:sub(_start, _end-1)
		line = strip_comments(line)
		if not is_empty(line) then
			table.insert(lines, line)
		end
		_start = _end + skip
		_end = source:find("\n", _start)
	end

	if #lines == 0 then
		return strip_comments(source)
	end

	return table.concat(lines, "\n"), lines
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

return {
	clean = clean,
	split = split,
	trim = trim,
	invert = invert,
	print_r = print_r
}
