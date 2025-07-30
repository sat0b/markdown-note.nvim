local M = {}

function M.get_date_string(config)
  return os.date(config.date_prefix)
end

function M.get_directories(config)
  local directories = {}
  local notes_dir = vim.fn.expand(config.notes_dir)
  -- Get all directories in notes_dir
  local handle = vim.loop.fs_scandir(notes_dir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      if type == "directory" then
        table.insert(directories, name)
      end
    end
  end
  
  return directories
end

function M.create_note_path(config, title, directory)
  local date = M.get_date_string(config)
  local filename
  
  -- Check if title is already a date (matches the date format)
  if title == date then
    filename = string.format("%s.md", title)
  else
    filename = string.format("%s-%s.md", date, title or config.default_title)
  end
  
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  if directory then
    local dir_path = notes_dir .. "/" .. directory
    vim.fn.mkdir(dir_path, "p")
    return dir_path .. "/" .. filename
  else
    return notes_dir .. "/" .. filename
  end
end

function M.create_note_with_title(config, title, directory)
  local path = M.create_note_path(config, title, directory)
  return path, title
end

function M.select_directory(config, callback)
  local directories = M.get_directories(config)
  table.insert(directories, 1, "(root)")
  table.insert(directories, "(new directory)")
  
  vim.ui.select(directories, {
    prompt = "Select directory:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end
    
    if choice == "(new directory)" then
      vim.ui.input({
        prompt = "Enter new directory name: ",
      }, function(dir_name)
        if dir_name and dir_name ~= "" then
          callback(dir_name)
        end
      end)
    elseif choice == "(root)" then
      callback(nil)
    else
      callback(choice)
    end
  end)
end

function M.get_all_notes(config, directory)
  local notes = {}
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  local function scan_directory(dir, prefix)
    local handle = vim.loop.fs_scandir(dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        
        if type == "file" and name:match("%.md$") then
          local path = dir .. "/" .. name
          local display = prefix and (prefix .. "/" .. name) or name
          table.insert(notes, { path = path, display = display })
        elseif type == "directory" and not directory then
          scan_directory(dir .. "/" .. name, name)
        end
      end
    end
  end
  
  if directory then
    scan_directory(notes_dir .. "/" .. directory, directory)
  else
    scan_directory(notes_dir)
  end
  
  return notes
end

function M.get_recent_note(config)
  local notes = M.get_all_notes(config)
  
  if #notes == 0 then
    return nil
  end
  
  -- Sort notes by modification time (newest first)
  table.sort(notes, function(a, b)
    local stat_a = vim.loop.fs_stat(a.path)
    local stat_b = vim.loop.fs_stat(b.path)
    
    if stat_a and stat_b then
      return stat_a.mtime.sec > stat_b.mtime.sec
    end
    return false
  end)
  
  return notes[1]
end

return M