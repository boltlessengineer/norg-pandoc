require "globals"

local token = require "token"
local block = require "parser.block"
local paragraph = require "parser.paragraph"

_G.grammar = {
    "Doc",
    Doc = Ct(choice {
        (whitespace + line_ending),
        V "Block",
    } ^ 0) / token.pandoc,
    Block = block.block,
    Heading = block.heading,
    list = block.list,
    quote = block.quote,
    UnorderedList = block.unordered_list,
    OrderedList = block.ordered_list,
    detached_modifier = block.detached_modifier,
    ParaSeg = paragraph.paragraph_segment,
    Para = paragraph.paragraph,
    Styled = paragraph.styled,
    Link = paragraph.link,
    verbatim_ranged_tag = block.verbatim_ranged_tag,
    definition = block.definition_list,
    footnote = block.footnote,
}

-- _G.grammar = require("src.pegdebug").trace(grammar)
G = P(grammar)

function Reader(input, _reader_options)
    print "============[INPUT:]============"
    print(input)
    print "============[PARSE:]============"
    local match = lpeg.match(G, tostring(input))
    print "============[RESULT]============"
    return match
end
