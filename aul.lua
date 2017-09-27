#!/usr/bin/luajit
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local lexer = require "lexer"

local args = {...}

if #args < 1 then
	print "hi"
	return 0
end

local function lex(buf)
	local tokens = lexer.lex(buf)
end

local check_flags = true
for _, filename in ipairs(args) do
	if check_flags and filename == "--" then
		check_flags = false
	end
	while true do
		if check_flags then
			-- TODO
			if false then
				break
			end
		end
		local f = io.open(filename)
		if f then
			local buf = f:read("*a")
			f:close()
			lex(buf, filename)
		else
			print(string.format("unable to open file %s", filename))
			return 1
		end
	break end
end
