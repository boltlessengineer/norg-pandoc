local M = {}

local function count_child(t)
    local count = 0
    for _, v in ipairs(t) do
        count = count + 1
        if type(v) == "table" then
            count = count + count_child(v)
        else
        end
    end
    return count
end

local function pretty_non_table(val)
    if type(val) == "string" then
        return string.format("%q", val)
    else
        return tostring(val)
    end
end

local function pretty_table_inline(tb)
    local res = ""
    for k, v in ipairs(tb) do
        local lead = k == 1 and "" or ", "
        local v_str
        if type(v) == "table" then
            v_str = pretty_table_inline(v)
        else
            v_str = pretty_non_table(v)
        end
        res = res .. lead .. v_str
    end
    if tb.t then
        return table.concat({ tb.t, res ~= "" and res or nil }, " ")
    else
        return "[ " .. res .. " ]"
    end
end

local function indent_str(indent) return string.rep("  ", indent) end

-- yes, this is quite spaghetti code. but it is working :)
function M.pretty_table(tb, indent)
    indent = indent or 0
    if count_child(tb) < 7 then
        return pretty_table_inline(tb) .. "\n"
    else
        local res = ""
        local is_token = not not tb.t
        if is_token then
            res = tb.t .. "\n"
        end
        for k, v in ipairs(tb) do
            -- stylua: ignore
            local lead = k == 1
                and (is_token and indent_str(indent) or "")
                or indent_str(indent - 1) .. ", "
            local v_str
            if type(v) == "table" then
                v_str = M.pretty_table(v, indent + 1)
            else
                v_str = pretty_non_table(v) .. "\n"
            end
            res = res .. (lead .. v_str)
        end
        if tb.t then
            return res
        end
        return table.concat {
            "[ ",
            res,
            indent_str(indent - 1) .. "]\n",
        }
    end
end

return M
