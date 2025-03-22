local M = {}

-- Function to extract the repo name from the URL
function M.get_repo_name(url)
  return url:match(".*/(.*).git")
end

function M.get_lazy_plugins()
  local lazy = require("lazy") -- Ensure lazy.nvim is loaded
  local plugins = lazy.plugins() -- Retrieve the plugin list
  local repos = {}

  for _, plugin in pairs(plugins) do
    if plugin.url then
      table.insert(repos, plugin.url) -- Add the Git repo URL to the list
    end
  end

  return repos
end

function M.format_directory(dir)
  local status = os.execute(string.format("mkdir -p %s/nvim-deps/", dir))
  if status == false then
    vim.notify("Failed to create nvim-deps in output directory", vim.log.levels.ERROR)
    return false
  end
  status = os.execute(string.format("mkdir -p %s/config/", dir))
  if status == false then
    vim.notify("Failed to create config in output directory", vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.clone_repos(repos, dir)
  for _, url in ipairs(repos) do
    local repo_name = M.get_repo_name(url)
    local status = os.execute(string.format("git clone %s %s/nvim-deps/%s > /dev/null 2>&1", url, dir, repo_name))
    if status == false then
      vim.notify(string.format("Failed to clone %s", repo_name), vim.log.levels.ERROR)
      return false
    end
  end

  return true
end

function M.copy_config(dir)
  local config_path = vim.fn.stdpath("config")
  local expanded_dir = vim.fn.expand(dir) -- Expand ~ if necessary

  -- Use rsync to copy all files and directories inside config_path
  local cmd = string.format("rsync -a %s/ %s/config/ > /dev/null 2>&1", config_path, expanded_dir)
  local result = os.execute(cmd)

  if result == false then
    vim.notify("Failed to copy config", vim.log.levels.ERROR)
  end

  return result
end

function M.update_lazy_config(deps_dir)
  -- Ensure lazy.nvim is loaded
  local lazy = require("lazy")

  -- Get all configured plugins
  local plugins = lazy.plugins()

  -- Iterate over plugins to generate updated configurations
  for _, plugin in pairs(plugins) do
    if plugin.dir then
      -- Plugin already uses a local directory, no need to modify
      vim.notify(string.format("Skipped plugin (already local): %s", plugin.dir), vim.log.levels.INFO)
    elseif plugin.url then
      -- Construct new `dir` field pointing to the local dependency directory
      local repo_name = plugin.name or plugin.url:match(".*/(.*).git") or "unknown-plugin"
      plugin.dir = string.format("%s/%s", deps_dir, repo_name)

      vim.notify(string.format("Updated plugin '%s' to use local dir: %s", repo_name, plugin.dir), vim.log.levels.INFO)
    else
      -- Handle any plugins with non-standard configurations
      vim.notify(string.format("Could not update plugin: %s", plugin.name or "unknown"), vim.log.levels.WARN)
    end
  end
end

local function update_copied_config_with_lazy_api(config_dir, search_values, deps_dir)
  local plugins_dir = vim.fn.expand(config_dir .. "/lua/plugins/")

  -- Utility function to read the content of a file
  local function read_file(file_path)
    local file = io.open(file_path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
  end

  -- Utility function to write content to a file
  local function write_file(file_path, content)
    local file = io.open(file_path, "w")
    if not file then return nil end
    file:write(content)
    file:close()
  end

  -- Utility function to find repo_name from search_values
  local function extract_repo_name(value)
    return value:match(".*/(.*).git") or value:match("[^/]+$")
  end

  local function escape_special_chars(value)
    return value:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")
  end

  -- Iterate over all files in the plugins directory
  for file_name in io.popen('ls "' .. plugins_dir .. '"'):lines() do
    local file_path = plugins_dir .. file_name
    local content = read_file(file_path)

    if content then
      local modified_content = content

      -- Handle matches inside single/double quotes
      for _, search_value in ipairs(search_values) do
        local escaped_value = escape_special_chars(search_value)
        local repo_name = extract_repo_name(search_value)
        if repo_name then
          -- Replace quoted matches
          modified_content = modified_content
            :gsub('"' .. escaped_value .. '"', 'dir = "' .. deps_dir .. '/' .. repo_name .. '"')
            :gsub("'" .. escaped_value .. "'", "dir = '" .. deps_dir .. '/' .. repo_name .. "'")
        end
      end

      -- Write back the modified content if changes were made
      if modified_content ~= content then
        write_file(file_path, modified_content)
      end
    end
  end
end

local function extract_plugin_search_values(plugins)
  local search_values = {}

  for _, plugin in pairs(plugins) do
    if plugin.url then
      table.insert(search_values, plugin.url) -- Add the full URL

      -- Split the URL into components
      local parts = {}
      for part in plugin.url:gmatch("[^/]+") do
        table.insert(parts, part)
      end

      -- Get the second-to-last and last parts as "username/repo"
      if #parts > 2 then
        local username_repo = parts[#parts - 1] .. "/" .. parts[#parts]:gsub("%.git$", "")
        table.insert(search_values, username_repo)
      end
    elseif plugin.name then
      table.insert(search_values, plugin.name) -- Add the plugin name if no URL
    end
  end

  return search_values
end

function M.replace_plugin_dirs(copied_config_dir, deps_dir)
  -- Ensure lazy.nvim is loaded
  local lazy = require("lazy")

  local search_values = extract_plugin_search_values(lazy.plugins())
  update_copied_config_with_lazy_api(copied_config_dir, search_values, deps_dir)
end

function M.add_unpack_script(dir)
  -- Get the path of the directory containing this Lua script
  local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""

  -- Construct the path to find unpack script
  local script_path = plugin_dir .. "../../scripts/unpack.sh"

  local status = os.execute(string.format("cp %s %s", vim.fn.expand(script_path), dir))
  if status == false then
    vim.notify("Could not copy unpack script", vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.tar_with_date(output_dir, tar_dir)
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  local tar_name = string.format("nvim-snapshot-%s.tar.gz", timestamp)
  local status = os.execute(string.format("tar -C %s -czf %s/%s .", vim.fn.expand(tar_dir), output_dir, tar_name))
  if status == true then
    vim.notify(string.format("Successfully created snapshot at %s/%s", output_dir, tar_name), vim.log.levels.INFO)
  else
    vim.notify("Failed to tar bundle", vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
