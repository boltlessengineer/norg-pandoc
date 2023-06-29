# norg-pandoc

Custom pandoc reader for [Norg
format](#h-tpsgithubcomnvimneorgnorgspecs). It will be able to transfrom
.norg files to the [pandoc](#h-tpsgithubcomjgmpandoc) AST.

## why?

There is already a [haskell
parser](#h-tpsgithubcomSimre1neorghaskellparser) that tried to implement
a native pandoc reader, but the project is stalled. Haskell is good
language to make custom parser, but there aren't many people who can use
it.

Many of Neorg's features are already written in Lua, and pandoc has
built-in support for Lua custom parsers. This project is started to
provide full pandoc support as soon as possible.

## Parser Implementation State

You can see detailed current state in [todo.norg](#h-todonorg)

## Contributing

All contributions are welcome!

You can test with [busted](#h-tpsgithubcomlunarmodulesbusted) or
[neotest-plenary](#h-tpsgithubcomnvimneotestneotestplenary) before
making a PR.

All test files should be named like: `test/*_spec.lua`.
