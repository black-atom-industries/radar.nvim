local root = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2) .. "/../../../..")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(vim.fn.expand("~/repos/black-atom-industries/black-atom/adapters/nvim"))
vim.o.termguicolors = true
vim.o.number = true
vim.o.laststatus = 3
vim.o.winbar = " %f"
vim.o.showmode = false
vim.o.cmdheight = 1
vim.o.swapfile = false
vim.o.shada = ""
vim.g.black_atom_core_config = { styles = { transparency = "none", syntax = { comments = { italic = false } } } }
pcall(vim.cmd.colorscheme, "black-atom-minium-polymer-light")
require("radar").setup()
