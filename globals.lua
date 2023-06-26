_G.lpeg = require "lpeg"
-- stylua: ignore
P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt, Cp =
    lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt, lpeg.Cp

local inspect = require "src.inspect"

function _G.choice(patts)
    local patt = patts[1]
    for i = 2, #patts do
        patt = patt + patts[i]
    end
    return patt
end

---empty pattern to do something when pattern is matched
---@param callback fun(str,num,...):any
---@return any
function _G.empty_pat(callback)
    return Cmt(P(true), function(s, n, ...)
        local r = callback(s, n, ...)
        return r ~= nil and r or true
    end)
end

function _G.print_cap(...)
    for key, value in pairs { ... } do
        print(key)
        print(inspect(value))
    end
    print(...)
    return ...
end

_G.whitespace = S " \t"
_G.line_ending = P "\r" ^ -1 * P "\n"
_G.line_ending_ch = S "\r\n"
_G.punctuation = S [[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]]

_G.wordchar = (1 - (whitespace + line_ending + punctuation))

_G.escape_sequence = Cs((P [[\]] / "") * P(1))
