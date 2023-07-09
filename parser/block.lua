require "globals"

local token = require "token"

local M = {}

M.week_delimiting_mod = whitespace ^ 0 * P "-" ^ 2 * line_ending
M.strong_delimiting_mod = whitespace ^ 0 * P "=" ^ 2 * line_ending
M.horizontal_rule = (whitespace ^ 0 * P "_" ^ 2 * line_ending)
    / token.horizontal_rule

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
                pandoc.RawInline(
                    "html",
                    '<label><input type="checkbox" checked>'
                ),
                pandoc.RawInline("latex", "$\\boxtimes$"),
                pandoc.Space(),
                table.unpack(content),
            }
            content[#content + 1] = pandoc.Space()
            content[#content + 1] = pandoc.RawInline("html", "</label>")
        else
            content = {
                pandoc.RawInline("html", '<label><input type="checkbox">'),
                pandoc.RawInline("latex", "$\\square$"),
                pandoc.Space(),
                table.unpack(content),
            }
            content[#content + 1] = pandoc.Space()
            content[#content + 1] = pandoc.RawInline("html", "</label>")
        end
    end
    return str, content
end

M.heading = whitespace ^ 0
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
        return whitespace ^ 0
            * P(prefix_ch)
            * whitespace ^ 1
            * C(V "ParaSeg")
            * choice {
                whitespace ^ 1 * P ":" * whitespace ^ 1,
                (whitespace ^ 0 * line_ending * whitespace ^ 0) ^ 1,
            }
            * V "Para"
            * line_ending
    end

    local function rangeable_ranged_capture(prefix_ch)
        local modifier = P(prefix_ch .. prefix_ch)
        return modifier
            * whitespace ^ 1
            * C(V "ParaSeg")
            * choice {
                whitespace ^ 1 * P ":" * whitespace ^ 1,
                (whitespace ^ 0 * line_ending * whitespace ^ 0) ^ 1,
            }
            * Ct(choice {
                (whitespace + line_ending),
                (V "Block" - modifier),
            } ^ 1)
            * whitespace ^ 0
            * modifier
            * whitespace ^ 0
            * line_ending
    end

    M.definition_list = whitespace ^ 0
        * Ct(seq {
            Ct(choice {
                rangeable_single_capture "$",
                rangeable_ranged_capture "$",
            }),
            ((whitespace + line_ending) ^ 0 * Ct(choice {
                rangeable_single_capture "$",
                rangeable_ranged_capture "$",
            })) ^ 0,
        })
        / function(defs)
            local list = {}
            for i, item in ipairs(defs) do
                local raw, txt, def = table.unpack(item)
                local title = make_id_from_str(raw)
                list[i] = { token.definition_text(txt, { id = title }), def }
            end
            return token.definition_list(list)
        end

    M.footnotes = {}

    M.footnote = whitespace ^ 0
        * Cmt(
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

    M.table_cells = whitespace ^ 0
        * choice {
            rangeable_single_capture ":",
            rangeable_ranged_capture ":",
            -- HACK: implement this someday
            P "::" * line_ending,
        }
        / function(_raw, _txt, _def) return pandoc.Para "not implemented yet" end
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
        * C((wordchar + punctuation) ^ 1 - P "end")
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

do
    local _end = make_end(standard_ranged_tag_prefix)
    local _start = standard_ranged_tag_prefix
        * C((wordchar + punctuation) ^ 1 - P "end")
        * Ct((whitespace ^ 1 * C((wordchar + punctuation) ^ 1)) ^ 0)
        * line_ending
    M.standard_ranged_tag = C(whitespace ^ 0 / string.len)
        * _start
        * C(Ct(choice {
            V "standard_ranged_tag",
            V "verbatim_ranged_tag",
            V "detached_modifier",
            V "delimiting_mod",
            V "Para" * line_ending,
            (whitespace ^ 0 * line_ending),
        } ^ 0))
        * _end
        / function(ws_ch, indent, name, param, content, parsed)
            if name == "comment" then
                return
            elseif name == "example" then
                table.insert(param, 1, "norg")
            elseif name == "group" then
                return token.div(parsed)
            else
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
