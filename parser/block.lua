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

M.heading = P(true)
    * (P "*" ^ 1 / string.len)
    * whitespace ^ 1
    -- NOTE: parser one more time here to get actual captured table
    * C(V "ParaSeg" / function(...) return ... end)
    -- TODO: handle this in token.heading, not here.
    / function(lev, str, ...)
        local id = "h-" .. make_id_from_str(str)
        return lev, { ... }, id
    end
    / token.heading

-- TODO: range-able detached modifiers

M.detached_modifier = choice {
    -- structural
    V "Heading",
    -- nestable
    V "list",
    V "quote",
    -- TODO: range-able
}

local standard_ranged_tag_prefix = P "|"
local verbatim_ranged_tag_prefix = P "@"
local macro_ranged_tag_prefix = P "="

local function make_end(prefix)
    return B(line_ending_ch) * whitespace ^ 0 * prefix * P "end" * line_ending
end

do
    local _end = make_end(verbatim_ranged_tag_prefix)
    local _start = verbatim_ranged_tag_prefix
        * C((wordchar + punctuation) ^ 1)
        * Ct((whitespace ^ 1 * C((wordchar + punctuation) ^ 1)) ^ 0)
        * line_ending
    M.verbatim_ranged_tag = _start
        * C((1 - _end) ^ 1)
        * _end
        / function(name, param, content)
            local class = name .. " "
            if #param > 0 then
                class = table.concat(param, " ")
            end
            return token.code_block(content, { class = class })
        end
end

M.block = choice {
    V "detached_modifier",
    V "verbatim_ranged_tag",
    V "Para",
}

return M
