require('globals')

local token = require('token')
local block = require('parsers.block')

G = Ct((block.block + (whitespace + line_ending)) ^ 0) / token.pandoc

function Reader(input, _reader_options)
	print("============[INPUT:]============")
	print(input)
	local match = lpeg.match(G, tostring(input))
	print("============[RESULT]============")
	return match
end
