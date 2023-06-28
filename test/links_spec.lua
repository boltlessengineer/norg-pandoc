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
local p = P(grammar)

describe("Links >", function()
    -- TODO: test multi line definitions
    it("Link to definitions", function()
        local text = [[
see {$ some word}.
]]
        eq(
            p:match(text),
            t.pandoc {
                t.para {
                    t.para_seg {
                        t.str "see",
                        t.space(),
                        t.link("some word", "d-some-word"),
                        t.punc ".",
                    },
                },
            }
        )
    end)
    it("Link to footnotes", function()
        local text = [[
see {^ some word}.
]]
        eq(
            p:match(text),
            t.pandoc {
                t.para {
                    t.para_seg {
                        t.str "see",
                        t.space(),
                        t.link("some word", "f-some-word"),
                        t.punc ".",
                    },
                },
            }
        )
    end)
end)
