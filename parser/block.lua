require "globals"

local token = require "token"

local M = {}

local function list_item(lev, start)
    local start_p = P(start)
    local subitem = function(s)
        -- FIX: recursion is prevented by this logic
        -- so if this is removed, the parser will freeze
        if lev < 6 then
            return list_item(lev + 1, s)
        else
            return (1 - 1) -- fails
        end
    end
    -- stylua: ignore
    return Ct(
        whitespace ^ 0
        * start_p ^ lev
        * whitespace ^ 1
        -- HACK: this should rather be pandoc.Plain
        * V "Para"
        * line_ending
        * choice {
            Ct(subitem "-" ^ 1) / token.bullet_list,
            Ct(subitem "~" ^ 1) / token.ordered_list,
            Cc(nil),
        }
    )
end
local function quote_item(lev)
    local start_p = P ">"
    local subitem = function()
        if lev < 6 then
            return quote_item(lev + 1)
        else
            return (1 - 1) -- fails
        end
    end
    -- stylua: ignore
    return Ct(
        whitespace ^ 0
        * start_p ^ lev
        * whitespace ^ 1
        * V "Para"
        * line_ending
        * choice {
            P(true) * subitem() / token.quote,
            -- HACK: hacky way to avoid "loop body may accept empty string" compile error
            Cc(nil),
        }
    )
end

M.unordered_list = Ct(list_item(1, "-") ^ 1) / token.bullet_list
M.ordered_list = Ct(list_item(1, "~") ^ 1) / token.ordered_list
M.list = V "UnorderedList" + V "OrderedList"
M.quote = quote_item(1) / token.quote

local horizontal_rule = P "_" ^ 3 / token.horizontal_rule

M.heading = (P "*" ^ 1 / string.len) * whitespace ^ 1 * Ct(V "ParaSeg") / token.heading

M.detached_modifier = choice {
    V "Heading",
    V "list",
    V "quote",
}

M.block = choice {
    V "detached_modifier",
    V "Para",
}

return M
