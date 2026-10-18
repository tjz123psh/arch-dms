local M = {}

M.markers = { "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", ".project" }
M.tasks = {
  compile = { maven = { "compile" }, gradle = { "classes" } },
  test = { maven = { "test" }, gradle = { "test" } },
  package = { maven = { "package", "-DskipTests" }, gradle = { "build", "-x", "test" } },
  install = { maven = { "install", "-DskipTests" }, gradle = { "publishToMavenLocal" } },
  clean = { maven = { "clean" }, gradle = { "clean" } },
  dependencies = { maven = { "dependency:tree" }, gradle = { "dependencies" } },
}

function M.root(bufnr)
  return vim.fs.root(bufnr or 0, M.markers)
end

function M.source_root(file, package_name)
  local dir = vim.fs.dirname(file)
  if not package_name or package_name == "" then
    return dir
  end
  local suffix = "/" .. package_name:gsub("%.", "/")
  return dir:sub(-#suffix) == suffix and (dir:sub(1, -#suffix - 1):gsub("^$", "/")) or nil
end

function M.lsp_root(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  local root = M.root(bufnr) or vim.fs.root(bufnr, { ".git" })
  if not root then
    root = M.source_root(file, require("languages.java.syntax").package(bufnr)) or vim.fs.dirname(file)
  end
  return vim.uv.fs_realpath(root) or vim.fs.normalize(root)
end

function M.tool(root)
  if not root then
    return nil, "未找到 Maven / Gradle 项目；单文件请用 :JavaRun"
  end
  local gradle = vim.uv.fs_stat(root .. "/build.gradle") or vim.uv.fs_stat(root .. "/build.gradle.kts")
  local kind = gradle and "gradle" or "maven"
  if not gradle and not vim.uv.fs_stat(root .. "/pom.xml") then
    return nil, "项目中没有 pom.xml 或 build.gradle(.kts)"
  end
  local executable = gradle and "gradle" or "mvn"
  local wrapper = vim.fs.find(executable .. "w", { path = root, upward = true })[1]
  if wrapper then
    -- 不修改项目 wrapper 的权限；sh 同样可以执行未带 executable 位的 wrapper。
    return { root = root, kind = kind, bin = { "sh", wrapper } }
  end
  local bin = vim.fn.exepath(executable)
  if bin == "" then
    local cache = gradle and "/.gradle/wrapper/dists/**/bin/gradle" or "/.m2/wrapper/dists/**/bin/mvn"
    for _, candidate in ipairs(vim.fn.glob(vim.env.HOME .. cache, false, true)) do
      if vim.fn.executable(candidate) == 1 then
        bin = candidate
        break
      end
    end
  end
  if bin == "" then
    return nil, "找不到 " .. executable .. "，请使用项目 wrapper 或安装对应构建工具"
  end
  return { root = root, kind = kind, bin = { bin } }
end

function M.command(tool, args)
  local argv = vim.list_extend(vim.deepcopy(tool.bin), args)
  return table.concat(vim.tbl_map(vim.fn.shellescape, argv), " ")
end

function M.build(task, selector)
  local tool, err = M.tool(M.root())
  if not tool then
    return vim.notify(err, vim.log.levels.WARN)
  end
  local args = vim.deepcopy(assert(M.tasks[task], "unknown build task")[tool.kind])
  if selector then
    vim.list_extend(
      args,
      tool.kind == "maven" and { "-Dtest=" .. selector } or { "--tests", (selector:gsub("#", ".")) }
    )
  end
  local terminals = require("languages.java.terminal")
  return terminals.run(terminals.get(tool.root, "build"), M.command(tool, args), false)
end

function M.test(include_method)
  local selector, err = require("languages.java.syntax").selector(0, include_method)
  if not selector then
    return vim.notify(err, vim.log.levels.WARN)
  end
  return M.build("test", selector)
end

return M
