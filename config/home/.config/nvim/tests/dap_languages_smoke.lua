-- 完整配置；仅编译运行本轮临时目录中的无依赖程序。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-") and vim.fn.stdpath("data"):match("^/tmp/nvim%-java%-"))
local dap = require("dap")
vim.v.errmsg = ""
local clients = {}
for _, c in ipairs(vim.lsp.get_clients()) do
  clients[c.id] = true
end
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
  print("OK " .. label)
end
local function wait(fn, label)
  check(vim.wait(30000, fn, 30), label)
end
local specs = {
  {
    name = "c",
    file = "main.c",
    type = "codelldb",
    line = 3,
    code = "int main(void) {\n  int value=41;\n  value += 1;\n  return value==42 ? 0 : 1;\n}\n",
    compiler = { "cc", "-g", "-O0" },
  },
  {
    name = "cpp",
    file = "main.cpp",
    type = "codelldb",
    line = 3,
    code = "int main() {\n  int value=41;\n  value += 1;\n  return value==42 ? 0 : 1;\n}\n",
    compiler = { "c++", "-g", "-O0" },
  },
  {
    name = "rust",
    file = "main.rs",
    type = "codelldb",
    line = 3,
    code = "fn main() {\n  let mut value=41;\n  value += 1;\n  assert_eq!(value,42);\n}\n",
    compiler = { "rustc", "-g", "-C", "opt-level=0" },
  },
  {
    name = "go",
    file = "main.go",
    type = "delve",
    line = 4,
    code = "package main\nfunc main() {\n  value := 41\n  value++\n  if value != 42 { panic(value) }\n}\n",
  },
}
local ok, err = xpcall(function()
  for _, spec in ipairs(specs) do
    local dir = base .. "/" .. spec.name
    vim.fn.mkdir(dir, "p")
    local file, exe = dir .. "/" .. spec.file, dir .. "/app"
    vim.fn.writefile(vim.split(spec.code, "\n", { plain = true }), file)
    if spec.name == "go" then
      vim.fn.writefile({ "module example.com/dapcheck", "go 1.20" }, dir .. "/go.mod")
    end
    local args = spec.compiler and vim.list_extend(vim.deepcopy(spec.compiler), { file, "-o", exe })
      or { "go", "build", "-gcflags=all=-N -l", "-o", exe, file }
    local build = vim
      .system(
        args,
        { cwd = dir, text = true, timeout = 60000, env = { GOPROXY = "off", GOSUMDB = "off", GOTOOLCHAIN = "local" } }
      )
      :wait()
    check(build.code == 0, spec.name .. " compiled: " .. (build.stderr or ""))
    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.cmd.edit(vim.fn.fnameescape(file))
    dap.clear_breakpoints()
    vim.api.nvim_win_set_cursor(0, { spec.line, 0 })
    dap.toggle_breakpoint()
    dap.run({
      type = spec.type,
      request = "launch",
      name = "Isolated " .. spec.name,
      program = exe,
      cwd = dir,
      mode = spec.name == "go" and "exec" or nil,
      stopOnEntry = false,
    })
    wait(function()
      return dap.session() and dap.session().current_frame ~= nil
    end, spec.name .. " breakpoint reached")
    local session = dap.session()
    check(session.current_frame.line == spec.line, spec.name .. " correct source line")
    local value
    session:request(
      "evaluate",
      { expression = "value", frameId = session.current_frame.id, context = "watch" },
      function(e, result)
        if not e then
          value = result.result
        end
      end
    )
    wait(function()
      return value ~= nil
    end, spec.name .. " variable read")
    check(value == "41", spec.name .. " variable equals 41: " .. tostring(value))
    dap.continue()
    wait(function()
      return dap.session() == nil
    end, spec.name .. " debuggee exited")
    check(vim.v.errmsg == "", spec.name .. " no asynchronous callback error: " .. vim.v.errmsg)
  end
end, debug.traceback)
if dap.session() then
  dap.terminate()
  vim.wait(3000, function()
    return not dap.session()
  end, 30)
end
for _, c in ipairs(vim.lsp.get_clients()) do
  if not clients[c.id] then
    c:stop(true)
  end
end
vim.wait(3000, function()
  return #vim.lsp.get_clients() == 0
end, 30)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS " .. checks .. " real C/C++/Rust/Go debugger assertions")
vim.cmd("qa!")
