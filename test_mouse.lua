-- Test script for mouse functionality in markdown-note explorer
-- Run this in Neovim with :luafile test_mouse.lua

-- Load the plugin
require('markdown-note').setup({
  notes_dir = vim.fn.expand("~/notes"),
  explorer_close_on_open = false,
})

-- Open the explorer
require('markdown-note.explorer').open()

print("Explorer opened. You can now:")
print("- Left click on files/directories to open them")
print("- Double click also works to open files/directories")  
print("- Right click to toggle selection of items")
print("- Mouse should work for navigating the explorer")