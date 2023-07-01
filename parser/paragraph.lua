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

    local modi_start = (
        choice {
            B(wordchar) * P ":",
            #-B(wordchar),
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
local not_end = (P(1) - P "}") ^ 1
local function remove_whitespace(str)
    local p = Cs(((S " \t\r\n" ^ 1 / "" - escape_sequence) + lpeg.P(1)) ^ 1)
    return p:match(str)
end
local link_dest = P "{"
    * Cnil(file_loc_pattern ^ -1)
    -- * empty_pat(function(str, num) print(str:sub(num, num)) end)
    * choice {
        C(P "*" ^ 1) * whitespace ^ 1 * C(not_end),
        C(P "$") * whitespace ^ 1 * C(not_end),
        C(P "^") * whitespace ^ 1 * C(not_end),
        C(P "#") * whitespace ^ 1 * C(not_end),
        C(P "/") * whitespace ^ 1 * (C(not_end) / remove_whitespace),
        Cc(false) * #non_space * (C(not_end) / remove_whitespace),
        Cc(false) * Cc(false),
        -- P "$$" * whitespace ^ 1 * inline_cap,
        -- P "^^" * whitespace ^ 1 * inline_cap,
    }
    -- * empty_pat(function(str, num) print(str:sub(num, num)) end)
    * B(non_space)
    * P "}"
local link_desc = P(true)
    * P "["
    * #non_space
    * C((P(1) - P "]") ^ 1)
    * B(non_space)
    * P "]"

M.link = link_dest
    * link_desc ^ -1
    / function(file_loc, kind, raw_dest, desc)
        pretty_print(file_loc)
        pretty_print(kind)
        pretty_print(raw_dest)
        pretty_print(desc)
        local target = raw_dest
        if file_loc then
            target = file_loc .. ".norg"
            raw_dest = file_loc
        end
        desc = desc or raw_dest
        if kind then
            if kind == "/" then
            else
                desc = inline_grammar:match(raw_dest)
                target = "#" .. make_id_from_str(target)
                if kind:sub(1, 1) == "^" then
                    return token.footnote_link(desc, target)
                end
            end
        end
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
) / token.para * empty_pat(function() M.state = {} end)

return M
