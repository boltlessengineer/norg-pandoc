local function eq(pass, expect) return assert.are.same(expect, pass) end
assert:add_formatter(
    function(val) return require("src.debug_print").pretty_table(val) end
)

local t = require "token"
require "init"
local p = P(grammar)

describe("Precedences >", function()
    describe("break Attached Modifier on >", function()
        it("Heading", function()
            local text = [[
*bold
* heading
text*
            ]]
            eq(
                p:match(text),
                t.pandoc {
                    t.para { t.para_seg { t.punc "*", t.str "bold" } },
                    t.heading(1, t.para_seg { t.str "heading" }, "heading"),
                    t.para { t.para_seg { t.str "text", t.punc "*" } },
                }
            )
        end)
        it("Nestable Detached Modifiers", function()
            local text = [[
- item1 *bold
- item2
text*
            ]]
            eq(
                p:match(text),
                t.pandoc {
                    t.bullet_list {
                        {
                            t.para {
                                t.para_seg {
                                    t.str "item1",
                                    t.space(),
                                    t.punc "*",
                                    t.str "bold",
                                },
                            },
                        },
                        {
                            t.para {
                                t.para_seg { t.str "item2" },
                                t.soft_break(),
                                t.para_seg { t.str "text", t.punc "*" },
                            },
                        },
                    },
                }
            )
        end)
    end)
end)
