---@type table<string, string|function>
local M = {
    space = "Space",
    soft_break = "SoftBreak",
    line_break = "LineBreak",
    str = "Str",
    punc = "Str",
    para = function(content) return pandoc.Para(flatten_table(content)) end,
    para_seg = function(...) return ... end,
    inlines = "Inlines",
    bullet_list = "BulletList",
    ordered_list = "OrderedList",
    quote = "BlockQuote",
    pandoc = "Pandoc",
    heading = "Header",
    bold = "Strong",
    italic = "Emph",
    underline = "Underline",
    strikethrough = "Strikeout",
    spoiler = function(inline)
        return pandoc.Span(inline, { class = "spoiler" })
    end,
    superscript = "Superscript",
    subscript = "Subscript",
    inline_code = "Code",
    null_modifier = function() return nil end,
    inline_math = function(text) return pandoc.Math("InlineMath", text) end,
    variable = function(inline)
        return pandoc.Span(inline, { class = "variable" })
    end,
    horizontal_rule = "HorizontalRule",
    link = "Link",
    code_block = "CodeBlock",
    definition_text = "Span",
    definition_list = "DefinitionList",
    note = "Note",
}

local function t_with_val(id)
    return function(...) return { _t = id, ... } end
end
local function t_none_val(id)
    return function() return { _t = id } end
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
