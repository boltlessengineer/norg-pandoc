require "globals"

local token = require "token"

local M = {}

local function quote_item(lev)
    local start_p = P ">"
    local function subitem()
        if lev < 6 then
            return quote_item(lev + 1)
        else
            return (1 - 1) -- fails
        end
    end
    -- stylua: ignore
    return Ct(
        (whitespace ^ 0
        * start_p ^ lev
        * whitespace ^ 1
        * V "Para"
        * line_ending) ^ 1
        * choice {
            P(true) * subitem() / token.quote,
            -- HACK: hacky way to avoid "loop body may accept empty string" compile error
            Cc(nil),
        }
    )
end

M.quote = quote_item(1) / token.quote

M.week_delimiting_mod = P "-" ^ 2 * line_ending
M.strong_delimiting_mod = P "=" ^ 2 * line_ending
M.horizontal_rule = P "_" ^ 2 * line_ending / token.horizontal_rule

M.heading = P(true)
    * (P "*" ^ 1 / string.len)
    * whitespace ^ 1
    * C(V "ParaSeg")
    / function(lev, str, content)
        local id = make_id_from_str(str)
        return lev, content, id
    end
    / token.heading

do
    local function rangeable_single_capture(prefix_ch)
        return P(prefix_ch)
            * whitespace ^ 1
            * C(V "ParaSeg")
            * (line_ending * whitespace ^ 0) ^ 1
            * V "Para"
    end

    local function rangeable_ranged_capture(prefix_ch)
        local modifier = P(prefix_ch .. prefix_ch)
        return modifier
            * whitespace ^ 1
            * C(V "ParaSeg")
            * Ct(choice {
                (whitespace + line_ending),
                (V "Block" - modifier),
            } ^ 0)
            * whitespace ^ 0
            * modifier
            * whitespace ^ 0
            * line_ending
    end

    M.definition_list = Ct(Ct(choice {
        rangeable_single_capture "$",
        rangeable_ranged_capture "$",
    } * (whitespace + line_ending) ^ 0) ^ 1) / function(defs)
        local list = {}
        for i, item in ipairs(defs) do
            local raw, txt, def = table.unpack(item)
            local title = make_id_from_str(raw)
            list[i] = { token.definition_text(txt, { id = title }), def }
        end
        return token.definition_list(list)
    end

    M.footnotes = {}

    M.footnote = Cmt(
        choice {
            rangeable_single_capture "^",
            rangeable_ranged_capture "^",
        },
        function(_, _, raw, _txt, def)
            local title = make_id_from_str(raw)
            pretty_print(def)
            M.footnotes[title] = def
            return true
        end
    )
end

M.detached_modifier = choice {
    -- structural
    V "Heading",
    -- nestable
    V "list",
    V "quote",
    -- TODO: range-able
    V "definition",
    V "footnote",
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
    V "delimiting_mod",
    V "Para",
}

return M
