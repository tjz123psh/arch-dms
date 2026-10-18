local M = {}
local project = require("languages.java.project")

-- 独立源码运行：明确保存、临时编译、真实终端 stdin；不借用项目的 classpath。
function M.run()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype ~= "java" or file == "" or vim.bo.buftype ~= "" then
    return vim.notify(":JavaRun 需要一个已命名的 Java 文件", vim.log.levels.WARN)
  end
  for _, cmd in ipairs({ "javac", "java", "bash" }) do
    if vim.fn.executable(cmd) ~= 1 then
      return vim.notify("找不到 " .. cmd, vim.log.levels.ERROR)
    end
  end
  local package_name, parse_err = require("languages.java.syntax").package(0)
  if parse_err then
    return vim.notify(parse_err, vim.log.levels.ERROR)
  end
  local root = project.source_root(file, package_name)
  if not root then
    return vim.notify("文件目录与 package 声明不一致，无法确定源码根目录", vim.log.levels.ERROR)
  end
  local saved, err = pcall(vim.cmd, "update")
  if not saved or not vim.uv.fs_stat(file) then
    return vim.notify("保存失败，未运行 Java：" .. tostring(err or file), vim.log.levels.ERROR)
  end
  local output = vim.fn.tempname()
  vim.fn.mkdir(output, "p")
  local function cleanup()
    -- output 仅由本次 tempname/mkdir 创建；不删除源文件或项目产物。
    vim.fn.delete(output, "rf")
  end
  local class = vim.fn.fnamemodify(file, ":t:r")
  class = package_name and (package_name .. "." .. class) or class
  local function command(argv)
    return table.concat(vim.tbl_map(vim.fn.shellescape, argv), " ")
  end
  local compile = command({ vim.fn.exepath("javac"), "-encoding", "UTF-8", "-d", output, "-sourcepath", root, file })
  local run = command({ vim.fn.exepath("java"), "-cp", output, class })
  vim.cmd("botright 12new")
  local buf = vim.api.nvim_get_current_buf()
  local job = vim.fn.jobstart({ vim.fn.exepath("bash"), "-c", compile .. " && " .. run }, {
    term = true,
    cwd = root,
    on_exit = cleanup,
  })
  if job <= 0 then
    cleanup()
    return vim.notify("Java 终端启动失败", vim.log.levels.ERROR)
  end
  vim.cmd.startinsert()
  return { bufnr = buf, job_id = job, output = output }
end

local keywords = {}
for word in
  (
    "abstract assert boolean break byte case catch char class const continue default do double else enum "
    .. "extends final finally float for goto if implements import instanceof int interface long native new package "
    .. "private protected public return short static strictfp super switch synchronized this throw throws transient "
    .. "try void volatile while true false null _ record sealed permits var yield"
  ):gmatch("%S+")
do
  keywords[word] = true
end

function M.valid_name(name)
  if type(name) ~= "string" or name == "" or name:find("..", 1, true) or name:match("^%.") or name:match("%.$") then
    return false
  end
  for part in name:gmatch("[^.]+") do
    if not part:match("^[A-Za-z_$][A-Za-z0-9_$]*$") or keywords[part] then
      return false
    end
  end
  return true
end

-- 四种模板共用一个入口，不自动修改用户打开的空文件。
function M.generate(kind)
  assert(vim.tbl_contains({ "class", "interface", "enum", "record" }, kind))
  local file = vim.api.nvim_buf_get_name(0)
  local package_name = vim.bo.filetype == "java" and require("languages.java.syntax").package(0) or nil
  local root = file ~= "" and project.source_root(file, package_name) or vim.fn.getcwd()
  if vim.bo.filetype ~= "java" then
    local build_root = project.root()
    root = build_root and (build_root .. "/src/main/java") or root
  end
  root = root or vim.fs.dirname(file)
  vim.ui.input(
    { prompt = "生成 " .. kind .. "（完整类名）: ", default = package_name and (package_name .. ".") or "" },
    function(name)
      if not name or name == "" then
        return
      end
      if not M.valid_name(name) then
        return vim.notify("类名/包名不合法，请使用 Java 标识符，以点分隔包名", vim.log.levels.WARN)
      end
      local path = root .. "/" .. name:gsub("%.", "/") .. ".java"
      if vim.uv.fs_stat(path) or vim.fn.bufnr(path) ~= -1 then
        return vim.notify("目标文件或缓冲区已存在，未覆盖：" .. path, vim.log.levels.WARN)
      end
      local pkg, simple = name:match("^(.*)%.([^.]+)$")
      simple = simple or name
      local text = (pkg and ("package " .. pkg .. ";\n\n") or "")
        .. "public "
        .. kind
        .. " "
        .. simple
        .. (kind == "record" and "()" or "")
        .. " {\n}\n"
      vim.fn.mkdir(vim.fs.dirname(path), "p")
      local fd, err = vim.uv.fs_open(path, "wx", 420)
      if not fd then
        return vim.notify("创建失败：" .. tostring(err), vim.log.levels.ERROR)
      end
      local written, write_err = vim.uv.fs_write(fd, text, 0)
      vim.uv.fs_close(fd)
      if not written then
        return vim.notify("写入失败：" .. tostring(write_err), vim.log.levels.ERROR)
      end
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
  )
end

return M
