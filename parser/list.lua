require "globals"

local token = require "token"

local M = {}

local ext_wordchar = (wordchar + punctuation - (P ")" - P "|")) ^ 1
local ext_ch = S " x?!+-=_@#<>"
local ext_item = C(ext_ch * (whitespace * ext_wordchar) ^ 0)
local ext =
    Ct(P "(" * ext_item * (P "|" * ext_item) ^ 0 * P ")" * whitespace ^ 1)
local ext_cap = Cnil(ext ^ -1)
    / function(cap)
        if not cap then
            return
        end
        for _, e in ipairs(cap) do
            -- how this works: https://github.com/jgm/pandoc/pull/5139
            if e == "x" then
                return {
                    pandoc.Str "☒",
                    pandoc.Space(),
                }
            else
                return {
                    pandoc.Str "☐",
                    pandoc.Space(),
                }
            end
        end
    end

local nest_lev = {}
function nest_lev:new()
    self.__index = self
    local obj = setmetatable({ 0, sub_start = false }, self)
    return obj
end
function nest_lev:push(lev) table.insert(self, lev) end
function nest_lev:last() return self[#self] end
function nest_lev:pop()
    local popped = self[#self]
    self[#self] = nil
    return popped
end

local function nestable_modi(ch, nestable)
    local lev = nest_lev:new()
    local lower_item_start = whitespace ^ 0
        * Cmt(
            P(ch) ^ 1 / string.len,
            function(_, _, count) return count <= lev:last() end
        )
    local list_item = P(true)
        * ext_cap
        * choice {
            Ct(seq {
                P ":" * line_ending,
                whitespace ^ 0,
                (V "Block" - lower_item_start) ^ 1,
                empty_pat(
                    function(str, pos) pretty_print(str:sub(pos, pos + 2)) end
                ),
            }),
            Ct(seq {
                P "::" * line_ending,
                whitespace ^ 0,
                (V "Block" * line_ending ^ 0 - lower_item_start) ^ 1,
            }),
            Ct(seq {
                V "Para",
                line_ending,
                nestable ^ -1,
            }),
        }
        / function(e, tbl)
            if not tbl then
                return e
            end
            if tbl[1].t == "Para" then
                -- HACK: find more smarter way
                table.insert(tbl[1].content, 1, e[2])
                table.insert(tbl[1].content, 1, e[1])
            end
            return tbl
        end
    return Ct(seq {
        seq {
            whitespace ^ 0,
            Cmt(P(ch) ^ 1 / string.len, function(_, _, count)
                if count > lev:last() then
                    lev:push(count)
                    return true
                end
                return false
            end),
            whitespace ^ 1,
            list_item,
        },
        seq {
            whitespace ^ 0,
            Cmt(P(ch) ^ 1 / string.len, function(_, _, count)
                if count > lev:last() then
                    lev:push(count)
                    return true
                elseif count == lev:last() then
                    return true
                end
                return false
            end),
            whitespace ^ 1,
            list_item,
        } ^ 0,
    }) * empty_pat(function() lev:pop() end)
end

M.unordered_list = nestable_modi("-", V "UnorderedList") / token.bullet_list
M.ordered_list = nestable_modi("~", V "OrderedList") / token.ordered_list
M.quote = nestable_modi(">", V "quote")
    / function(tbl)
        local res = {}
        for _, t in ipairs(tbl) do
            for _, v in ipairs(t) do
                table.insert(res, v)
            end
        end
        return res
    end
    / token.quote

return M
