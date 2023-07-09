require "globals"

local function flatten(obj)
    return function(content, ...)
        return pandoc[obj](flatten_table(content), ...)
    end
end

---@type table<string, string|function>
local M = {
    space = "Space",
    soft_break = "SoftBreak",
    line_break = "LineBreak",
    str = "Str",
    punc = "Str",
    para = flatten "Para",
    para_seg = function(...) return ... end,
    inlines = "Inlines",
    bullet_list = "BulletList",
    ordered_list = "OrderedList",
    quote = "BlockQuote",
    pandoc = "Pandoc",
    heading = "Header",
    bold = flatten "Strong",
    italic = flatten "Emph",
    underline = flatten "Underline",
    strikethrough = flatten "Strikeout",
    spoiler = function(inline)
        return pandoc.Span(flatten_table(inline), { class = "spoiler" })
    end,
    superscript = flatten "Superscript",
    subscript = flatten "Subscript",
    inline_code = "Code",
    null_modifier = function() return nil end,
    -- TODO: excape punctuations in free-form markup (ex: `10$`)
    inline_math = function(text) return pandoc.Math("InlineMath", text) end,
    variable = function(inline)
        return pandoc.Span(inline, { class = "variable" })
    end,
    horizontal_rule = "HorizontalRule",
    link = "Link",
    inline_link_target = function(id, inline)
        id = make_id_from_str(id)
        return pandoc.Span(inline, { id = id, class = "target" })
    end,
    code_block = "CodeBlock",
    -- TODO: add class
    definition_text = "Span",
    definition_list = "DefinitionList",
    note = "Note",
    div = "Div",
}

local function t_with_val(id)
    return function(...) return { t = id, ... } end
end
local function t_none_val(id)
    return function() return { t = id } end
end

-- build token
for key, value in pairs(M) do
    if pandoc then
        if type(value) == "string" then
            M[key] = pandoc[value]
        end
    else
        if
            key == "space"
            or key == "soft_break"
            or key == "line_break"
            or key == "horizontal_rule"
        then
            M[key] = t_none_val(key)
        elseif key == "inlines" then
            M[key] = function(...) return ... end
        else
            M[key] = t_with_val(key)
        end
    end
end

return M
