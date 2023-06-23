local lpeg = require "lpeg"
-- stylua: ignore
local P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt =
	lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt

local pegdebug = require 'src.pegdebug'

local debug_mode = false

local function debug_wrapper(g)
	if debug_mode then
		return pegdebug.trace(g)
	end
	return g
end

local function choice(patt, ...)
	for _, p in pairs({...}) do
		patt = patt + p
	end
	return patt
end

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

local function attached_modifier(punc_char, verbatim)
	local punc = P(punc_char)
	local non_whitespace_char = wordchar + punctuation

	local modi_start = (#-B(wordchar) * punc * #non_whitespace_char)
	local free_modi_start = (#-B(wordchar) * punc * P "|")
	local modi_end = B(non_whitespace_char) * punc * -wordchar
	local free_modi_end = P "|" * punc * -wordchar

	local non_repeat_eol = (line_ending - line_ending ^ 2)
	-- HACK: don't know reason why... but parsing is too slow without this empty lazy capture
	local hack = Cmt(P(true), function() return true end)
	local inner_capture = Ct(choice(
		-- FIX: */italic *ignore*/ bold*
		-- */italic *ignore/ bold*
		(#(punctuation * -punc) * hack * (V "Styled")),
		(wordchar + escape_sequence + (#-modi_end * punctuation)) ^ 1 / pandoc.Str,
		whitespace / pandoc.Space,
		non_repeat_eol / pandoc.SoftBreak
	) ^ 1)
	local free_inner_capture = Ct(choice(
		(wordchar + (#-free_modi_end * punctuation)) ^ 1 / pandoc.Str,
		whitespace / pandoc.Space,
		non_repeat_eol / pandoc.LineBreak
	) ^ 1)
	if verbatim then
		free_inner_capture = C(choice(
			(wordchar + (#-free_modi_end * punctuation)) ^ 1,
			whitespace,
			non_repeat_eol
		) ^ 1)
		inner_capture = C(choice(
			(wordchar + escape_sequence + (#-modi_end * punctuation)) ^ 1,
			whitespace,
			non_repeat_eol
		) ^ 1)
	end
	return
		free_modi_start * free_inner_capture * free_modi_end
		+
		modi_start * inner_capture * modi_end
end

-- stylua: ignore
local paragraph_segment =
		choice(
			V "Styled",
			(wordchar + escape_sequence) ^ 1 / pandoc.Str,
			punctuation / pandoc.Str,
		  whitespace / pandoc.Space
		) ^ 1 / function (...)
			return ...
		end

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

Grammar = (debug_wrapper {
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
			V "Bold"
		+ V "Italic"
		+ V "Underline"
		+ V "StrikeThrough"
		+ V "Spoiler"
		+ V "Superscript"
		+ V "Subscript"
		+ V "InlineCode"
		+ V "NullModifier"
		+ V "InlineMath"
		+ V "Variable"
	),
	Bold = attached_modifier("*") / pandoc.Strong,
	Italic = attached_modifier("/") / pandoc.Emph,
	Underline = attached_modifier("_") / pandoc.Underline,
	StrikeThrough = attached_modifier("-") / pandoc.Strikeout,
	-- TODO: add class for Span
	Spoiler = attached_modifier("!") / function (inline)
		return pandoc.Span(inline, { class = "spoiler" })
	end,
	Superscript = attached_modifier("^") / pandoc.Superscript,
	Subscript = attached_modifier(",") / pandoc.Subscript,
	InlineCode = attached_modifier("`", true) / pandoc.Code,
	NullModifier = attached_modifier("%") / function () return nil end,
	InlineMath = attached_modifier("$", true) / function (text) return pandoc.Math("InlineMath", text) end,
	Variable = attached_modifier("&", true) / pandoc.Str
})
G = P(Grammar)

function Reader(input, _reader_options)
	print(pandoc.Strong("asdf"))
	print(pandoc.Code("asdf"))
	print("============[INPUT:]============")
	print(input)
	if debug_mode then
		print("============[DEBUG:]============")
	end
	local match = lpeg.match(G, tostring(input))
	print("============[RESULT]============")
	return match
end
