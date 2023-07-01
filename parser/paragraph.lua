require "globals"
local token = require "token"

local M = {}

M.state = {}

local function attached_modifier(punc_char, verbatim)
    local punc = P(punc_char)
    local non_whitespace_char = wordchar + punctuation

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

    local modi_start = (#-B(wordchar) * punc * #non_whitespace_char) * pre
    local modi_end = B(non_whitespace_char) * punc * -wordchar * post
    local free_modi_start = (#-B(wordchar) * punc * P "|")
    local free_modi_end = P "|" * punc * -wordchar

    local non_repeat_eol = whitespace ^ 0
        * (line_ending - line_ending ^ 2)
        * whitespace ^ 0
    local inner_capture = Ct(choice {
        (#(punctuation - punc) * (V "Styled")),
        V "Link",
        wordchar ^ 1 / token.str,
        escape_sequence + (#-modi_end * punctuation) / token.punc,
        non_repeat_eol / token.soft_break,
        whitespace / token.space,
    } ^ 1)
    local free_inner_capture = Ct(choice {
        (wordchar + (#-free_modi_end * punctuation)) ^ 1 / token.str,
        whitespace / token.space,
        non_repeat_eol / token.soft_break,
    } ^ 1)
    if verbatim then
        free_inner_capture = C(choice {
            (wordchar + (#-free_modi_end * punctuation)) ^ 1,
            non_repeat_eol,
            whitespace,
        } ^ 1)
        inner_capture = C(choice {
            (wordchar + escape_sequence + (#-modi_end * punctuation)) ^ 1,
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
    attached_modifier "*" / token.bold,
    attached_modifier "/" / token.italic,
    attached_modifier "_" / token.underline,
    attached_modifier "-" / token.strikethrough,
    attached_modifier "!" / token.spoiler,
    attached_modifier "^" / token.superscript,
    attached_modifier "," / token.subscript,
    attached_modifier("`", true) / token.inline_code,
    attached_modifier "%" / token.null_modifier,
    attached_modifier("$", true) / token.inline_math,
    attached_modifier("&", true) / token.variable,
}

local inline_without_link = choice {
    V "Styled",
    wordchar ^ 1 / token.str,
    escape_sequence / token.punc,
    punctuation / token.punc,
    whitespace ^ 0 * line_ending * whitespace ^ 0 / token.soft_break,
    whitespace ^ 1 / token.space,
}

local file_loc_pattern = P(true)
    * P ":"
    * Cs(choice {
        wordchar,
        escape_sequence,
        whitespace / "",
        line_ending / "",
        P "/",
    } ^ 1)
    * (B(wordchar) * P ":")
local non_space = wordchar + punctuation
local link_dest = P "{"
    * Cnil(file_loc_pattern ^ -1)
    * #non_space
    * C(Ct((inline_without_link - P "}") ^ 0))
    * B(non_space)
    * P "}"
local link_desc = P "[" * #non_space * C((1 - P "]") ^ 0) * B(non_space) * P "]"

-- hacky local __eq implement
local function _eq(a, b)
    local type_eq = a._t == b._t
    local content_eq = a[1] == b[1]
    return type_eq and content_eq
end

local function is_space_eol(t)
    return _eq(t, token.space()) or _eq(t, token.soft_break())
end

local function slice_tbl(tbl)
    local sliced = {}
    local skipped = false
    for i = 3, #tbl do
        if skipped or not is_space_eol(tbl[i]) then
            skipped = true
            table.insert(sliced, tbl[i])
        end
    end
    return sliced
end

local function remove_whitespace(str)
    local p = Cs(((S " \t\r\n" ^ 1 / "" - escape_sequence) + lpeg.P(1)) ^ 1)
    return p:match(str)
end

local footnote_count = 0

M.link = link_dest
    * link_desc ^ -1
    / function(file_loc, raw_dest, dest, desc)
        local target = raw_dest
        local function has_prefix(prefix)
            return _eq(dest[1], token.punc(prefix)) and is_space_eol(dest[2])
        end
        -- TODO: how can we handle magic char(#)?
        if #raw_dest > 0 then
            if has_prefix "*" then
                dest = slice_tbl(dest)
                target = "#h-" .. make_id_from_str(raw_dest:sub(3, #raw_dest))
            elseif has_prefix "$" then
                dest = slice_tbl(dest)
                target = "#d-" .. make_id_from_str(raw_dest:sub(3, #raw_dest))
            elseif has_prefix "^" then
                footnote_count = footnote_count + 1
                dest = slice_tbl(dest)
                target = "#f-" .. make_id_from_str(raw_dest:sub(3, #raw_dest))
                -- TODO: {^ 1} : traditional type footnotes
                local note = require("parser.block").footnotes[dest]
                desc = desc or dest
                return token.footnote_link(desc, target)
            elseif has_prefix "/" then
                target = remove_whitespace(raw_dest:sub(3, #raw_dest))
                dest = target
            else
                target = remove_whitespace(target)
                dest = target
            end
        else
            target = file_loc .. ".norg"
            dest = file_loc
        end
        desc = desc or dest
        return token.link(desc, target)
    end

-- TODO: implement anchor
M.anchor = link_desc * (link_dest + link_desc) ^ -1

-- re-check preceding whitespaces for nested blocks
M.paragraph_segment = Ct(whitespace ^ 0 * choice {
    V "Styled",
    V "Link",
    wordchar ^ 1 / token.str,
    escape_sequence / token.punc,
    punctuation / token.punc,
    whitespace / token.space,
} ^ 1) / token.para_seg

local soft_break = line_ending / token.soft_break
local paragraph_terminate = choice {
    (whitespace ^ 0 * line_ending),
    -- detached modifier starts
    (whitespace ^ 0 * S "*-~>%" ^ 1 * whitespace ^ 1),
    -- V "delimiting_modifier",
    -- V "ranged_tag",
    -- V "strong_carryover_tag"
}
M.paragraph = Ct(
    V "ParaSeg" * (soft_break * (V "ParaSeg" - paragraph_terminate)) ^ 0
) / token.para

return M
