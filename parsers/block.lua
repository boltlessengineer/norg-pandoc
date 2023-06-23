require('globals')

local paragarph = require('parsers.paragarph')
local token     = require('token')

local M = {}

local function list_item(lev, start)
	local sp = P(start)
	local subitem = function(s)
		if lev < 6 then
			return list_item(lev + 1, s)
		else
			return (1 - 1) -- fails
		end
	end
	-- stylua: ignore
	local parser = whitespace ^ 0
		* sp ^ lev
		* #-sp
		* whitespace
		* paragarph.paragraph_segment
		* line_ending
		* (Ct(subitem "-" ^ 1) / token.bullet_list
			+ Ct(subitem "~" ^ 1) / token.ordered_list
			+ Cc(nil))
		/ function(ils, sublist)
			return { token._plain(ils), sublist }
		end
	return parser
end

local unordered_list = Ct(list_item(1, "-") ^ 1) / token.bullet_list
local ordered_list = Ct(list_item(1, "~") ^ 1) / token.ordered_list
local list = unordered_list + ordered_list

local nestable_block = choice(
	list,
    paragarph.paragraph
)

local horizontal_rule = P "_" ^ 3 / token.horizontal_rule

M.block = nestable_block + horizontal_rule

M.heading = (P "*" ^ 1 / string.len)
    * whitespace ^ 1
    * Ct(paragarph.paragraph_segment)
    * line_ending
    / token.heading

return M
