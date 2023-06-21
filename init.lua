-- stylua: ignore
local P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt =
	lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt

local whitespace = S " \t"
local line_ending = P "\r" ^ -1 * P "\n"
local punctuation = S [[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]]

local wordchar = (1 - (whitespace + line_ending + punctuation))

local escape_sequence = Cs((P [[\]] / "") * P(1))

local week_delimiting_modifier = P "-" ^ 3
local strong_delimiting_modifier = P "=" ^ 3

local horizontal_rule = P "_" ^ 3 / pandoc.HorizontalRule

local nestableBlock = (
	V "List"
	-- + V "Quote" 
	+ V "Para"
)

local paragraph_break = whitespace ^ 0 * line_ending
-- TODO: 4 more types can be here
local paragraph_end = paragraph_break
local soft_break = line_ending * #-paragraph_break

local inline = (wordchar + escape_sequence) ^ 1 / pandoc.Str

local function attached_modifier(punc_char)
	local punc = P(punc_char)
	-- TODO: put B(-wordchar) here to check pattern before cursor
	return (punc * #-whitespace)
		* Ct((inline
				-- + (#-punc * V "Styled")
        + (#-punc * punctuation / pandoc.Str)
				+ (#-punc * punctuation / pandoc.Str)
				+ whitespace / pandoc.Space
				+ line_ending / pandoc.SoftBreak
					) ^ 1)
		* (#-whitespace * punc * #-wordchar)
end


-- stylua: ignore
local paragraph_segment =
		(
			inline
		+ V "Styled"
		+ punctuation / pandoc.Str
		+ whitespace / pandoc.Space
		) ^ 1

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
		* paragraph_segment
		* line_ending
		* (Ct(subitem "-" ^ 1) / pandoc.BulletList
		 + Ct(subitem "~" ^ 1) / pandoc.OrderedList
	 	 + Cc(nil))
		/ function(ils, sublist)
			return { pandoc.Plain(ils), sublist }
		end
	return parser
end

-- Grammar
G = P {
	"Doc",
	Doc = Ct((V "Block" + (whitespace + line_ending)) ^ 0) / pandoc.Pandoc,
	Block = (V "Heading" + nestableBlock + horizontal_rule),
	Heading = (P "*" ^ 1 / string.len)
		* P " " ^ 1
		* Ct(paragraph_segment)
		* line_ending
		/ function(...)
			local args = { ... }
			-- TODO: args[3] is attr. we can put id to header from here
			-- e.g. in markdown, `# heading 1` have id attr value `heading-1`
			return pandoc.Header(args[1], args[2], args[3])
		end,
	-- Quote = Ct(list_item(1, ">") ^ 1) / function ()
	-- 	pandoc.BlockQuote()
	-- end,
	-- HACK: paragraph_end should be ignored (for other 3 cases)
	Para = Ct(paragraph_segment * ((soft_break / pandoc.SoftBreak) * paragraph_segment) ^ 0)
		* paragraph_end ^ 0
		/ pandoc.Para,
	-- Para = Ct((paragraph_segment + soft_break / pandoc.SoftBreak) ^ 1)
	List = V "UnorderedList" + V "OrderedList",
	UnorderedList = Ct(list_item(1, "-") ^ 1) / pandoc.BulletList,
	OrderedList = Ct(list_item(1, "~") ^ 1) / pandoc.OrderedList,
	Space = whitespace ^ 1 / pandoc.Space,
	Styled = (
			attached_modifier("*") / pandoc.Strong      -- Bold
		+ attached_modifier("/") / pandoc.Emph        -- Italic
		+ attached_modifier("_") / pandoc.Underline   -- Underline
		+ attached_modifier("-") / pandoc.Strikeout   -- StrikeThrough
		-- TODO: Spoiler
		+ attached_modifier("^") / pandoc.Superscript -- Superscript
		+ attached_modifier(",") / pandoc.Subscript   -- Subscript
		-- TODO: InlineCode
		+ attached_modifier("%")                      -- NullModifier
		+ attached_modifier("$") / pandoc.Math  -- InlineMath
		-- TODO: Variable
	),
}

function Reader(input, _reader_options)
	return lpeg.match(G, tostring(input))
end
