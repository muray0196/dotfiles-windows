-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape insert mode" })
vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard", silent = true })
vim.keymap.set("n", "<C-a>", "ggVG", { desc = "Select all", silent = true })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { desc = "Select all from insert", silent = true })