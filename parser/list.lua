require "globals"

local token = require "token"

local M = {}

local list_lev = { 0 }
function list_lev:push(lev) table.insert(list_lev, lev) end
function list_lev:last() return list_lev[#list_lev] end
function list_lev:pop()
    local popped = list_lev[#list_lev]
    list_lev[#list_lev] = nil
    return popped
end
local is_sub_start = false

local function list_item(ch)
    local sub_pre = empty_pat(function() is_sub_start = true end)
    local sub_quit = empty_pat(function() is_sub_start = false end)
    return whitespace ^ 0
        * Cmt(P(ch) ^ 1 / string.len, function(_str, _pos, count)
            if count == list_lev:last() and not is_sub_start then
                return true
            elseif count > list_lev:last() then
                list_lev:push(count)
                is_sub_start = false
                return true
            else
                if not is_sub_start then
                    list_lev:pop()
                end
                is_sub_start = false
                return false
            end
        end)
        * whitespace ^ 1
        * Ct(V "Para" * line_ending * (sub_pre * choice {
            Ct(V "bullet_list_item" ^ 1) / token.bullet_list,
            Ct(V "ordered_list_item" ^ 1) / token.ordered_list,
        } + sub_quit))
end

M.bullet_list_item = list_item "-"
M.ordered_list_item = list_item "~"
M.unordered_list = Ct(M.bullet_list_item ^ 1) / token.bullet_list
M.ordered_list = Ct(M.ordered_list_item ^ 1) / token.ordered_list

return M
