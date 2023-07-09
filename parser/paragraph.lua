require "globals"

local block = require "parser.block"
local token = require "token"

local M = {}

local function parse_cap(cap) return M.inline:match(cap) end

local paragraph_terminate = choice {
    (whitespace ^ 0 * line_ending),
    -- detached modifier starts
    (whitespace ^ 0 * S "*-~>%" ^ 1 * whitespace),
    (whitespace ^ 0 * choice {
        P "^^",
        P "$$",
        P "::",
    } * line_ending),
    (whitespace ^ 0 * S "$^:" * whitespace),
    choice {
        block.week_delimiting_mod,
        block.strong_delimiting_mod,
        block.horizontal_rule,
    },
    block.verbatim_ranged_tag,
    (whitespace ^ 0 * P "|" * wordchar ^ 1),
    -- V "strong_carryover_tag"
}

local non_repeat_eol = whitespace ^ 0
    * (line_ending - line_ending * paragraph_terminate)
    * whitespace ^ 0
local seg_break = choice {
    whitespace ^ 1 * P ":" * whitespace ^ 1,
    whitespace ^ 0 * line_ending * whitespace ^ 0,
}
local paragraph_seg_patt = choice {
    V "Link",
    V "Styled",
    wordchar ^ 1 / token.str,
    escape_sequence / token.punc,
    punctuation / token.punc,
    (whitespace - seg_break) ^ 1 / token.space,
}

-- re-check preceding whitespaces for nested blocks
M.paragraph_segment = whitespace ^ 0
    * Ct(paragraph_seg_patt ^ 1)
    / token.para_seg

local soft_break = line_ending / token.soft_break
M.paragraph = Ct(
    V "_ParaSeg"
        * whitespace ^ 0
        * (soft_break * (V "_ParaSeg" - paragraph_terminate)) ^ 0
) - whitespace ^ 0 * P "|end"

M.state = {}

