_G.lpeg = require "lpeg"
P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt =
	lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt

function _G.choice(patt, ...)
	for _, p in pairs({...}) do
		patt = patt + p
	end
	return patt
end

_G.whitespace = S " \t"
_G.line_ending = P "\r" ^ -1 * P "\n"
_G.punctuation = S [[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]]

_G.wordchar = (1 - (whitespace + line_ending + punctuation))

_G.escape_sequence = Cs((P [[\]] / "") * P(1))
