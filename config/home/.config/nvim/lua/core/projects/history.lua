-- 自有副本 ∪ 插件文件 ∪ 会话项目；只读 recent_projects，只追加回填。

local M = {}

local function own_history_file()
  return vim.fn.stdpath("state") .. "/project-history.list"
end

local function normalize_dir(dir)
  return (dir:gsub("\\", "/"):gsub("//", "/"))
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

local function read_own_history()
  local dirs, seen = {}, {}
  for _, line in ipairs(read_lines(own_history_file())) do
    local dir = normalize_dir(vim.trim(line))
    if dir ~= "" and not seen[dir] and vim.uv.fs_stat(dir) then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end
  return dirs, seen
end

local function append_history_file(path, dirs, existing)
  existing = existing or {}
  local fresh = {}
  for _, dir in ipairs(dirs) do
    local normalized = normalize_dir(dir)
    if normalized ~= "" and not existing[normalized] and vim.uv.fs_stat(normalized) then
      existing[normalized] = true
      fresh[#fresh + 1] = normalized
    end
  end
  if #fresh == 0 then
    return 0
  end

  local f = io.open(path, "a")
  if not f then
    return 0
  end
  f:write(table.concat(fresh, "\n") .. "\n")
  f:close()
  return #fresh
end

function M.list()
  local ok_path, path = pcall(require, "project_nvim.utils.path")
  local dirs, seen = {}, {}

  local function put(dir)
    if seen[dir] then
      for i, d in ipairs(dirs) do
        if d == dir then
          table.remove(dirs, i)
          break
        end
      end
    end
    seen[dir] = true
    dirs[#dirs + 1] = dir
  end

  local own, own_seen = read_own_history()
  for _, dir in ipairs(own) do
    put(dir)
  end

  if ok_path then
    for _, line in ipairs(read_lines(path.historyfile)) do
      local dir = normalize_dir(vim.trim(line))
      if dir ~= "" and vim.uv.fs_stat(dir) then
        put(dir)
      end
    end
  end

  local ok_history, history = pcall(require, "project_nvim.utils.history")
  if ok_history and type(history.session_projects) == "table" then
    for _, dir in ipairs(history.session_projects) do
      local normalized = normalize_dir(dir)
      if normalized ~= "" then
        put(normalized)
      end
    end
  end

  append_history_file(own_history_file(), dirs, own_seen)
  if ok_path then
    local in_plugin = {}
    for _, line in ipairs(read_lines(path.historyfile)) do
      in_plugin[normalize_dir(vim.trim(line))] = true
    end
    append_history_file(path.historyfile, dirs, in_plugin)
  end

  return dirs
end

local PROJECT_MARKERS = {
  ".git",
  ".hg",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "package.json",
  "go.mod",
  "Cargo.toml",
  "pyproject.toml",
  "CMakeLists.txt",
}

local function looks_like_project(dir)
  for _, marker in ipairs(PROJECT_MARKERS) do
    if vim.uv.fs_stat(dir .. "/" .. marker) then
      return true
    end
  end
  return false
end

function M.mirror(dir)
  if looks_like_project(dir) then
    local _, seen = read_own_history()
    append_history_file(own_history_file(), { dir }, seen)
  end
end

-- 上游截断写存在多实例竞态；即使读取失败也绝不回退到截断。
function M.protect()
  local ok_hist, history = pcall(require, "project_nvim.utils.history")
  local ok_path_utils, path_utils = pcall(require, "project_nvim.utils.path")
  if ok_hist and ok_path_utils and type(history.write_projects_to_history) == "function" then
    local function disk_entries()
      local set = {}
      local fh = io.open(path_utils.historyfile, "r")
      if not fh then
        return set
      end
      local data = fh:read("*a")
      fh:close()
      for line in data:gmatch("[^\r\n]+") do
        local dir = vim.trim(line)
        if dir ~= "" then
          set[dir] = true
        end
      end
      return set
    end

    history.write_projects_to_history = function()
      local ok, err = pcall(function()
        local disk = disk_entries()
        local missing = {}
        for _, dir in ipairs(history.get_recent_projects()) do
          if not disk[dir] then
            disk[dir] = true
            missing[#missing + 1] = dir
          end
        end
        if #missing == 0 then
          return -- 磁盘已包含本次全部条目：什么都不用写
        end

        pcall(path_utils.create_scaffolding)
        local fh = io.open(path_utils.historyfile, "a")
        if not fh then
          return
        end
        fh:write(table.concat(missing, "\n") .. "\n")
        fh:close()
      end)
      if not ok then
        vim.notify(
          "项目历史写回守卫异常（本次跳过写入，绝不截断）: " .. tostring(err),
          vim.log.levels.WARN
        )
      end
    end
  end
end

return M
