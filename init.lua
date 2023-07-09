require "globals"

local token = require "token"
local block = require "parser.block"
local paragraph = require "parser.paragraph"
local list = require "parser.list"

_G.grammar = {
    "Doc",
    Doc = Ct(choice {
        V "Block",
        (whitespace + line_ending),
    } ^ 0) / token.pandoc,
    Block = choice {
        V "standard_ranged_tag",
        V "verbatim_ranged_tag",
        V "detached_modifier",
        V "delimiting_mod",
        V "Para" * line_ending,
    },
    Heading = block.heading,
    list = V "UnorderedList" + V "OrderedList",
    quote = list.quote,
    UnorderedList = list.unordered_list,
    OrderedList = list.ordered_list,
    detached_modifier = choice {
        -- structural
        V "Heading",
        -- nestable
        V "list",
        V "quote",
        -- range-able
        V "definition",
        V "footnote",
        V "table_cells",
    },
    ParaSeg = paragraph.inline_segment,
    Para = paragraph.inline / token.para,
    verbatim_ranged_tag = block.verbatim_ranged_tag,
    standard_ranged_tag = block.standard_ranged_tag,
    definition = block.definition_list,
    footnote = block.footnote,
    table_cells = block.table_cells,
    delimiting_mod = choice {
        block.week_delimiting_mod,
        block.strong_delimiting_mod,
        block.horizontal_rule,
    },

    _paragraph = paragraph.inline,
}

-- _G.grammar = require("src.pegdebug").trace(grammar)
G = P(grammar)

function Reader(input, _reader_options)
    print "============[INPUT:]============"
    print(input)
    print "============[PARSE:]============"
    local match = lpeg.match(G, tostring(input))
    -- local match = pandoc.Pandoc {
    --     pandoc.Para {
    --         pandoc.RawInline("pdf", "HEADING"),
    --         pandoc.RawInline("html", "<h1>heading</h1>"),
    --     },
    -- }
    print "============[RESULT]============"
    return match
end
