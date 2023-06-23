require "globals"

local token = require "token"
local block = require "parser.block"
local paragraph = require "parser.paragraph"

_G.grammar = {
    "Doc",
    Doc = Ct((V "Block" + (whitespace + line_ending)) ^ 0) / token.pandoc,
    Block = block.block,
    nestable_block = block.nestable_block,
    list = block.list,
    UnorderedList = block.unordered_list,
    OrderedList = block.ordered_list,
    ParaSeg = paragraph.paragraph_segment,
    Para = paragraph.paragraph,
    Styled = paragraph.styled,
}

G = P(grammar)

function Reader(input, _reader_options)
    print "============[INPUT:]============"
    print(input)
    local match = lpeg.match(G, tostring(input))
    print "============[RESULT]============"
    return match
end
