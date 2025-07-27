local M = {}

local explorer_buf = nil
local explorer_win = nil
local config = {}
local current_path = nil
local entries = {}

-- State management
local selected_entries = {}
local clipboard = {
  entries = {},
  action = nil -- "copy" or "cut"
}
local search_term = ""
local search_active = false
local search_matches = {}
local current_match_index = 0

local function get_icon(entry)
  if entry.type == "directory" then
    return entry.expanded and "▼ " or "▶ "
  else
    return "  "
  end
end

local function get_selection_mark(entry)
  return selected_entries[entry.path] and "* " or "  "
end

local function build_tree(path, prefix, expanded_dirs)
  local tree = {}
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  -- Get entries
  local files = {}
  local dirs = {}
  
  local handle = vim.loop.fs_scandir(path)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      
      if type == "directory" then
        table.insert(dirs, name)
      elseif type == "file" and name:match("%.md$") then
        table.insert(files, name)
      end
    end
  end
  
  -- Sort
  table.sort(dirs)
  table.sort(files)
  
  -- Add directories first
  for _, name in ipairs(dirs) do
    local full_path = path .. "/" .. name
    local relative_path = full_path:sub(#notes_dir + 2)
    local entry = {
      name = name,
      path = full_path,
      relative_path = relative_path,
      type = "directory",
      expanded = expanded_dirs[relative_path] or false,
      prefix = prefix
    }
    table.insert(tree, entry)
    
    -- Add subdirectories if expanded
    if entry.expanded then
      local subtree = build_tree(full_path, prefix .. "  ", expanded_dirs)
      for _, subentry in ipairs(subtree) do
        table.insert(tree, subentry)
      end
    end
  end
  
  -- Add files
  for _, name in ipairs(files) do
    local full_path = path .. "/" .. name
    local relative_path = full_path:sub(#notes_dir + 2)
    table.insert(tree, {
      name = name,
      path = full_path,
      relative_path = relative_path,
      type = "file",
      prefix = prefix
    })
  end
  
  return tree
end

local function refresh_explorer()
  if not explorer_buf or not vim.api.nvim_buf_is_valid(explorer_buf) then
    return
  end
  
  local lines = {}
  
  if show_help_mode then
    -- Show help content
    lines = get_help_lines()
  else
    -- Show file tree
    local notes_dir = vim.fn.expand(config.notes_dir)
    local expanded_dirs = {}
    
    -- Preserve expanded state
    for _, entry in ipairs(entries) do
      if entry.type == "directory" and entry.expanded then
        expanded_dirs[entry.relative_path] = true
      end
    end
    
    entries = build_tree(notes_dir, "", expanded_dirs)
    
    -- Build display lines
    for _, entry in ipairs(entries) do
      local icon = get_icon(entry)
      local selection = get_selection_mark(entry)
      local line = entry.prefix .. selection .. icon .. entry.name
      
      -- Add clipboard indicator
      if clipboard.action and vim.tbl_contains(clipboard.entries, entry.path) then
        line = line .. " [" .. clipboard.action:sub(1,1):upper() .. "]"
      end
      
      table.insert(lines, line)
    end
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(explorer_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', false)
  
  -- Update search matches if active and not in help mode
  if not show_help_mode and search_active and search_term ~= "" then
    update_search_matches()
  end
end

local function toggle_directory()
  if show_help_mode then return end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  
  if entry and entry.type == "directory" then
    entry.expanded = not entry.expanded
    refresh_explorer()
    vim.api.nvim_win_set_cursor(0, {row, 0})
  end
end

local function open_note(cmd)
  if show_help_mode then return end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  
  if entry then
    if entry.type == "file" then
      -- Save current window
      local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
      
      -- Close explorer if configured
      if config.explorer_close_on_open then
        M.close()
      else
        -- Go to previous window
        vim.api.nvim_set_current_win(prev_win)
      end
      
      -- Open file with specified command
      vim.cmd((cmd or config.open_cmd) .. " " .. vim.fn.fnameescape(entry.path))
    elseif entry.type == "directory" then
      toggle_directory()
    end
  end
end

-- Selection functions
local function toggle_selection()
  if show_help_mode then return end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  
  if entry then
    if selected_entries[entry.path] then
      selected_entries[entry.path] = nil
    else
      selected_entries[entry.path] = true
    end
    refresh_explorer()
    
    -- Move to next line
    if row < #entries then
      vim.api.nvim_win_set_cursor(0, {row + 1, 0})
    end
  end
end

local function select_all()
  if show_help_mode then return end
  
  for _, entry in ipairs(entries) do
    if entry.type == "file" then
      selected_entries[entry.path] = true
    end
  end
  refresh_explorer()
end

local function clear_selection()
  if show_help_mode then return end
  
  selected_entries = {}
  refresh_explorer()
end

local function get_selected_or_current()
  local selected = {}
  for path, _ in pairs(selected_entries) do
    table.insert(selected, path)
  end
  
  if #selected == 0 then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local entry = entries[row]
    if entry then
      table.insert(selected, entry.path)
    end
  end
  
  return selected
end

-- Clipboard functions
local function copy_entries()
  if show_help_mode then return end
  
  local selected = get_selected_or_current()
  if #selected > 0 then
    clipboard.entries = selected
    clipboard.action = "copy"
    vim.notify(string.format("Copied %d item(s)", #selected))
    clear_selection()
  end
end

local function cut_entries()
  if show_help_mode then return end
  
  local selected = get_selected_or_current()
  if #selected > 0 then
    clipboard.entries = selected
    clipboard.action = "cut"
    vim.notify(string.format("Cut %d item(s)", #selected))
    clear_selection()
  end
end

local function paste_entries()
  if show_help_mode then return end
  
  if #clipboard.entries == 0 then
    vim.notify("Nothing to paste")
    return
  end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  local target_dir
  
  if entry then
    if entry.type == "directory" then
      target_dir = entry.path
    else
      target_dir = vim.fn.fnamemodify(entry.path, ":h")
    end
  else
    target_dir = vim.fn.expand(config.notes_dir)
  end
  
  local success_count = 0
  for _, source_path in ipairs(clipboard.entries) do
    local filename = vim.fn.fnamemodify(source_path, ":t")
    local target_path = target_dir .. "/" .. filename
    
    -- Check if target exists
    if vim.fn.filereadable(target_path) == 1 or vim.fn.isdirectory(target_path) == 1 then
      local new_name = vim.fn.input(string.format("'%s' already exists. New name (empty to skip): ", filename), filename)
      if new_name == "" then
        goto continue
      end
      target_path = target_dir .. "/" .. new_name
    end
    
    local ok = false
    if clipboard.action == "copy" then
      if vim.fn.isdirectory(source_path) == 1 then
        -- Copy directory
        ok = vim.fn.system(string.format("cp -r %s %s", vim.fn.shellescape(source_path), vim.fn.shellescape(target_path))) == ""
      else
        -- Copy file
        ok = vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(source_path), vim.fn.shellescape(target_path))) == ""
      end
    elseif clipboard.action == "cut" then
      -- Move file or directory
      ok = os.rename(source_path, target_path)
    end
    
    if ok then
      success_count = success_count + 1
    end
    
    ::continue::
  end
  
  if clipboard.action == "cut" and success_count > 0 then
    clipboard.entries = {}
    clipboard.action = nil
  end
  
  vim.notify(string.format("Pasted %d/%d item(s)", success_count, #clipboard.entries))
  refresh_explorer()
end

-- File operations
local function create_note()
  if show_help_mode then return end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  local target_dir
  
  if entry then
    if entry.type == "directory" then
      target_dir = entry.path
    else
      target_dir = vim.fn.fnamemodify(entry.path, ":h")
    end
  else
    target_dir = vim.fn.expand(config.notes_dir)
  end
  
  vim.ui.input({
    prompt = "Note title: ",
  }, function(title)
    if title then
      local utils = require("markdown-note.utils")
      local date = utils.get_date_string(config)
      local filename = string.format("%s-%s.md", date, title)
      local filepath = target_dir .. "/" .. filename
      
      -- Check if file exists
      if vim.fn.filereadable(filepath) == 1 then
        vim.notify("Note already exists: " .. filename, vim.log.levels.ERROR)
        return
      end
      
      -- Create and open file
      local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
      if not config.explorer_close_on_open then
        vim.api.nvim_set_current_win(prev_win)
      end
      
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      
      -- Insert title if auto_insert_title is enabled
      if config.auto_insert_title then
        local lines = {"# " .. title, "", ""}
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, {3, 0})
      end
      
      if config.explorer_close_on_open then
        M.close()
      else
        refresh_explorer()
      end
    end
  end)
end

local function delete_entries()
  if show_help_mode then return end
  
  local selected = get_selected_or_current()
  if #selected == 0 then
    return
  end
  
  local prompt
  if #selected == 1 then
    local name = vim.fn.fnamemodify(selected[1], ":t")
    prompt = string.format("Delete '%s'?", name)
  else
    prompt = string.format("Delete %d items?", #selected)
  end
  
  vim.ui.select({"No", "Yes"}, {
    prompt = prompt,
  }, function(choice)
    if choice == "Yes" then
      local deleted = 0
      for _, path in ipairs(selected) do
        local ok = false
        if vim.fn.isdirectory(path) == 1 then
          -- Delete directory
          ok = vim.fn.system(string.format("rm -rf %s", vim.fn.shellescape(path))) == ""
        else
          -- Delete file
          ok = os.remove(path)
          
          -- Close buffer if open
          local bufnr = vim.fn.bufnr(path)
          if bufnr ~= -1 then
            vim.cmd("bdelete! " .. bufnr)
          end
        end
        
        if ok then
          deleted = deleted + 1
        end
      end
      
      vim.notify(string.format("Deleted %d/%d items", deleted, #selected))
      clear_selection()
      refresh_explorer()
    end
  end)
end

local function rename_entry()
  if show_help_mode then return end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  
  if not entry then
    return
  end
  
  if entry.type == "directory" then
    vim.notify("Directory rename not supported", vim.log.levels.ERROR)
    return
  end
  
  -- Extract current title from filename
  local filename = vim.fn.fnamemodify(entry.path, ":t:r")
  local date_pattern = "^%d%d%d%d%-%d%d%-%d%d%-"
  local current_title = filename:gsub(date_pattern, "")
  
  vim.ui.input({
    prompt = "New title: ",
    default = current_title,
  }, function(new_title)
    if not new_title or new_title == "" or new_title == current_title then
      return
    end
    
    -- Get the date part from current filename
    local date = filename:match(date_pattern) or (require("markdown-note.utils").get_date_string(config) .. "-")
    date = date:sub(1, -2)  -- Remove trailing dash
    
    -- Construct new path
    local dir = vim.fn.fnamemodify(entry.path, ":h")
    local new_filename = date .. "-" .. new_title .. ".md"
    local new_path = dir .. "/" .. new_filename
    
    -- Check if new file already exists
    if vim.fn.filereadable(new_path) == 1 then
      vim.notify("File already exists: " .. new_filename, vim.log.levels.ERROR)
      return
    end
    
    -- Check if file is open in buffer
    local bufnr = vim.fn.bufnr(entry.path)
    if bufnr ~= -1 then
      -- Update title in buffer if auto_insert_title is enabled
      if config.auto_insert_title then
        vim.cmd("buffer " .. bufnr)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if #lines > 0 and lines[1]:match("^# ") then
          lines[1] = "# " .. new_title
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end
        vim.cmd("write")
      end
    end
    
    -- Rename the file
    local ok = os.rename(entry.path, new_path)
    if ok then
      -- Update buffer name if open
      if bufnr ~= -1 then
        vim.api.nvim_buf_set_name(bufnr, new_path)
      end
      
      vim.notify("Renamed to: " .. new_filename)
      refresh_explorer()
    else
      vim.notify("Failed to rename file", vim.log.levels.ERROR)
    end
  end)
end

-- Search functions
local function update_search_matches()
  search_matches = {}
  if search_term == "" then
    return
  end
  
  local search_lower = search_term:lower()
  for i, entry in ipairs(entries) do
    if entry.name:lower():find(search_lower, 1, true) then
      table.insert(search_matches, i)
    end
  end
end

local function start_search()
  if show_help_mode then return end
  
  vim.ui.input({
    prompt = "Search: ",
    default = search_term,
  }, function(term)
    if term then
      search_term = term
      search_active = true
      current_match_index = 0
      update_search_matches()
      
      if #search_matches > 0 then
        current_match_index = 1
        vim.api.nvim_win_set_cursor(0, {search_matches[1], 0})
      else
        vim.notify("No matches found")
      end
    end
  end)
end

local function next_match()
  if not search_active or #search_matches == 0 then
    return
  end
  
  current_match_index = current_match_index + 1
  if current_match_index > #search_matches then
    current_match_index = 1
  end
  
  vim.api.nvim_win_set_cursor(0, {search_matches[current_match_index], 0})
end

local function prev_match()
  if not search_active or #search_matches == 0 then
    return
  end
  
  current_match_index = current_match_index - 1
  if current_match_index < 1 then
    current_match_index = #search_matches
  end
  
  vim.api.nvim_win_set_cursor(0, {search_matches[current_match_index], 0})
end

local function clear_search()
  search_term = ""
  search_active = false
  search_matches = {}
  current_match_index = 0
end

-- State for help display
local show_help_mode = false

-- Help display
local function toggle_help()
  show_help_mode = not show_help_mode
  refresh_explorer()
end

local function get_help_lines()
  return {
    "Note Explorer Keybindings",
    "========================",
    "",
    "Navigation:",
    "  Enter/o/l  Open file or expand directory",
    "  h          Collapse directory",
    "  q          Close explorer",
    "  Esc        Close explorer (or clear search)",
    "",
    "File Operations:",
    "  a          Create new note",
    "  d          Delete selected items",
    "  r          Rename file",
    "",
    "Selection:",
    "  Space      Toggle selection",
    "  Ctrl-a     Select all files",
    "  Ctrl-d     Clear selection",
    "",
    "Clipboard:",
    "  c          Copy selected items",
    "  x          Cut selected items",
    "  p          Paste items",
    "",
    "Opening Files:",
    "  Ctrl-x     Open in horizontal split",
    "  Ctrl-v     Open in vertical split",
    "  Ctrl-t     Open in new tab",
    "",
    "Search:",
    "  /          Start search",
    "  n          Next match",
    "  N          Previous match",
    "",
    "Other:",
    "  R          Refresh explorer",
    "  ?          Toggle this help",
    "",
    "Press ? again to return to file view"
  }
end

local function setup_keymaps()
  local opts = { noremap = true, silent = true, buffer = explorer_buf }
  
  -- Navigation
  vim.keymap.set('n', '<CR>', function() open_note() end, opts)
  vim.keymap.set('n', 'o', function() open_note() end, opts)
  vim.keymap.set('n', 'l', function() open_note() end, opts)
  vim.keymap.set('n', 'h', toggle_directory, opts)
  
  -- Split opening
  vim.keymap.set('n', '<C-x>', function() open_note("split") end, opts)
  vim.keymap.set('n', '<C-v>', function() open_note("vsplit") end, opts)
  vim.keymap.set('n', '<C-t>', function() open_note("tabedit") end, opts)
  
  -- Selection
  vim.keymap.set('n', '<Space>', toggle_selection, opts)
  vim.keymap.set('n', '<C-a>', select_all, opts)
  vim.keymap.set('n', '<C-d>', clear_selection, opts)
  
  -- Clipboard
  vim.keymap.set('n', 'c', copy_entries, opts)
  vim.keymap.set('n', 'x', cut_entries, opts)
  vim.keymap.set('n', 'p', paste_entries, opts)
  
  -- File operations
  vim.keymap.set('n', 'a', create_note, opts)
  vim.keymap.set('n', 'd', delete_entries, opts)
  vim.keymap.set('n', 'r', rename_entry, opts)
  
  -- Search
  vim.keymap.set('n', '/', start_search, opts)
  vim.keymap.set('n', 'n', next_match, opts)
  vim.keymap.set('n', 'N', prev_match, opts)
  vim.keymap.set('n', '<Esc>', function()
    if search_active then
      clear_search()
    else
      M.close()
    end
  end, opts)
  
  -- Close
  vim.keymap.set('n', 'q', M.close, opts)
  
  -- Refresh
  vim.keymap.set('n', 'R', refresh_explorer, opts)
  
  -- Help
  vim.keymap.set('n', '?', toggle_help, opts)
  
  -- Prevent modification
  vim.keymap.set('n', 'i', '<Nop>', opts)
  vim.keymap.set('n', 'A', '<Nop>', opts)
  vim.keymap.set('n', 'O', '<Nop>', opts)
  vim.keymap.set('n', 'dd', '<Nop>', opts)
  vim.keymap.set('n', 'D', '<Nop>', opts)
end

function M.setup(cfg)
  config = cfg
end

function M.open()
  -- Close existing explorer if any
  if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
    M.close()
    return
  end
  
  -- Reset state
  selected_entries = {}
  search_term = ""
  search_active = false
  search_matches = {}
  current_match_index = 0
  show_help_mode = false
  
  -- Create buffer
  explorer_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(explorer_buf, "Note Explorer")
  vim.api.nvim_buf_set_option(explorer_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(explorer_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(explorer_buf, 'filetype', 'markdown-note-explorer')
  
  -- Create window at bottom
  vim.cmd('botright split')
  explorer_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(explorer_win, 15)
  vim.api.nvim_win_set_buf(explorer_win, explorer_buf)
  
  -- Window options
  vim.api.nvim_win_set_option(explorer_win, 'number', false)
  vim.api.nvim_win_set_option(explorer_win, 'relativenumber', false)
  vim.api.nvim_win_set_option(explorer_win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(explorer_win, 'wrap', false)
  vim.api.nvim_win_set_option(explorer_win, 'cursorline', true)
  
  -- Setup keymaps
  setup_keymaps()
  
  -- Initial content
  refresh_explorer()
  
  -- Autocommands
  local augroup = vim.api.nvim_create_augroup('MarkdownNoteExplorer', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = augroup,
    buffer = explorer_buf,
    callback = function()
      explorer_buf = nil
      explorer_win = nil
    end
  })
end

function M.close()
  if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
    vim.api.nvim_win_close(explorer_win, true)
  end
  explorer_win = nil
  explorer_buf = nil
end

function M.toggle()
  if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
    M.close()
  else
    M.open()
  end
end

function M.is_open()
  return explorer_win and vim.api.nvim_win_is_valid(explorer_win)
end

return M