-- Java 专用终端：按「真实项目路径 + 用途 + 主类」持有对象，不复用通用终端 1/2/3。
local M = {}
local owned = {}
local reserved = {}

local function shell_exited(term)
  if not term.job_id then
    return term.bufnr ~= nil
  end
  local ok, status = pcall(vim.fn.jobwait, { term.job_id }, 0)
  return not ok or status[1] ~= -1
end

local function available(term)
  local registered = require("toggleterm.terminal").get(term.id, true)
  return (not registered or registered == term) and not shell_exited(term)
end

function M.get(root, kind, main)
  local terms = require("toggleterm.terminal")
  root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
  local key = root .. "\0" .. kind .. "\0" .. (main or "")
  local term = owned[key]
  if term then
    if available(term) then
      return term
    end
    -- exit/Ctrl-D 后保留旧缓冲区的输出，但给后续任务分配新对象，不能向死 channel 发送。
    -- 用户关掉旧终端后该编号可能已被其它终端占用，绝不抢回或向它发 Ctrl-C。
  end
  local id = 4
  while reserved[id] or terms.get(id, true) do
    id = id + 1
  end
  term = terms.Terminal:new({
    id = id,
    dir = root,
    direction = "horizontal",
    display_name = (kind == "build" and "Java 构建: " or "Spring: ")
      .. vim.fn.fnamemodify(root, ":t")
      .. (main and (" / " .. main) or ""),
    close_on_exit = false,
    on_stdout = function(t, _, data)
      -- 仅保留本次启动输出，避免「全部启动」误读上次的 Started；限制内存占用。
      t._java_output = ((t._java_output or "") .. table.concat(data or {}, "\n")):sub(-65536)
    end,
  })
  term._java_root = root
  owned[key], reserved[id] = term, term
  return term
end

local function process_busy(term)
  if not term.job_id then
    return false
  end
  local ok, pid = pcall(vim.fn.jobpid, term.job_id)
  if not ok or not pid or pid == 0 then
    return false
  end
  local file = io.open("/proc/" .. pid .. "/task/" .. pid .. "/children", "r")
  if not file then
    return true -- 无法确认是否空闲时，不向旧进程输入命令。
  end
  local children = file:read("*a")
  file:close()
  return children ~= nil and children:match("%S") ~= nil
end

function M.busy(term)
  return term._java_dispatching or term._java_restarting or process_busy(term)
end

--- 保留输出；构建忙时拒绝叠加，应用重启等待旧进程退出再发新命令。
function M.run(term, command, restart)
  if not available(term) then
    vim.notify("Java 终端已被替换，请重新运行", vim.log.levels.WARN)
    return false
  end
  if term._java_dispatching or term._java_restarting then
    vim.notify("终端 " .. term.id .. " 正在启动或重启，请稍后再试", vim.log.levels.WARN)
    return false
  end
  local function execute()
    -- shutdown 后原 id 可能被其它终端占用；不能借旧对象的 id 操作新终端。
    if not available(term) then
      vim.notify("Java 终端编号已被其它终端占用，请重新运行", vim.log.levels.WARN)
      return false
    end
    term._java_output = ""
    term._java_dispatching = true
    local ok, err = pcall(function()
      term:open(nil, "horizontal")
      -- 不相信常驻 shell 的当前目录（用户可能手动 cd 过），每次显式进入捕获的项目根。
      term:send("cd -- " .. vim.fn.shellescape(term._java_root) .. " && " .. command, false)
    end)
    if not ok then
      term._java_dispatching = nil
      vim.notify("Java 终端启动失败：" .. tostring(err), vim.log.levels.ERROR)
      return false
    end
    vim.defer_fn(function()
      term._java_dispatching = nil
    end, 300)
    return true
  end
  if not process_busy(term) then
    return execute()
  end
  if not restart then
    term:open(nil, "horizontal")
    vim.notify("终端 " .. term.id .. " 的构建/测试尚未结束，未发送新命令", vim.log.levels.WARN)
    return false
  end
  term._java_output = ""
  term._java_restarting = true
  local sent = pcall(vim.fn.chansend, term.job_id, string.char(3))
  if not sent then
    term._java_restarting = nil
    vim.notify("无法停止旧 Java 进程，未发送启动命令", vim.log.levels.ERROR)
    return false
  end
  local tries = 0
  local function wait_for_shell()
    tries = tries + 1
    if not process_busy(term) then
      term._java_restarting = nil
      execute()
    elseif tries >= 100 then
      term._java_restarting = nil
      vim.notify("旧 Java 进程 10 秒内未退出，请手动停止后重试", vim.log.levels.WARN)
    else
      vim.defer_fn(wait_for_shell, 100)
    end
  end
  vim.defer_fn(wait_for_shell, 100)
  return true
end

return M
