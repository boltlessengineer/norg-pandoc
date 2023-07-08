require "globals"

local block = require "parser.block"
local token = require "token"

local M = {}

local paragraph_terminate = choice {
    (whitespace ^ 0 * line_ending),
    -- detached modifier starts
    (whitespace ^ 0 * S "*-~>%" ^ 1 * whitespace),
    (whitespace ^ 0 * choice {
        P "^^",
        P "$$",
    } * line_ending),
    V "delimiting_mod",
    block.verbatim_ranged_tag,
    -- V "strong_carryover_tag"
}

local non_repeat_eol = whitespace ^ 0
    * (line_ending - line_ending * paragraph_terminate)
    * whitespace ^ 0
local paragraph_seg_patt = choice {
    V "Link",
    V "Styled",
    wordchar ^ 1 / token.str,
    escape_sequence / token.punc,
    punctuation / token.punc,
    (whitespace - non_repeat_eol) ^ 1 / token.space,
}

-- re-check preceding whitespaces for nested blocks
M.paragraph_segment = whitespace ^ 0
    * Ct(paragraph_seg_patt ^ 1)
    / token.para_seg
    * empty_pat(function() M.state = {} end)

local soft_break = line_ending / token.soft_break
M.paragraph = Ct(
    V "ParaSeg" * (soft_break * (V "ParaSeg" - paragraph_terminate)) ^ 0
) / token.para

M.state = {}

-- TODO: make Inline parsing as Group. parse after all higher precedences are captured

local function attached_modifier(punc_char, verbatim, ignore_punc)
    local punc = P(punc_char)
    local non_whitespace_char = wordchar + punctuation
    local ignore = ignore_punc
            and #-B(whitespace + line_ending_ch + P "\\") * P(ignore_punc)
        or P(false)

    local pre = Cmt(P(true), function()
        if M.state[punc_char] then
            return false
        end
        M.state[punc_char] = true
        return true
    end)
    local post = Cmt(P(true), function()
        M.state[punc_char] = false
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
        (wordchar + (punctuation - ignore - free_modi_end)) ^ 1 / token.str,
        non_repeat_eol / token.soft_break,
        whitespace / token.space,
    } ^ 1)
    -- TODO: parse as verbatim first, and capture as paragraph_segments
    local inner_capture = Ct(choice {
        non_repeat_eol,
        Ct((paragraph_seg_patt - ignore - modi_end) ^ 1) / token.para_seg,
    } ^ 1)
    if verbatim then
        free_inner_capture = C(choice {
            (wordchar + (punctuation - ignore - free_modi_end)) ^ 1,
            non_repeat_eol,
            whitespace,
        } ^ 1)
        inner_capture = C(choice {
            (wordchar + escape_sequence + (punctuation - ignore - modi_end))
                ^ 1,
            non_repeat_eol,
            whitespace,
        } ^ 1)
    end
    return choice {
        free_modi_start * free_inner_capture * free_modi_end,
        modi_start * inner_capture * modi_end,
    }
end

local function make_styled(ignore_punc)
    return choice {
        attached_modifier("*", false, ignore_punc) / token.bold,
        attached_modifier("/", false, ignore_punc) / token.italic,
        attached_modifier("_", false, ignore_punc) / token.underline,
        attached_modifier("-", false, ignore_punc) / token.strikethrough,
        attached_modifier("!", false, ignore_punc) / token.spoiler,
        attached_modifier("^", false, ignore_punc) / token.superscript,
        attached_modifier(",", false, ignore_punc) / token.subscript,
        attached_modifier("`", true, ignore_punc) / token.inline_code,
        attached_modifier("%", false, ignore_punc) / token.null_modifier,
        attached_modifier("$", true, ignore_punc) / token.inline_math,
        attached_modifier("&", true, ignore_punc) / token.variable,
    }
end

M.styled = make_styled()

local inline_grammar = P {
    Ct(choice {
        V "Styled",
        wordchar ^ 1 / token.str,
        escape_sequence / token.punc,
        punctuation / token.punc,
        whitespace ^ 0 * line_ending * whitespace ^ 0 / token.soft_break,
        whitespace ^ 1 / token.space,
    } ^ 1),
    Styled = M.styled,
    Link = P(false),
    delimiting_mod = choice {
        block.week_delimiting_mod,
        block.strong_delimiting_mod,
        block.horizontal_rule,
    },
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
        * Ct(choice {
            make_styled(punc),
            V "Link",
            wordchar ^ 1 / token.str,
            escape_sequence / token.punc,
            punctuation / token.punc - P(punc),
            whitespace ^ 0 * line_ending * whitespace ^ 0 / token.soft_break,
            whitespace ^ 1 / token.space,
        } ^ 1)
        * B(non_space)
end
local link_desc = P "[" * link_desc_inner "]" * P "]"

local function link_handler(file_loc, kind, raw_dest, desc)
    -- pretty_print(file_loc)
    -- pretty_print(kind)
    -- pretty_print(raw_dest)
    -- pretty_print(desc)
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
                    return token.note(content),
                        token.superscript { " ", table.unpack(desc) }
                else
                    return token.note(content)
                end
                -- FIX: This doesn't work. `M.state` is only valid while parsing
            elseif M.state["^"] or M.state[","] then
                return token.str(raw_dest)
            else
                return token.superscript(raw_dest)
            end
        else
            desc_content = inline_grammar:match(raw_dest)
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

return M
