local function eq(pass, expect) return assert.are.same(expect, pass) end
assert:add_formatter(
    function(val) return require("src.debug_print").pretty_table(val) end
)

local t = require "token"
-- we don't care about paragraphs in this test
t.para = function() return { _t = "para" } end
require "init"
local p = P(grammar)

describe("Nestable Detached Modifiers >", function()
    describe("Lists >", function()
        it("Unordered List", function()
            local text = [[
- Unordered list content
spanning a paragraph

but not further
]]
            eq(
                p:match(text),
                t.pandoc {
                    t.bullet_list {
                        { t.para() },
                    },
                    t.para(),
                }
            )
        end)
        it("Ordered List", function()
            local text = [[
- Ordered list content
spanning a paragraph

but not further
]]
            eq(
                p:match(text),
                t.pandoc {
                    t.bullet_list {
                        { t.para() },
                    },
                    t.para(),
                }
            )
        end)
        --[[ it("Nested Unorderd list", function()
            local text = [=[
-- level2
--- level3
---- level4
-- level2
- level1
------ level6
]=]
            eq(
                p:match(text),
                t.pandoc {
                    t.bullet_list {
                        {
                            t.para(),
                            t.bullet_list {
                                {
                                    t.para(),
                                    t.bullet_list {
                                        { t.para() },
                                    },
                                },
                            },
                        },
                        { t.para() },
                    },
                    t.bullet_list {
                        {
                            t.para(),
                            t.bullet_list {
                                { t.para() },
                            },
                        },
                    },
                }
            )
        end) ]]
    end)
    describe("Quotes >", function() end)
end)
