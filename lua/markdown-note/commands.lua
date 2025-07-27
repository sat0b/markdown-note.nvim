local M = {}
local utils = require("markdown-note.utils")

local config = {}

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
        local path = utils.create_note_path(config, title, project)
        vim.cmd(config.open_cmd .. " " .. path)
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
  
  local path = utils.create_note_path(config, title, project)
  vim.cmd(config.open_cmd .. " " .. path)
end

function M.note_today()
  utils.select_project(config, function(project)
    vim.ui.input({
      prompt = "Enter title (default: daily): ",
    }, function(title)
      title = title and title ~= "" and title or "daily"
      local path = utils.create_note_path(config, title, project)
      vim.cmd(config.open_cmd .. " " .. path)
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
