local core = require("snapshot.core")
local M = {}
M.config = {
  output_dir = "~/tmp/",
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

vim.api.nvim_create_user_command(
  "Snapshot",
  function()
    local TMP_DIR = string.format("%s/tmp/", M.config.output_dir)
    local status

    -- Clean up previous stuff if it exists
    os.execute(string.format("rm -rf %s", TMP_DIR))

    -- Create tmp directory with structure
    status = core.format_directory(TMP_DIR)
    if status == false then
      return
    end

    -- Gather plugins
    local repos = core.get_lazy_plugins()
    status = core.clone_repos(repos, TMP_DIR)
    if status == false then
      return
    end

    -- Gather config
    status = core.copy_config(TMP_DIR)
    if status == false then
      return
    end

    -- Fix config to use "~/.config/nvim-deps/"
    local config_dir = string.format("%s/config/", TMP_DIR)
    local deps_dir = string.format("~/.config/nvim-deps", TMP_DIR)
    core.replace_plugin_dirs(config_dir, deps_dir)

    -- Add unpack script to bundle
    status = core.add_unpack_script(TMP_DIR)
    if status == false then
      return
    end

    -- Tar it all up
    status = core.tar_with_date(M.config.output_dir, TMP_DIR)
    if status == false then
      return
    end

    os.execute(string.format("rm -rf %s", TMP_DIR))
  end,
  {}
)

return M
