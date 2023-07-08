local function flatten_table(tbl)
    local res = {}
    for _, val in ipairs(tbl) do
        if type(val) == "table" then
            local flattened = flatten_table(val)
            for _, v in ipairs(flattened) do
                table.insert(res, v)
            end
        else
            table.insert(res, val)
        end
    end
    return res
end

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
    inline_link_target = function(id, inline)
        id = make_id_from_str(id)
        return pandoc.Span(inline, { id = id, class = "target" })
    end,
    code_block = "CodeBlock",
    -- TODO: add class
    definition_text = "Span",
    definition_list = "DefinitionList",
    note = "Note",
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
