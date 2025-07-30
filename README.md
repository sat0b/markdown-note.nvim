# markdown-note.nvim

A Neovim plugin that manages markdown notes with consistent date prefix filenames.

## How it works

This plugin automatically creates and manages notes with a consistent naming pattern:

```
~/Documents/notes/
├── daily/                      # Daily notes always go here
│   ├── 2025-07-27.md          # Created with :NoteToday (YYYY-MM-DD format)
│   ├── 2025-07-26.md
│   └── 2025-07-25.md
├── project-a/                  # Project directories in root
│   ├── 250727-kickoff-meeting.md
│   ├── 250726-architecture-design.md
│   └── 250725-requirements.md
├── project-b/
│   ├── 250727-api-design.md
│   └── 250726-database-schema.md
└── 250727-quick-memo.md        # Root level notes
```

Key features:
- All notes use `YYMMDD-` date prefix format
- Notes can be organized into directories at root level
- Renaming updates both the filename and the markdown title (# header)
- Built-in explorer with file management capabilities

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
- `:NoteQuick <title> [directory]` - Quick note creation
- `:NoteToday` - Open today's daily note (always creates in daily/ folder as YYYY-MM-DD.md)
- `:NoteRecent` - Open the most recently modified note

### Browsing Notes
- `:NoteList [directory]` - List notes
- `:NoteDirectories` - Browse directories
- `:NoteExplorer` - Toggle file explorer at bottom of screen

### Managing Notes
- `:NoteRename` - Rename current note (updates both filename and title)
- `:NoteDelete` - Delete current note (with confirmation)

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
    ["<leader>nr"] = { "<cmd>NoteRecent<cr>", "Recent note" },
    ["<leader>nl"] = { "<cmd>NoteList<cr>", "List all notes" },
    ["<leader>nD"] = { "<cmd>NoteDirectories<cr>", "Browse directories" },
    ["<leader>ne"] = { "<cmd>NoteExplorer<cr>", "Toggle note explorer" },
    ["<leader>nR"] = { "<cmd>NoteRename<cr>", "Rename current note" },
    ["<leader>nd"] = { "<cmd>NoteDelete<cr>", "Delete current note" },
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
vim.keymap.set("n", "<leader>nr", "<cmd>NoteRecent<cr>", { desc = "Recent note" })
vim.keymap.set("n", "<leader>nl", "<cmd>NoteList<cr>", { desc = "List notes" })
vim.keymap.set("n", "<leader>nD", "<cmd>NoteDirectories<cr>", { desc = "Browse directories" })
vim.keymap.set("n", "<leader>ne", "<cmd>NoteExplorer<cr>", { desc = "Toggle explorer" })
vim.keymap.set("n", "<leader>nR", "<cmd>NoteRename<cr>", { desc = "Rename note" })
vim.keymap.set("n", "<leader>nd", "<cmd>NoteDelete<cr>", { desc = "Delete current note" })
```

## Note Explorer

The Note Explorer provides a file tree view of your notes at the bottom of the screen with full mouse support. Use it to browse, search, and manage all your notes and directories.

### Explorer Keybindings

#### Navigation
- `Enter`, `o`, `l` - Open file or expand/collapse directory
- `h` - Collapse directory
- `q`, `Esc` - Close explorer

#### File Operations
- `a` - Create new note in current directory
- `d` - Delete selected items
- `r` - Rename file

#### Selection & Clipboard
- `Space` - Toggle selection
- `Ctrl-a` - Select all files
- `Ctrl-d` - Clear selection
- `c` - Copy selected items
- `x` - Cut selected items
- `p` - Paste items

#### Opening Files
- `Ctrl-x` - Open in horizontal split
- `Ctrl-v` - Open in vertical split
- `Ctrl-t` - Open in new tab

#### Search & Sort
- `/` - Start search
- `n` - Next match
- `N` - Previous match
- `s` - Toggle sort order (asc/desc)
- `S` - Toggle sort by (name/date)

#### Mouse Support
- **Left click** - Open file/directory
- **Double click** - Open file/directory
- **Right click** - Toggle selection

#### Other
- `R` - Refresh explorer
- `g?`, `H`, `?` - Toggle help

## Configuration

```lua
require("markdown-note").setup({
  -- Notes directory
  notes_dir = vim.fn.expand("~/Documents/notes"),
  
  -- Date prefix for note filenames
  date_prefix = "%y%m%d",
  
  -- Date prefix for daily notes (used by :NoteToday)
  daily_date_prefix = "%Y-%m-%d",
  
  -- Default title for new notes
  default_title = "note",
  
  -- Command to open notes (edit, split, vsplit, tabedit)
  open_cmd = "edit",
  
  -- Automatically insert title header in new notes
  auto_insert_title = true,
  
  -- Keep explorer open after opening a file
  explorer_close_on_open = false,
  
  -- Explorer sort options
  explorer_sort_order = "desc",  -- "asc" or "desc"
  explorer_sort_by = "name",     -- "name" or "date"
})
```

