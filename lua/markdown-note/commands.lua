local M = {}
local utils = require("markdown-note.utils")

local config = {}

local function open_note_with_title(path, title)
  vim.cmd(config.open_cmd .. " " .. path)
  
  -- If auto_insert_title is enabled and buffer is empty, insert title
  if config.auto_insert_title and vim.fn.getline(1) == "" and vim.fn.line('$') == 1 then
    local lines = {"# " .. (title or config.default_title), "", ""}
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    -- Move cursor to line 3 (after title and blank line)
    vim.api.nvim_win_set_cursor(0, {3, 0})
  end
end

function M.setup(cfg)
  config = cfg
  
  -- Create commands
  vim.api.nvim_create_user_command("NoteNew", M.note_new, {})
  vim.api.nvim_create_user_command("NoteQuick", M.note_quick, { nargs = "*" })
  vim.api.nvim_create_user_command("NoteToday", M.note_today, {})
  vim.api.nvim_create_user_command("NoteList", M.note_list, { nargs = "?" })
  vim.api.nvim_create_user_command("NoteDirectories", M.note_directories, {})
  vim.api.nvim_create_user_command("NoteFindFile", M.note_find_file, {})
  vim.api.nvim_create_user_command("NoteGrep", M.note_grep, {})
  vim.api.nvim_create_user_command("NoteDelete", M.note_delete, {})
  vim.api.nvim_create_user_command("NoteDeleteMulti", M.note_delete_multi, {})
  vim.api.nvim_create_user_command("NoteRename", M.note_rename, {})
  vim.api.nvim_create_user_command("NoteExplorer", M.note_explorer, {})
  vim.api.nvim_create_user_command("NoteRecent", M.note_recent, {})
end

function M.note_new()
  utils.select_directory(config, function(directory)
    vim.ui.input({
      prompt = "Enter title: ",
    }, function(title)
      if title then
        local path, note_title = utils.create_note_with_title(config, title, directory)
        open_note_with_title(path, note_title)
      end
    end)
  end)
end

function M.note_quick(opts)
  local args = vim.split(opts.args, " ")
  local title = args[1]
  local directory = args[2]
  
  if not title then
    vim.notify("Usage: :NoteQuick <title> [directory]", vim.log.levels.ERROR)
    return
  end
  
  local path, note_title = utils.create_note_with_title(config, title, directory)
  open_note_with_title(path, note_title)
end

function M.note_today()
  -- Use daily_date_prefix format for daily notes
  local date = os.date(config.daily_date_prefix)
  -- Always use "daily" directory for today's notes
  local directory = "daily"
  -- Create path directly since we're using a different date format
  local notes_dir = vim.fn.expand(config.notes_dir)
  local dir_path = notes_dir .. "/" .. directory
  vim.fn.mkdir(dir_path, "p")
  local path = dir_path .. "/" .. date .. ".md"
  open_note_with_title(path, date)
end

function M.note_list(opts)
  local directory = opts.args ~= "" and opts.args or nil
  local notes = utils.get_all_notes(config, directory)
  
  if #notes == 0 then
    vim.notify("No notes found", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(notes, {
    prompt = "Select note:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if choice then
      vim.cmd(config.open_cmd .. " " .. choice.path)
    end
  end)
end

function M.note_directories()
  local directories = utils.get_directories(config)
  
  if #directories == 0 then
    vim.notify("No directories found", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(directories, {
    prompt = "Directories:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      M.note_list({ args = choice })
    end
  end)
end


function M.note_find_file()
  vim.notify("This feature has been removed. Use NoteExplorer instead.", vim.log.levels.INFO)
end

function M.note_grep()
  vim.notify("This feature has been removed. Use NoteExplorer search (/) instead.", vim.log.levels.INFO)
end

function M.note_delete()
  local current_file = vim.fn.expand('%:p')
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  -- Check if current file is in notes directory
  if not current_file:match("^" .. notes_dir) then
    vim.notify("Current file is not a note", vim.log.levels.ERROR)
    return
  end
  
  local filename = vim.fn.expand('%:t')
  vim.ui.select({"No", "Yes"}, {
    prompt = string.format("Delete '%s'?", filename),
  }, function(choice)
    if choice == "Yes" then
      -- Close buffer
      vim.cmd("bdelete!")
      -- Delete file
      local ok, err = os.remove(current_file)
      if ok then
        vim.notify("Note deleted: " .. filename, vim.log.levels.INFO)
      else
        vim.notify("Failed to delete note: " .. (err or "unknown error"), vim.log.levels.ERROR)
      end
    end
  end)
end

function M.note_delete_multi()
  vim.notify("This feature has been removed. Use NoteExplorer for file management.", vim.log.levels.INFO)
end

function M.note_rename()
  local current_file = vim.fn.expand('%:p')
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  -- Check if current file is in notes directory
  if not current_file:match("^" .. notes_dir) then
    vim.notify("Current file is not a note", vim.log.levels.ERROR)
    return
  end
  
  -- Extract current title from filename
  local filename = vim.fn.expand('%:t:r')  -- filename without extension
  local date_pattern = "^%d%d%d%d%-%d%d%-%d%d%-"
  local current_title = filename:gsub(date_pattern, "")
  
  vim.ui.input({
    prompt = "Enter new title: ",
    default = current_title,
  }, function(new_title)
    if not new_title or new_title == "" or new_title == current_title then
      return
    end
    
    -- Get the date part from current filename
    local date = filename:match(date_pattern) or (utils.get_date_string(config) .. "-")
    date = date:sub(1, -2)  -- Remove trailing dash
    
    -- Construct new filename
    local dir = vim.fn.expand('%:p:h')
    local new_filename = date .. "-" .. new_title .. ".md"
    local new_path = dir .. "/" .. new_filename
    
    -- Check if new file already exists
    if vim.fn.filereadable(new_path) == 1 then
      vim.notify("File already exists: " .. new_filename, vim.log.levels.ERROR)
      return
    end
    
    -- Update the title in the file content if auto_insert_title is enabled
    if config.auto_insert_title then
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      if #lines > 0 and lines[1]:match("^# ") then
        lines[1] = "# " .. new_title
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      end
    end
    
    -- Save the buffer
    vim.cmd("write")
    
    -- Rename the file
    local ok, err = os.rename(current_file, new_path)
    if ok then
      -- Open the renamed file
      vim.cmd("edit " .. vim.fn.fnameescape(new_path))
      -- Delete the old buffer
      vim.cmd("bdelete #")
      vim.notify("Renamed to: " .. new_filename, vim.log.levels.INFO)
    else
      vim.notify("Failed to rename file: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

function M.note_explorer()
  require("markdown-note.explorer").toggle()
end

function M.note_recent()
  local recent_note = utils.get_recent_note(config)
  
  if recent_note then
    vim.cmd(config.open_cmd .. " " .. recent_note.path)
  else
    vim.notify("No notes found", vim.log.levels.INFO)
  end
end

return M
