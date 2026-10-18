-- 项目接线；界面按需加载，历史只追加规则独立于 picker。
local history = require("core.projects.history")
local M = {}
local wrapped_set_pwd

function M.refresh_tree(dir)
  if not package.loaded["neo-tree.sources.manager"] then
    return
  end
  vim.schedule(function()
    local ok, manager = pcall(require, "neo-tree.sources.manager")
    if not ok then
      return
    end
    manager._for_each_state("filesystem", function(state)
      if state.path and state.path ~= dir then
        pcall(manager.navigate, state, dir)
      end
    end)
  end)
end

function M.patch()
  local ok, project = pcall(require, "project_nvim.project")
  if not ok then
    vim.notify("project.nvim 内部模块加载失败，已跳过兼容性修补", vim.log.levels.WARN)
    return
  end
  project.find_lsp_root = function()
    local ft = vim.bo.filetype
    local ignored = require("project_nvim.config").options.ignore_lsp
    for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
      local config = client.config
      if
        config.filetypes
        and vim.tbl_contains(config.filetypes, ft)
        and not vim.tbl_contains(ignored, client.name)
        and type(config.root_dir) == "string"
        and config.root_dir ~= ""
      then
        return config.root_dir, client.name
      end
    end
  end
  if type(project.set_pwd) == "function" and project.set_pwd ~= wrapped_set_pwd then
    local original = project.set_pwd
    wrapped_set_pwd = function(dir, method)
      local success, changed = pcall(original, dir, method)
      if not success then
        vim.notify("项目目录切换失败: " .. tostring(changed), vim.log.levels.ERROR)
        return false
      end
      if changed and type(dir) == "string" then
        M.refresh_tree(dir)
      end
      return changed
    end
    project.set_pwd = wrapped_set_pwd
  end
  history.protect()
end

function M.switch(dir)
  if type(dir) ~= "string" or dir == "" then
    vim.notify("项目切换失败：目录参数异常（" .. vim.inspect(dir) .. "）", vim.log.levels.ERROR)
    return
  end
  local ok, project = pcall(require, "project_nvim.project")
  if ok then
    project.set_pwd(dir, "projects")
  else
    vim.api.nvim_set_current_dir(dir)
  end
  -- 隐藏树和同目录重选未必产生 DirChanged，仍需主动刷新。
  M.refresh_tree(dir)
end

function M.setup()
  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("ProjectHistoryMirror", { clear = true }),
    desc = "把当前项目根追加到自有项目历史副本",
    callback = function()
      history.mirror(vim.fn.getcwd())
    end,
  })
  vim.api.nvim_create_user_command("Projects", function()
    require("core.projects.picker").show()
  end, { force = true, desc = "打开项目列表" })
end

return M