local function attached_modifier(punc_char, verbatim)
    local punc = P(punc_char)
    local non_whitespace_char = wordchar + punctuation

    local pre = Cmt(P(true), function()
        if M.state[punc_char] then
            return false
        end
        -- M.state[punc_char] = true
        return true
    end)
    local post = Cmt(P(true), function()
        -- M.state[punc_char] = false
        return true
    end)

    local modi_start = (
        choice {
            B(wordchar) * P ":",
            #-B(wordchar + punc),
        }
        * punc
        * #non_whitespace_char
    ) * pre
    local modi_end = B(non_whitespace_char)
        * punc
        * choice {
            (P ":") * #wordchar,
            -wordchar,
        }
        * post
    local free_modi_start = (#-B(wordchar) * punc * P "|")
    local free_modi_end = P "|" * punc * -wordchar

    local free_inner_capture = Ct(choice {
        (wordchar + (punctuation - free_modi_end)) ^ 1 / token.str,
        non_repeat_eol / token.soft_break,
        whitespace / token.space,
    } ^ 1)
    local inner_capture = C(choice {
        wordchar ^ 1,
        escape_sequence ^ 1,
        V "Styled" - modi_start,
        V "Link",
        (punctuation - modi_end) ^ 1,
        line_ending * -#paragraph_terminate,
        whitespace ^ 1,
    } ^ 1) / function(cap)
        M.state[punc_char] = true
        local match = M.inline:match(cap)
        M.state[punc_char] = false
        return match
    end
    if verbatim then
        free_inner_capture = C(choice {
            (wordchar + (punctuation - free_modi_end)) ^ 1,
            non_repeat_eol,
            whitespace,
        } ^ 1)
        inner_capture = Cs(choice {
            escape_sequence,
            (wordchar + (punctuation - modi_end)) ^ 1,
            non_repeat_eol,
            whitespace,
        } ^ 1)
    end
    return choice {
        free_modi_start * free_inner_capture * free_modi_end,
        modi_start * inner_capture * modi_end,
    }
end

M.styled = choice {
    attached_modifier("*", false) / token.bold,
    attached_modifier("/", false) / token.italic,
    attached_modifier("_", false) / token.underline,
    attached_modifier("-", false) / token.strikethrough,
    attached_modifier("!", false) / token.spoiler,
    attached_modifier("^", false) / token.superscript,
    attached_modifier(",", false) / token.subscript,
    attached_modifier("`", true) / token.inline_code,
    attached_modifier("%", false) / token.null_modifier,
    attached_modifier("$", true) / token.inline_math,
    attached_modifier("&", true) / token.variable,
}

local file_loc_pattern = P(true)
    * P ":"
    * Cs(choice {
        wordchar,
        escape_sequence,
        whitespace / "",
        line_ending / "",
        punctuation - P ":",
    } ^ 1)
    * (B(wordchar) * P ":")
local non_space = wordchar + punctuation
local not_end = (P(1) - P "}") ^ 1
local function remove_whitespace(str)
    local p = Cs(((S " \t\r\n" ^ 1 / "" - escape_sequence) + lpeg.P(1)) ^ 1)
    return p:match(str)
end
local link_dest = P "{"
    * Cnil(file_loc_pattern ^ -1)
    * choice {
        C(P "*" ^ 1) * whitespace ^ 1 * C(not_end),
        C(P "$") * whitespace ^ 1 * C(not_end),
        C(P "$$") * whitespace ^ 1 * C(not_end),
        C(P "^") * whitespace ^ 1 * C(not_end),
        C(P "^^") * whitespace ^ 1 * C(not_end),
        C(P "#") * whitespace ^ 1 * C(not_end),
        C(P "/") * whitespace ^ 1 * (C(not_end) / remove_whitespace),
        Cc(false) * #non_space * (C(not_end) / remove_whitespace), -- URL type
        Cc(false) * Cc(false), -- only File Location
    }
    * B(non_space)
    * P "}"
local function link_desc_inner(punc)
    return P(true)
        * #non_space
        * C(choice {
            wordchar ^ 1,
            escape_sequence,
            V "Link",
            punctuation - B(non_space) * P(punc),
            line_ending * whitespace ^ 0 * #-line_ending,
            whitespace ^ 1,
        } ^ 1)
        / parse_cap
        / flatten_table
        * B(non_space)
end
local link_desc = P "[" * link_desc_inner "]" * P "]"

local function link_handler(file_loc, kind, raw_dest, desc)
    -- print "link==="
    -- pretty_print(file_loc)
    -- pretty_print(kind)
    -- pretty_print(raw_dest)
    -- pretty_print(desc)
    -- print "======="
    local target_str = ""
    if file_loc then
        target_str = file_loc .. ".norg"
    end
    local desc_content = desc or file_loc or raw_dest
    if kind then
        if kind == "/" then
        elseif kind:sub(1, 1) == "^" then
            local title = make_id_from_str(raw_dest)
            local content = require("parser.block").footnotes[title]
            if content then
                if desc then
                    -- pretty_print(desc)
                    return token.note(content),
                        token.superscript { " ", table.unpack(desc) }
                else
                    return token.note(content)
                end
                -- FIX: This doesn't work. `M.state` is only valid while parsing
            elseif M.state["^"] or M.state[","] then
                return token.str(desc or raw_dest)
            else
                return token.superscript(desc or raw_dest)
            end
        else
            desc_content = desc
                or flatten_table((line_ending ^ 0 * M.inline):match(raw_dest))
            target_str = target_str .. "#" .. make_id_from_str(raw_dest)
        end
    end
    if string.len(target_str) == 0 then
        target_str = raw_dest
    end
    return token.link(desc_content, target_str)
end
M.link = link_dest * link_desc ^ -1 / link_handler

local anchors = {}
M.anchor = C(link_desc)
    * link_dest ^ -1
    / function(raw_desc, desc, file_loc, kind, raw_dest)
        local desc_id = make_id_from_str(raw_desc)
        if file_loc or raw_dest then
            local element = link_handler(file_loc, kind, raw_dest, desc)
            anchors[desc_id] = element
            return element
        else
            local element = anchors[desc_id]
            if not element then
                element = link_handler(nil, false, "", desc)
            end
            return element
        end
    end

M.inline_link_target = P "<"
    * C(link_desc_inner ">")
    * P ">"
    / token.inline_link_target

local group = {
    "_Para",
    _Para = M.paragraph,
    _ParaSeg = M.paragraph_segment,
    Styled = M.styled,
    Link = choice {
        M.link,
        M.anchor,
        M.inline_link_target,
    },
}
M.inline = P(group)
group[1] = "_ParaSeg"
M.inline_segment = P(group)

return M
