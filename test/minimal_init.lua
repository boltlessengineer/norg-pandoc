local lazypath = vim.fn.stdpath "data" .. "/lazy"
vim.opt.rtp:append "."
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.opt.rtp:append(lazypath .. "/nvim-treesitter")
