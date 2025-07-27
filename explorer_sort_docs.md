# Explorer Sort Configuration

Add these options to your setup:

```lua
require('markdown-note').setup({
  notes_dir = "~/notes",
  
  -- Explorer sort options
  explorer_sort_order = "desc",  -- "asc" or "desc" (default: "desc")
  explorer_sort_by = "name",     -- "name" or "date" (default: "name")
  
  -- Other options...
})
```

## Keyboard shortcuts in explorer:
- `s` - Toggle sort order between ascending and descending
- `S` - Toggle sort by name or date

## Features:
- Default sort order is descending (newest/Z-A first)
- Can sort by filename or modification date
- Settings persist during the session
- Can be configured via setup options