require "globals"
local token = require "token"

local M = {}

local state = {}

local function attached_modifier(punc_char, verbatim)
    local punc = P(punc_char)
    local non_whitespace_char = wordchar + punctuation

    local pre = Cmt(P(true), function()
        if state[punc_char] then
            return false
        end
        state[punc_char] = true
        return true
    end)
    local post = Cmt(P(true), function()
        state[punc_char] = false
        return true
    end)

    local modi_start = (#-B(wordchar) * punc * #non_whitespace_char) * pre
    local modi_end = B(non_whitespace_char) * punc * -wordchar * post
    local free_modi_start = (#-B(wordchar) * punc * P "|")
    local free_modi_end = P "|" * punc * -wordchar

    local non_repeat_eol = (line_ending - line_ending ^ 2)
    local inner_capture = Ct(choice {
        (#(punctuation - punc) * (V "Styled")),
        V "Link",
        wordchar ^ 1 / token.str,
        escape_sequence + (#-modi_end * punctuation) / token.punc,
        whitespace / token.space,
        non_repeat_eol / token.soft_break,
    } ^ 1)
    local free_inner_capture = Ct(choice {
        (wordchar + (#-free_modi_end * punctuation)) ^ 1 / token.str,
        whitespace / token.space,
        non_repeat_eol / token.soft_break,
    } ^ 1)
    if verbatim then
        free_inner_capture = C(choice {
            (wordchar + (#-free_modi_end * punctuation)) ^ 1,
            whitespace,
            non_repeat_eol,
        } ^ 1)
        inner_capture = C(choice {
            (wordchar + escape_sequence + (#-modi_end * punctuation)) ^ 1,
            whitespace,
            non_repeat_eol,
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

local link_dest = P "{" * C((1 - (P "}" + line_ending)) ^ 0) * P "}"
local link_desc = P "[" * C((1 - (P "]" + line_ending)) ^ 0) * P "]"

M.link = link_dest
    * link_desc ^ -1
    / function(dest, desc)
        local text = desc or dest
        -- TODO: how can we handle magic char(#)?
        local heading = (P "*" ^ 1 * whitespace ^ 1 / "h-") * (C(P(1) ^ 1) / make_id_from_str)
        -- TODO: implement this
        local file_location = P(true)
        local p = Cs(choice {
            file_location * choice {
                heading,
                -- definitions,
                -- footnotes,
            },
            P(1) ^ 1,
        })
        dest = p:match(dest)
        return token.link(text, dest)
    end
-- TODO: implement anchor
M.anchor = link_desc * (link_dest + link_desc) ^ -1

-- re-check preceding whitespaces for nested blocks
M.paragraph_segment = (
    whitespace ^ 0
    * choice {
            V "Styled",
            V "Link",
            wordchar ^ 1 / token.str,
            escape_sequence / token.punc,
            punctuation / token.punc,
            whitespace / token.space,
        }
        ^ 1
) / token.para_seg

local soft_break = line_ending / token.soft_break
local paragraph_terminate = choice {
    (whitespace ^ 0 * line_ending),
    -- detached modifier starts
    (whitespace ^ 0 * S "*-~>%" ^ 1 * whitespace ^ 1),
    -- V "delimiting_modifier",
    -- V "ranged_tag",
    -- V "strong_carryover_tag"
}
M.paragraph = Ct(V "ParaSeg" * (soft_break * (V "ParaSeg" - paragraph_terminate)) ^ 0) / token.para

return M
