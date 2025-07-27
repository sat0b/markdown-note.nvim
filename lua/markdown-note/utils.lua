local M = {}

function M.get_date_string(config)
  return os.date(config.date_format)
end

function M.get_projects(config)
  local projects = { "(default)" }
  local notes_dir = vim.fn.expand(config.notes_dir)
  local projects_dir = notes_dir .. "/projects"
  
  -- Create projects directory if it doesn't exist
  vim.fn.mkdir(projects_dir, "p")
  
  -- Get all directories in projects subdirectory
  local handle = vim.loop.fs_scandir(projects_dir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      if type == "directory" then
        table.insert(projects, name)
      end
    end
  end
  
  table.insert(projects, "(new project)")
  return projects
end

function M.create_note_path(config, title, project)
  local date = M.get_date_string(config)
  local filename = string.format("%s-%s.md", date, title or config.default_title)
  local notes_dir = vim.fn.expand(config.notes_dir)
  
  if project and project ~= "(default)" then
    local project_dir = notes_dir .. "/projects/" .. project
    vim.fn.mkdir(project_dir, "p")
    return project_dir .. "/" .. filename
  else
    return notes_dir .. "/" .. filename
  end
end

function M.create_note_with_title(config, title, project)
  local path = M.create_note_path(config, title, project)
  return path, title
end

function M.select_project(config, callback)
  local projects = M.get_projects(config)
  
  -- Try to use Telescope if available
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Select Project",
      finder = finders.new_table {
        results = projects
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            local choice = selection[1]
            if choice == "(new project)" then
              vim.ui.input({
                prompt = "Enter new project name: ",
              }, function(project_name)
                if project_name and project_name ~= "" then
                  callback(project_name)
                end
              end)
            else
              callback(choice == "(default)" and nil or choice)
            end
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(projects, {
      prompt = "Select project:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not choice then
        return
      end
      
      if choice == "(new project)" then
        vim.ui.input({
          prompt = "Enter new project name: ",
        }, function(project_name)
          if project_name and project_name ~= "" then
            callback(project_name)
          end
        end)
      else
        callback(choice == "(default)" and nil or choice)
      end
    end)
  end
end

function M.get_all_notes(config, project)
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
        elseif type == "directory" and not project then
          scan_directory(dir .. "/" .. name, name)
        end
      end
    end
  end
  
  if project then
    scan_directory(notes_dir .. "/projects/" .. project, project)
  else
    scan_directory(notes_dir)
  end
  
  return notes
end

return M