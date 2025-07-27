local M = {}

M.config = {
  notes_dir = vim.fn.expand("~/Documents/notes"),
  date_format = "%Y-%m-%d",
  default_title = "note",
  default_project = nil,
  open_cmd = "edit",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Ensure notes directory exists
  vim.fn.mkdir(M.config.notes_dir, "p")
  
  -- Load modules
  require("markdown-note.commands").setup(M.config)
end

return M