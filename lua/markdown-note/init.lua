local M = {}

M.config = {
  notes_dir = vim.fn.expand("~/Documents/notes"),
  date_prefix = "%y%m%d",
  daily_date_prefix = "%Y-%m-%d",
  default_title = "note",
  default_project = nil,
  open_cmd = "edit",
  auto_insert_title = true,
  explorer_close_on_open = false,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Ensure notes directory exists
  vim.fn.mkdir(vim.fn.expand(M.config.notes_dir), "p")
  
  -- Load modules
  require("markdown-note.commands").setup(M.config)
  require("markdown-note.explorer").setup(M.config)
  
  -- Mark as setup
  vim.g.markdown_note_setup_called = true
end

return M