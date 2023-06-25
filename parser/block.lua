require "globals"

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
    return Ct(
        whitespace ^ 0
        * sp ^ lev
        * #-sp
        * whitespace
        * V "Para"
        * line_ending
        * choice {
            Ct(subitem "-" ^ 1) / token.bullet_list,
            Ct(subitem "~" ^ 1) / token.ordered_list,
            Cc(nil),
        }
    )
end

M.unordered_list = Ct(list_item(1, "-") ^ 1) / token.bullet_list
M.ordered_list = Ct(list_item(1, "~") ^ 1) / token.ordered_list
M.list = V "UnorderedList" + V "OrderedList"

local horizontal_rule = P "_" ^ 3 / token.horizontal_rule

M.detached_modifier = choice {
    V "Heading",
    V "list",
}

M.block = choice {
    V "detached_modifier",
    V "Para",
}

M.heading = (P "*" ^ 1 / string.len) * whitespace ^ 1 * Ct(V "ParaSeg") / token.heading

return M
