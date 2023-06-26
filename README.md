# norg-pandoc

Custom pandoc reader for [Norg
format](https://github.com/nvim-neorg/norg-specs). It will be able to
transfrom .norg files to the [pandoc](https://github.com/jgm/pandoc)
AST.

## why?

There is already a [haskell
parser](https://github.com/Simre1/neorg-haskell-parser) that tried to
implement a native pandoc reader, but the project is stalled. Haskell is
good language to make custom parser, but there aren't many people who
can use it.

Many of Neorg's features are already written in Lua, and pandoc has
built-in support for Lua custom parsers. This project is started to
provide full pandoc support as soon as possible.

## Parser Implementation State

You can see detailed current state in [todo.norg](./blob/main/todo.norg)

## Contributing

All contributions are welcome!

You can test with [busted](https://github.com/lunarmodules/busted) or
[neotest-plenary](https://github.com/nvim-neotest/neotest-plenary)
before making a PR.

All test files should be named like: `test/*_spec.lua`.