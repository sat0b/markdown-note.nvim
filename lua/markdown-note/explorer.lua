local M = {}

local explorer_buf = nil
local explorer_win = nil
local config = {}
local current_path = nil
local entries = {}

local function get_icon(entry)
  if entry.type == "directory" then
    return entry.expanded and "▼ " or "▶ "
  else
    return "  "
  end
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
  local lines = {}
  for _, entry in ipairs(entries) do
    local icon = get_icon(entry)
    local line = entry.prefix .. icon .. entry.name
    table.insert(lines, line)
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(explorer_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', false)
end

local function toggle_directory()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = entries[row]
  
  if entry and entry.type == "directory" then
    entry.expanded = not entry.expanded
    refresh_explorer()
    vim.api.nvim_win_set_cursor(0, {row, 0})
  end
end

local function open_note()
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
      
      -- Open file
      vim.cmd(config.open_cmd .. " " .. vim.fn.fnameescape(entry.path))
    elseif entry.type == "directory" then
      toggle_directory()
    end
  end
end

local function setup_keymaps()
  local opts = { noremap = true, silent = true, buffer = explorer_buf }
  
  -- Navigation
  vim.keymap.set('n', '<CR>', open_note, opts)
  vim.keymap.set('n', 'o', open_note, opts)
  vim.keymap.set('n', 'l', open_note, opts)
  vim.keymap.set('n', 'h', toggle_directory, opts)
  vim.keymap.set('n', '<Space>', toggle_directory, opts)
  
  -- Close
  vim.keymap.set('n', 'q', M.close, opts)
  vim.keymap.set('n', '<Esc>', M.close, opts)
  
  -- Refresh
  vim.keymap.set('n', 'r', refresh_explorer, opts)
  vim.keymap.set('n', 'R', refresh_explorer, opts)
  
  -- Prevent modification
  vim.keymap.set('n', 'i', '<Nop>', opts)
  vim.keymap.set('n', 'a', '<Nop>', opts)
  vim.keymap.set('n', 'o', open_note, opts)
  vim.keymap.set('n', 'O', '<Nop>', opts)
  vim.keymap.set('n', 'dd', '<Nop>', opts)
  vim.keymap.set('n', 'D', '<Nop>', opts)
  vim.keymap.set('n', 'x', '<Nop>', opts)
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