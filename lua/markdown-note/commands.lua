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
  vim.api.nvim_create_user_command("NoteProjects", M.note_projects, {})
  vim.api.nvim_create_user_command("NoteSetDefault", M.note_set_default, { nargs = 1 })
  vim.api.nvim_create_user_command("NoteFindFile", M.note_find_file, {})
  vim.api.nvim_create_user_command("NoteGrep", M.note_grep, {})
  vim.api.nvim_create_user_command("NoteDelete", M.note_delete, {})
  vim.api.nvim_create_user_command("NoteDeleteMulti", M.note_delete_multi, {})
  vim.api.nvim_create_user_command("NoteRename", M.note_rename, {})
end

function M.note_new()
  utils.select_project(config, function(project)
    vim.ui.input({
      prompt = "Enter title: ",
    }, function(title)
      if title then
        local path, note_title = utils.create_note_with_title(config, title, project)
        open_note_with_title(path, note_title)
      end
    end)
  end)
end

function M.note_quick(opts)
  local args = vim.split(opts.args, " ")
  local title = args[1]
  local project = args[2]
  
  if not title then
    vim.notify("Usage: :NoteQuick <title> [project]", vim.log.levels.ERROR)
    return
  end
  
  local path, note_title = utils.create_note_with_title(config, title, project)
  open_note_with_title(path, note_title)
end

function M.note_today()
  local title = "daily"
  local project = config.default_project
  local path, note_title = utils.create_note_with_title(config, title, project)
  open_note_with_title(path, note_title)
end

function M.note_list(opts)
  local project = opts.args ~= "" and opts.args or nil
  local notes = utils.get_all_notes(config, project)
  
  if #notes == 0 then
    vim.notify("No notes found", vim.log.levels.INFO)
    return
  end
  
  -- Try to use Telescope if available
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Select Note",
      finder = finders.new_table {
        results = notes,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.display,
          }
        end
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd(config.open_cmd .. " " .. selection.value.path)
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
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
end

function M.note_projects()
  local projects = utils.get_projects(config)
  local filtered = {}
  
  for _, project in ipairs(projects) do
    if project ~= "(default)" and project ~= "(new project)" then
      table.insert(filtered, project)
    end
  end
  
  if #filtered == 0 then
    vim.notify("No projects found", vim.log.levels.INFO)
    return
  end
  
  -- Try to use Telescope if available
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Projects",
      finder = finders.new_table {
        results = filtered
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            M.note_list({ args = selection[1] })
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(filtered, {
      prompt = "Projects:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice then
        M.note_list({ args = choice })
      end
    end)
  end
end

function M.note_set_default(opts)
  local project = opts.args
  config.default_project = project ~= "(default)" and project or nil
  vim.notify("Default project set to: " .. (project or "(default)"))
end

function M.note_find_file()
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  
  if not has_telescope then
    vim.notify("Telescope is required for this feature", vim.log.levels.ERROR)
    return
  end
  
  telescope.find_files({
    cwd = config.notes_dir,
    prompt_title = "Find Notes",
  })
end

function M.note_grep()
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  
  if not has_telescope then
    vim.notify("Telescope is required for this feature", vim.log.levels.ERROR)
    return
  end
  
  telescope.live_grep({
    cwd = config.notes_dir,
    prompt_title = "Search Notes Content",
  })
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
  vim.ui.select({"Yes", "No"}, {
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
  local notes = utils.get_all_notes(config)
  
  if #notes == 0 then
    vim.notify("No notes found", vim.log.levels.INFO)
    return
  end
  
  -- Try to use Telescope for multi-select
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Delete Notes (Tab to select multiple, Enter to confirm)",
      finder = finders.new_table {
        results = notes,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.display,
          }
        end
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local multi_selections = picker:get_multi_selection()
          
          if vim.tbl_isempty(multi_selections) then
            vim.notify("No notes selected", vim.log.levels.WARN)
            actions.close(prompt_bufnr)
            return
          end
          
          actions.close(prompt_bufnr)
          
          -- Confirm deletion
          local count = #multi_selections
          vim.ui.select({"Yes", "No"}, {
            prompt = string.format("Delete %d note(s)?", count),
          }, function(choice)
            if choice == "Yes" then
              local deleted = 0
              for _, selection in ipairs(multi_selections) do
                local ok, err = os.remove(selection.value.path)
                if ok then
                  deleted = deleted + 1
                else
                  vim.notify("Failed to delete: " .. selection.value.display, vim.log.levels.ERROR)
                end
              end
              vim.notify(string.format("Deleted %d/%d notes", deleted, count), vim.log.levels.INFO)
            end
          end)
        end)
        
        -- Allow multi-selection with Tab
        map("i", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
        map("i", "<S-Tab>", actions.toggle_selection + actions.move_selection_better)
        map("n", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
        map("n", "<S-Tab>", actions.toggle_selection + actions.move_selection_better)
        
        return true
      end,
    }):find()
  else
    vim.notify("Telescope is required for multi-delete", vim.log.levels.ERROR)
  end
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

return M
