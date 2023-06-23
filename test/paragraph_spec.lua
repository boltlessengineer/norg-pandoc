local eq = assert.are.same

require "init"

-- TODO: replace with luaunit?
-- or make my own?

insulate("paragarph", function()
    insulate("Attached Modifiers", function()
        grammar[1] = "ParaSeg"
        local p = P(grammar)
        local t = require "token"
        it("Bold words", function()
            local text = "A *bold* word"
            eq(p:match(text), t.para_seg { t.str "A", t.space " ", t.bold { t.str "bold" }, t.space " ", t.str "word" })
        end)
        it("Bold text", function()
            local text = "*Bold text*"
            eq(p:match(text), t.para_seg { t.bold { t.str "Bold", t.space " ", t.str "text" } })
        end)
        it("Bold text with comma and period", function()
            local text = ".*Bold text*,"
            eq(p:match(text), t.para_seg { t.str ".", t.bold { t.str "Bold", t.space " ", t.str "text" }, t.str "," })
        end)
        it("Bold text with newline inside", function()
            local text = "*Bold\ntext*"
            eq(p:match(text), t.para_seg { t.bold { t.str "Bold", t.soft_break "\n", t.str "text" } })
        end)
        it("Bold and italic text", function()
            local text = "*/Bold italic/*"
            eq(p:match(text), t.para_seg { t.bold { t.italic { t.str "Bold", t.space " ", t.str "italic" } } })
        end)
        it("Bold and partly italic text", function()
            local text = "*/Bold italic/ only bold*"
            eq(
                p:match(text),
                t.para_seg {
                    t.bold {
                        t.italic { t.str "Bold", t.space " ", t.str "italic" },
                        t.space " ",
                        t.str "only",
                        t.space " ",
                        t.str "bold",
                    },
                }
            )
        end)
        it("Text with different markup types", function()
            local text = "Text */with/ _different_ ^markup^ !types!*"
            eq(
                p:match(text),
                t.para_seg {
                    t.str "Text",
                    t.space " ",
                    t.bold {
                        t.italic { t.str "with" },
                        t.space " ",
                        t.underline { t.str "different" },
                        t.space " ",
                        t.superscript { t.str "markup" },
                        t.space " ",
                        t.spoiler { t.str "types" },
                    },
                }
            )
        end)
        it("Ignore bold inside italic inside bold", function()
            local text = "*/*ignore* italic/ bold*"
            eq(
                p:match(text),
                t.para_seg {
                    t.bold {
                        t.italic {
                            t.punc "*",
                            t.str "ignore",
                            t.punc "*",
                            t.space " ",
                            t.str "italic",
                        },
                        t.space " ",
                        t.str "bold",
                    },
                }
            )
        end)
    end)
end)
