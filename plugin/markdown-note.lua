if vim.g.loaded_markdown_note then
  return
end

vim.g.loaded_markdown_note = true

-- Autoload setup if user hasn't called it
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if not vim.g.markdown_note_setup_called then
      require("markdown-note").setup()
    end
  end,
})

-- Track if setup was called
local original_setup = require("markdown-note").setup
require("markdown-note").setup = function(opts)
  vim.g.markdown_note_setup_called = true
  return original_setup(opts)
end