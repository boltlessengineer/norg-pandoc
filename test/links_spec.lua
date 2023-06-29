local function eq(pass, expect) return assert.are.same(expect, pass) end
assert:add_formatter(
    function(val) return require("src.debug_print").pretty_table(val) end
)
if _G["vim"] then
    ---@diagnostic disable-next-line: deprecated
    table.unpack = unpack
end

local t = require "token"
require "init"
grammar[1] = "ParaSeg"
local p = P(grammar)

describe("Links >", function()
    it("URL type, but whitespace and newline inside", function()
        local text = [[
{https://go
    ogle.com}
]]
        -- TODO: make test
        eq(
            p:match(text),
            t.para_seg {
                t.link("https://google.com", "https://google.com"),
            }
        )
    end)
    it("Link to headings", function()
        local text = [[
{* heading 1}
]]
        eq(
            p:match(text),
            t.para_seg {
                t.link(
                    { t.str "heading", t.space(), t.str "1" },
                    "#h-heading-1"
                ),
            }
        )
    end)
    it("Link to definitions", function()
        local text = [[
see {$ some word}.
]]
        eq(
            p:match(text),
            t.para_seg {
                t.str "see",
                t.space(),
                t.link(
                    { t.str "some", t.space(), t.str "word" },
                    "#d-some-word"
                ),
                t.punc ".",
            }
        )
    end)
    -- FIX: this should be pandoc.Note, not pandoc.Link
    it("Link to footnotes", function()
        local text = "see {^ some word}."
        eq(
            p:match(text),
            t.para_seg {
                t.str "see",
                t.space(),
                t.footnote_link(
                    { t.str "some", t.space(), t.str "word" },
                    "#f-some-word"
                ),
                t.punc ".",
            }
        )
    end)
    -- TODO: these two cases should rather checked from Pandoc to check
    -- footnote doesn't create <sup> wrapper inside superscript/subscript
    it("Footnote link inside superscript", function()
        local text = "^see {^ my footnote}^"
        eq(
            p:match(text),
            t.para_seg {
                t.superscript {
                    t.str "see",
                    t.space(),
                    t.footnote_link(
                        { t.str "my", t.space(), t.str "footnote" },
                        "#f-my-footnote"
                    ),
                },
            }
        )
    end)
    it("Footnote link inside subscript", function()
        local text = ",see {^ my footnote},"
        eq(
            p:match(text),
            t.para_seg {
                t.subscript {
                    t.str "see",
                    t.space(),
                    t.footnote_link(
                        { t.str "my", t.space(), t.str "footnote" },
                        "#f-my-footnote"
                    ),
                },
            }
        )
    end)
    -- FIX: this fails
    it("Link with multi line destination", function()
        local text = [[
{* long  
   heading}
]]
        eq(
            p:match(text),
            t.para_seg {
                t.link({
                    t.str "long",
                    t.soft_break(),
                    t.str "heading",
                }, "#h-long-heading"),
            }
        )
    end)
    it("Link to Custom Detached Modifier (file)", function()
        local text = "{/ path/to/file.txt}"
        eq(
            p:match(text),
            t.para_seg {
                t.link("path/to/file.txt", "path/to/file.txt"),
            }
        )
    end)
    it("Link to Custom Detached Modifier (file) with whitespaces", function()
        local text = [[
{/ pa
th/to
/file.txt}
]]
        eq(
            p:match(text),
            t.para_seg {
                t.link("path/to/file.txt", "path/to/file.txt"),
            }
        )
    end)
    describe("Link with File Location >", function()
        it("Basic File Location", function()
            local text = [[
{:path/to/file:}
]]
            -- eq(
            --     p:match(text),
            --     t.para_seg {
            --         t.link("path/to/file", "path/to/file"),
            --     }
            -- )
        end)
    end)
end)
