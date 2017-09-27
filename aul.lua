#!/usr/bin/luajit
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local lexer = require "lexer"
local parser = require "parser"

local args = {...}

if #args < 1 then
	print "hi"
	return 0
end

local check_flags = true

local dump_tokens = false

local files = {}

for _, filename in ipairs(args) do
	if check_flags and filename == "--" then
		check_flags = false
	end
	while true do
		if check_flags then
			if filename == "--dump" then
				dump_tokens = true
				break
			end
		end

		-- don't attempt to process the same file twice
		if files[filename] then
			break
		end

		local f = io.open(filename)
		if f then
			files[filename] = true

			local buf = f:read("*a")
			f:close()

			local tokens = lexer.lex(buf)
			parser.parse(tokens)

			if dump_tokens then
				for k, v in ipairs(tokens) do
					print(string.rep(" ", v.posinfo.indent*2) .. token_name(v.type), v.value)
				end
			end
		else
			print(string.format("unable to open file %s", filename))
			return 1
		end
	break end
end
