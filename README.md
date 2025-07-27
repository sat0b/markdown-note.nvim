# markdown-note.nvim

A simple Neovim plugin for managing markdown notes with project-based organization.

## Installation

Using lazy.nvim:
```lua
{
  "sat0b/markdown-note.nvim",
  event = "VeryLazy",
  config = function()
    require("markdown-note").setup()
  end
}
```

## Commands

### Creating Notes
- `:NoteNew` - Create a new note
- `:NoteQuick <title> [project]` - Quick note creation
- `:NoteToday` - Open today's daily note (uses default project)

### Browsing Notes
- `:NoteList [project]` - List notes
- `:NoteProjects` - Browse projects
- `:NoteFindFile` - Find notes with Telescope
- `:NoteGrep` - Search note contents with Telescope

### Managing Notes
- `:NoteRename` - Rename current note (updates both filename and title)
- `:NoteDelete` - Delete current note (with confirmation)
- `:NoteDeleteMulti` - Delete multiple notes (Tab to select, Enter to confirm)
- `:NoteSetDefault <project>` - Set default project

## Keybindings

### For NvChad users

Add this to your `~/.config/nvim/lua/mappings.lua`:

```lua
local M = {}

M.notes = {
  n = {
    ["<leader>nn"] = { "<cmd>NoteNew<cr>", "Create new note" },
    ["<leader>nq"] = { ":NoteQuick ", "Quick note (enter title)" },
    ["<leader>nt"] = { "<cmd>NoteToday<cr>", "Today's note" },
    ["<leader>nl"] = { "<cmd>NoteList<cr>", "List all notes" },
    ["<leader>np"] = { "<cmd>NoteProjects<cr>", "Browse projects" },
    ["<leader>nf"] = { "<cmd>NoteFindFile<cr>", "Find note files" },
    ["<leader>ng"] = { "<cmd>NoteGrep<cr>", "Search in notes" },
    ["<leader>nr"] = { "<cmd>NoteRename<cr>", "Rename current note" },
    ["<leader>nd"] = { "<cmd>NoteDelete<cr>", "Delete current note" },
    ["<leader>nD"] = { "<cmd>NoteDeleteMulti<cr>", "Delete multiple notes" },
  }
}

return M
```

### For standard Neovim configuration

```lua
-- Note keybindings
vim.keymap.set("n", "<leader>nn", "<cmd>NoteNew<cr>", { desc = "Create new note" })
vim.keymap.set("n", "<leader>nq", ":NoteQuick ", { desc = "Quick note" })
vim.keymap.set("n", "<leader>nt", "<cmd>NoteToday<cr>", { desc = "Today's note" })
vim.keymap.set("n", "<leader>nl", "<cmd>NoteList<cr>", { desc = "List notes" })
vim.keymap.set("n", "<leader>np", "<cmd>NoteProjects<cr>", { desc = "Browse projects" })
vim.keymap.set("n", "<leader>nf", "<cmd>NoteFindFile<cr>", { desc = "Find notes" })
vim.keymap.set("n", "<leader>ng", "<cmd>NoteGrep<cr>", { desc = "Search in notes" })
vim.keymap.set("n", "<leader>nr", "<cmd>NoteRename<cr>", { desc = "Rename note" })
vim.keymap.set("n", "<leader>nd", "<cmd>NoteDelete<cr>", { desc = "Delete current note" })
vim.keymap.set("n", "<leader>nD", "<cmd>NoteDeleteMulti<cr>", { desc = "Delete multiple notes" })
```

