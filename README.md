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

- `:NoteNew` - Create a new note
- `:NoteQuick <title> [project]` - Quick note creation
- `:NoteToday` - Create today's note
- `:NoteList [project]` - List notes
- `:NoteFindFile` - Find notes with Telescope
- `:NoteGrep` - Search note contents with Telescope