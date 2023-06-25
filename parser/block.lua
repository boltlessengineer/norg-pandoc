require "globals"

local paragraph = require "parser.paragraph"
local token = require "token"

local M = {}

local function list_item(lev, start)
    local sp = P(start)
    local subitem = function(s)
        if lev < 6 then
            return list_item(lev + 1, s)
        else
            return (1 - 1) -- fails
        end
    end
    -- stylua: ignore
    local parser = whitespace ^ 0
        * sp ^ lev
        * #-sp
        * whitespace
        * Ct(V "ParaSeg")
        * line_ending
        * (Ct(subitem "-" ^ 1) / token.bullet_list
            + Ct(subitem "~" ^ 1) / token.ordered_list
            + Cc(nil))
        / function(ils, sublist)
            return { token._plain(ils), sublist }
        end
    return parser
end

M.unordered_list = Ct(list_item(1, "-") ^ 1) / token.bullet_list
M.ordered_list = Ct(list_item(1, "~") ^ 1) / token.ordered_list
M.list = V "UnorderedList" + V "OrderedList"

M.nestable_block = choice {
    V "list",
    V "Para",
}

local horizontal_rule = P "_" ^ 3 / token.horizontal_rule

M.block = V "Heading" + V "nestable_block" + horizontal_rule

M.heading = (P "*" ^ 1 / string.len) * whitespace ^ 1 * Ct(V "ParaSeg") / token.heading

return M
