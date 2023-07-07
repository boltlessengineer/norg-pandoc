require "globals"

local paragraph = require "parser.paragraph"
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
    return obj, function() obj:reset() end
end
function nest_lev:push(lev) table.insert(self, lev) end
function nest_lev:last() return self[#self] end
function nest_lev:pop()
    local popped = self[#self]
    self[#self] = nil
    return popped
end
function nest_lev:reset()
    while #self > 1 do
        self:pop()
    end
end

local function nest_item(ch, item, lev, sub)
    local sub_pre = empty_pat(function() lev.sub_start = true end)
    local sub_quit = empty_pat(function() lev.sub_start = false end)
    return (
        whitespace ^ 0
        * Cmt(P(ch) ^ 1 / string.len, function(_, _, count)
            if count == lev:last() and not lev.sub_start then
                return true
            elseif count > lev:last() then
                lev:push(count)
                lev.sub_start = false
                return true
            else
                if not lev.sub_start then
                    lev:pop()
                end
                lev.sub_start = false
                return false
            end
        end)
        * whitespace ^ 1
        * item
        * line_ending
        * (sub_pre * sub + sub_quit)
    )
end

local list_lev, list_reset = nest_lev:new()
local list_sub = choice {
    Ct(V "ordered_list_item" ^ 1) / token.ordered_list,
}
local _list_item = Ct(ext_cap * paragraph.paragraph_patt) / token.para
M.ordered_list_item = Ct(nest_item("~", _list_item, list_lev, list_sub))

local lower_item_start = whitespace ^ 0
    * Cmt(
        P "-" ^ 1 / string.len,
        function(_, _, count) return count <= list_lev:last() end
    )

local list_item = P(true)
    * ext_cap
    * choice {
        Ct(seq {
            P "::",
            line_ending,
            whitespace ^ 0,
            (V "Block" * line_ending ^ 0 - lower_item_start) ^ 1,
        }),
        Ct(seq {
            V "Para",
            line_ending,
            (V "UnorderedList") ^ -1,
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
M.unordered_list = Ct(seq {
    seq {
        whitespace ^ 0,
        Cmt(P "-" ^ 1 / string.len, function(_, _, count)
            if count > list_lev:last() then
                list_lev:push(count)
                return true
            end
            return false
        end),
        whitespace ^ 1,
        list_item,
    },
    seq {
        whitespace ^ 0,
        Cmt(P "-" ^ 1 / string.len, function(_, _, count)
            if count > list_lev:last() then
                list_lev:push(count)
                return true
            elseif count == list_lev:last() then
                return true
            end
            return false
        end),
        whitespace ^ 1,
        list_item,
    } ^ 0,
}) * empty_pat(function() list_lev:pop() end) / token.bullet_list

M.ordered_list = Ct(M.ordered_list_item ^ 1)
    / token.ordered_list
    * empty_pat(list_reset)

local quote_lev, quote_reset = nest_lev:new()
local quote_sub = Ct(V "quote_item" ^ 1) / token.quote
local quote_item = V "Para"
M.quote_item = nest_item(">", quote_item, quote_lev, quote_sub)
M.quote = Ct(M.quote_item ^ 1) / token.quote * empty_pat(quote_reset)

return M
