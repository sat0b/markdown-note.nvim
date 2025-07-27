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
  utils.select_project(config, function(project)
    vim.ui.input({
      prompt = "Enter title (default: daily): ",
    }, function(title)
      title = title and title ~= "" and title or "daily"
      local path, note_title = utils.create_note_with_title(config, title, project)
      open_note_with_title(path, note_title)
    end)
  end)
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

return M
