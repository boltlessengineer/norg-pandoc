_G.lpeg = require "lpeg"
-- stylua: ignore
P, S, R, Cf, Cc, Ct, V, Cs, Cg, Cb, B, C, Cmt, Cp =
    lpeg.P, lpeg.S, lpeg.R, lpeg.Cf, lpeg.Cc, lpeg.Ct, lpeg.V, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.B, lpeg.C, lpeg.Cmt, lpeg.Cp

_G.inspect = require "src.inspect"

function _G.pretty_print(...) print(inspect(...)) end

function _G.list_contains(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

function _G.flatten_table(tbl)
    local res = {}
    for _, val in ipairs(tbl) do
        if type(val) == "table" and not val.t then
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

function _G.choice(patts)
    local patt = patts[1]
    for i = 2, #patts do
        patt = patt + patts[i]
    end
    return patt
end

function _G.seq(patts)
    local patt = patts[1]
    for i = 2, #patts do
        patt = patt * patts[i]
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

---All captures made by patt, if patt don't have captures, return nil
---useful when collecting multiple captures
function Cnil(patt)
    return C(patt) / function(_raw, cap) return cap end
end

function _G.print_cap(...)
    for _, value in pairs { ... } do
        print(inspect(value))
    end
    return ...
end

function _G.make_id_from_str(str)
    local replace_space = lpeg.S " \t\r\n" ^ 1 / "-"
    local p = whitespace ^ 0
        * Cs(choice {
            punctuation / "",
            replace_space,
            lpeg.P(1) / string.lower,
        } ^ 1)
        * whitespace ^ 0
    return p:match(str)
end

_G.whitespace = S " \t"
_G.line_ending = P "\r" ^ -1 * P "\n"
_G.line_ending_ch = S "\r\n"
_G.punctuation = S [[!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]]

_G.wordchar = (1 - (whitespace + line_ending + punctuation))

_G.escape_sequence = Cs((P [[\]] / "") * P(1))
