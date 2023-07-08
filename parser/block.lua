require "globals"

local token = require "token"

local M = {}

M.week_delimiting_mod = P "-" ^ 2 * line_ending
M.strong_delimiting_mod = P "=" ^ 2 * line_ending
M.horizontal_rule = P "_" ^ 2 * line_ending / token.horizontal_rule

local ext_wordchar = (wordchar + punctuation - (P ")" - P "|")) ^ 1
local ext_ch = S " x?!+-=_@#<>"
local ext_item = C(ext_ch * (whitespace * ext_wordchar) ^ 0)
local ext =
    Ct(P "(" * ext_item * (P "|" * ext_item) ^ 0 * P ")" * whitespace ^ 1)

-- TODO: this should be moved to `token.detached_ext`
local function handle_ext(cap, str, content)
    for _, e in ipairs(cap) do
        if e == "x" then
            content = {
                pandoc.RawInline("html", "<label><input type=\"checkbox\" checked>"),
                pandoc.RawInline("latex", "$\\boxtimes$"),
                pandoc.Space(),
                table.unpack(content),
            }
            content[#content+1] = pandoc.Space()
            content[#content+1] = pandoc.RawInline("html", "</label>")
        else
            content = {
                pandoc.RawInline("html", "<label><input type=\"checkbox\">"),
                pandoc.RawInline("latex", "$\\square$"),
                pandoc.Space(),
                table.unpack(content),
            }
            content[#content+1] = pandoc.Space()
            content[#content+1] = pandoc.RawInline("html", "</label>")
        end
    end
    return str, content
end

M.heading = P(true)
    * (P "*" ^ 1 / string.len)
    * whitespace ^ 1
    * choice {
        ext * C(V "ParaSeg") / handle_ext,
        C(V "ParaSeg"),
    }
    * line_ending
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
            * line_ending
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
    -- range-able
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
    M.verbatim_ranged_tag = C(whitespace ^ 0 / string.len)
        * _start
        * C((1 - _end) ^ 1)
        * _end
        / function(ws_ch, indent, name, param, content)
            if name == "document.meta" then
                -- TODO: remove this line and return parsed document
                table.insert(param, 1, name)
            elseif name ~= "code" then
                table.insert(param, 1, name)
            end
            local class = table.concat(param, " ")
            if indent > 0 then
                local repl = (P(ws_ch) / "")
                content = lpeg.match(
                    Cs(repl * (line_ending * repl + 1) ^ 0),
                    content
                ) or content
            end
            return token.code_block(content, { class = class })
        end
end

return M
