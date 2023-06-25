require "globals"
local token = require "token"

local M = {}

local paragraph_break = whitespace ^ 0 * line_ending
local paragraph_end = paragraph_break
local soft_break = line_ending * #-paragraph_break

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
        (wordchar + escape_sequence + (#-modi_end * punctuation)) ^ 1 / token.str,
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

M.paragraph_segment = Ct(choice {
    V "Styled",
    (wordchar + escape_sequence) ^ 1 / token.str,
    punctuation / token.str,
    whitespace / token.space,
} ^ 1) / token.para_seg

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

M.paragraph = V "ParaSeg" * ((soft_break / token.soft_break) * V "ParaSeg") ^ 0 * paragraph_end ^ 0 / token.para

return M
