#!/usr/bin/luajit
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local lexer = require "lexer"
local utils = require "utils"
local trim = utils.trim
local split = utils.split
local print_r = utils.print_r

local args = {...}
local f = io.open(args[1])

if #args < 1 then
	print "hi"
	return 0
end

local function lex(buf)
	local tokens = lexer.lex(buf)
end

if f then
	local buf = f:read("*a")
	f:close()
	lex(buf, args[1])
	return 0
else
	print "unable to open file"
	return 1
end
