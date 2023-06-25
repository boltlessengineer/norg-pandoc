local function empty_fn(...)
    return ...
end

---returns token function. use pandoc if possible
---@param id string
---@param fallback? fun(function, ...): any
local function pandoc_fb(id, fallback)
    if pandoc then
        if pandoc[id] and not fallback then
            return pandoc[id]
        elseif fallback then
            return function(...)
                return fallback(pandoc[id], ...)
            end
        else
            return empty_fn
        end
    else
        if id == "Space" or id == "SoftBreak" or id == "LineBreak" then
            return function()
                return { id }
            end
        end
        return function(...)
            return { id, ... }
        end
    end
end

local M = {
    str = pandoc_fb "Str",
    -- punc = pandoc_fb "Str",
    para = pandoc_fb "Para",
    space = pandoc_fb "Space",
    para_seg = pandoc_fb "Inlines",
    soft_break = pandoc_fb "SoftBreak",
    bullet_list = pandoc_fb "BulletList",
    ordered_list = pandoc_fb "OrderedList",
    _plain = pandoc_fb "Plain",
    pandoc = pandoc_fb "Pandoc",
    heading = pandoc_fb("Header", function(header, ...)
        local args = { ... }
        -- TODO: args[3] is attr. we can put id to header from here
        -- e.g. in markdown, `# heading 1` have id attr value `heading-1`
        return header(args[1], args[2], args[3])
    end),
    bold = pandoc_fb "Strong",
    italic = pandoc_fb "Emph",
    underline = pandoc_fb "Underline",
    strikethrough = pandoc_fb "Strikeout",
    spoiler = pandoc_fb("Span", function(span, inline)
        return span(inline, { class = "spoiler" })
    end),
    superscript = pandoc_fb "Superscript",
    subscript = pandoc_fb "Subscript",
    inline_code = pandoc_fb "Code",
    null_modifier = function()
        return nil
    end,
    inline_math = pandoc_fb("Math", function(math, text)
        return math("InlineMath", text)
    end),
    -- TODO: add custom class (or id) for it
    variable = pandoc_fb "Str",
    horizontal_rule = pandoc_fb "HorizontalRule",
}

return M
