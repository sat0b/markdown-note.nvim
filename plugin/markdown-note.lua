if vim.g.loaded_markdown_note then
  return
end

vim.g.loaded_markdown_note = true

-- Immediately setup with defaults if not already done
if not vim.g.markdown_note_setup_called then
  require("markdown-note").setup()
end