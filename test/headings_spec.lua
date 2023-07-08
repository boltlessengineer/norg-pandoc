local function eq(pass, expect) return assert.are.same(expect, pass) end
assert:add_formatter(
    function(val) return require("src.debug_print").pretty_table(val) end
)
if _G["vim"] then
    ---@diagnostic disable-next-line: deprecated
    table.unpack = unpack
end

local t = require "token"
-- we don't care about paragraphs in this test
t.para_seg = function() return { _t = "ParaSeg" } end
require "init"
local p = P(grammar)

describe("Detached Modifiers >", function()
    describe("Structural (headings) >", function()
        it("Level 1 heading", function()
            local text = [[
* Heading Title!
]]
            eq(
                p:match(text),
                t.pandoc {
                    t.heading(1, t.para_seg(), "Heading-Title"),
                }
            )
        end)
        it("Heading with following paragraph", function()
            local text = [[
* Heading
I'm not heading
            ]]
            eq(
                p:match(text),
                t.pandoc {
                    t.heading(1, t.para_seg(), "Heading"),
                    t.para { t.para_seg() },
                }
            )
        end)
    end)
end)
