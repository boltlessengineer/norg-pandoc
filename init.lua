require "globals"

local token = require "token"
local block = require "parser.block"
local paragraph = require "parser.paragraph"
local list = require "parser.list"

_G.grammar = {
    "Doc",
    Doc = Ct(choice {
        (whitespace + line_ending),
        V "Block",
    } ^ 0) / token.pandoc,
    Block = block.block,
    Heading = block.heading,
    list = V "UnorderedList" + V "OrderedList",
    quote_item = list.quote_item,
    quote = list.quote,
    UnorderedList = list.unordered_list,
    OrderedList = list.ordered_list,
    bullet_list_item = list.bullet_list_item,
    ordered_list_item = list.ordered_list_item,
    detached_modifier = block.detached_modifier,
    ParaSeg = paragraph.paragraph_segment,
    Para = paragraph.paragraph,
    Styled = paragraph.styled,
    Link = paragraph.link + paragraph.anchor,
    verbatim_ranged_tag = block.verbatim_ranged_tag,
    definition = block.definition_list,
    footnote = block.footnote,
    delimiting_mod = choice {
        block.week_delimiting_mod,
        block.strong_delimiting_mod,
        block.horizontal_rule,
    },
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
