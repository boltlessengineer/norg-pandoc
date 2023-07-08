-- change order, expected output goes second
local function eq(pass, expect) return assert.are.same(expect, pass) end
assert:add_formatter(
    function(val) return require("src.debug_print").pretty_table(val) end
)

require "init"
local p_doc = P(grammar)
grammar[1] = "ParaSeg"
local p = P(grammar)
local t = require "token"

describe("Attached Modifiers >", function()
    it("Bold words", function()
        local text = "A *bold* word"
        eq(
            p:match(text),
            t.para_seg {
                t.str "A",
                t.space(),
                t.bold { t.para_seg { t.str "bold" } },
                t.space(),
                t.str "word",
            }
        )
    end)
    it("Bold text", function()
        local text = "*Bold text*"
        eq(
            p:match(text),
            t.para_seg {
                t.bold { t.para_seg { t.str "Bold", t.space(), t.str "text" } },
            }
        )
    end)
    it("Bold text with comma and period", function()
        local text = ".*Bold text*,"
        eq(
            p:match(text),
            t.para_seg {
                t.punc ".",
                t.bold { t.para_seg { t.str "Bold", t.space(), t.str "text" } },
                t.punc ",",
            }
        )
    end)
    it("Bold text with newline inside", function()
        local text = "*Bold\ntext*"
        eq(
            p:match(text),
            t.para_seg {
                t.bold {
                    t.para_seg { t.str "Bold" },
                    t.soft_break(),
                    t.para_seg { t.str "text" },
                },
            }
        )
    end)
    it("Bold and italic text", function()
        local text = "*/Bold italic/*"
        eq(
            p:match(text),
            t.para_seg {
                t.bold {
                    t.para_seg {
                        t.italic {
                            t.para_seg {
                                t.str "Bold",
                                t.space(),
                                t.str "italic",
                            },
                        },
                    },
                },
            }
        )
    end)
    it("Bold and partly italic text", function()
        local text = "*/Bold italic/ only bold*"
        eq(
            p:match(text),
            t.para_seg {
                t.bold {
                    t.para_seg {
                        t.italic {
                            t.para_seg {
                                t.str "Bold",
                                t.space(),
                                t.str "italic",
                            },
                        },
                        t.space(),
                        t.str "only",
                        t.space(),
                        t.str "bold",
                    },
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
                t.space(),
                t.bold {
                    t.para_seg {
                        t.italic { t.para_seg { t.str "with" } },
                        t.space(),
                        t.underline { t.para_seg { t.str "different" } },
                        t.space(),
                        t.superscript { t.para_seg { t.str "markup" } },
                        t.space(),
                        t.spoiler { t.para_seg { t.str "types" } },
                    },
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
                    t.para_seg {
                        t.italic {
                            t.para_seg {
                                t.punc "*",
                                t.str "ignore",
                                t.punc "*",
                                t.space(),
                                t.str "italic",
                            },
                        },
                        t.space(),
                        t.str "bold",
                    },
                },
            }
        )
    end)
    it("Ignore multiple whitespaces inside bold", function()
        local text = [[
*bold   
    text*
        ]]
        eq(
            p:match(text),
            t.para_seg {
                t.bold {
                    t.para_seg { t.str "bold" },
                    t.soft_break(),
                    t.para_seg { t.str "text" },
                },
            }
        )
    end)
    it("Can have only paragraph segments, not paragraphs", function()
        local text = [[
*bold

text*
        ]]
        eq(
            p:match(text),
            t.para_seg {
                t.punc "*",
                t.str "bold",
            }
        )
    end)
    it("Link Modifier", function()
        local text = [[
Intra:*word*:bold
]]
        eq(
            p:match(text),
            t.para_seg {
                t.str "Intra",
                t.bold { t.para_seg { t.str "word" } },
                t.str "bold",
            }
        )
    end)
    it("Repeated modifiers is treated as raw text", function()
        local text = "*///example//*"
        eq(
            p:match(text),
            t.para_seg {
                t.bold {
                    t.para_seg {
                        t.punc "/",
                        t.punc "/",
                        t.punc "/",
                        t.str "example",
                        t.punc "/",
                        t.punc "/",
                    },
                },
            }
        )
    end)
    it("Reset after detached modifier", function()
        local text = [[
- _:
- _x_
]]
        eq(
            p_doc:match(text),
            t.pandoc {
                t.bullet_list {
                    { t.para { t.para_seg { t.punc "_", t.punc ":" } } },
                    {
                        t.para {
                            t.para_seg {
                                t.underline { t.para_seg { t.str "x" } },
                            },
                        },
                    },
                },
            }
        )
    end)
    it("Precedence between linkables (1)", function()
        local text = "{google.com}[not *bold]*]"
        eq(
            p:match(text),
            t.para_seg {
                t.link({
                    t.para_seg {
                        t.str "not",
                        t.space(),
                        t.punc "*",
                        t.str "bold",
                    },
                }, "google.com"),
                t.punc "*",
                t.punc "]",
            }
        )
    end)
    it("Precedence between linkables (2)", function()
        local text = "{google.com}[is *bold ]*]"
        eq(
            p:match(text),
            t.para_seg {
                t.link({
                    t.para_seg {
                        t.str "is",
                        t.space(),
                        t.bold {
                            t.para_seg {
                                t.str "bold",
                                t.space(),
                                t.punc "]",
                            },
                        },
                    },
                }, "google.com"),
            }
        )
    end)
    it("Precedence between linkables (verbatim)", function()
        local text = "{google.com}[not `code]`]"
        eq(
            p:match(text),
            t.para_seg {
                t.link({
                    t.para_seg {
                        t.str "not",
                        t.space(),
                        t.punc "`",
                        t.str "code",
                    },
                }, "google.com"),
                t.punc "`",
                t.punc "]",
            }
        )
    end)
end)
