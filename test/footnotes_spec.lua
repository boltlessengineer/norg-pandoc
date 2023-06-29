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

describe("Footnotes >", function()
    it("Footnote", function()
        local text = [[
some text {^ my footnote}

^ my footnote
content of footnote
]]
        eq(true, true)
    end)
    it("Footnote with description", function()
        local text = [[
some text {^ my footnote}[foot]

^ my footnote
content of footnote
]]
        eq(true, true)
    end)
end)
