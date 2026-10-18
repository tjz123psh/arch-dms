-- 用完整用户配置运行；XDG_DATA/STATE/CACHE 必须指向隔离测试目录。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-"))
assert(vim.fn.stdpath("data"):match("^/tmp/nvim%-java%-"), "isolate Neovim data before running")
vim.o.columns, vim.o.lines = 180, 55
local old_clients, jobs, results = {}, {}, {}
for _, client in ipairs(vim.lsp.get_clients()) do
  old_clients[client.id] = true
end
local function check(value, label)
  assert(value, label)
  results[#results + 1] = label
  print("OK " .. label)
end
local function wait(predicate, label, timeout)
  check(vim.wait(timeout or 30000, predicate, 30), label)
end
local function put(name, text)
  local path = base .. "/" .. name
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
  return path
end
local function open(path)
  vim.cmd("stopinsert")
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end
local function client_for(buf, name)
  local client
  wait(function()
    client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
    return client and client.initialized
  end, name .. " initialized", 90000)
  return client
end
local function configs(buf, client)
  local found, failure, attempts = nil, nil, 0
  local function fetch()
    attempts = attempts + 1
    require("languages.java.debug").fetch(buf, client, function()
      return not client:is_stopped()
    end, function(err, list)
      failure = err
      if list and #list > 0 then
        found = list
      elseif attempts < 12 then
        vim.defer_fn(fetch, 1000)
      end
    end)
  end
  fetch()
  wait(function()
    return found ~= nil
  end, "current project main discovery: " .. tostring(failure), 60000)
  return found
end
local function text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function press(key)
  local map = vim.fn.maparg(key, "n", false, true)
  check(type(map.callback) == "function", key .. " is a real buffer action")
  map.callback()
end
local dap
local ok, err = xpcall(function()
  check(vim.fn.exists(":JavaRun") == 2 and vim.fn.exists(":SpringBootCreate") == 2, "global commands available")
  check(not package.loaded["languages.java.spring.wizard"], "wizard stays unloaded at startup")
  local first = put(
    "algorithm/Main.java",
    [[import java.util.Scanner;
public class Main {
  public static void main(String[] args) {
    Scanner in = new Scanner(System.in);
    System.out.println("INPUT_READY");
    int n = in.nextInt();
    int answer = n + 1;
    System.out.println("RESULT=" + answer);
  }
}]]
  )
  local a = open(first)
  local ca = client_for(a, "jdtls")
  check(ca.config.root_dir == base .. "/algorithm", "standalone LSP root is file directory")
  check(#vim.lsp.get_clients({ name = "spring-boot" }) == 0, "algorithm has no Spring language server")
  local mains = configs(a, ca)
  check(mains[1].mainClass == "Main" and mains[1].cwd == ca.config.root_dir, "standalone main has own classpath")
  local source_line = vim.api.nvim_buf_get_lines(a, 4, 5, false)[1]
  local completion = ca:request_sync("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(a) },
    position = { line = 4, character = source_line:find("println", 1, true) + 2 },
    context = { triggerKind = 1 },
  }, 10000, a)
  check(
    completion and not completion.err and vim.inspect(completion.result):find("println", 1, true),
    "Java completion offers println"
  )
  vim.cmd("edit!")
  wait(function()
    return vim.lsp.get_clients({ bufnr = a, name = "jdtls" })[1] == ca
  end, "edit reload reattaches same client")
  check(#vim.lsp.get_clients({ name = "jdtls" }) == 1, "reload does not duplicate JDTLS")

  local second =
    put("other/Main.java", 'public class Main { public static void main(String[] a) { System.out.println("OTHER"); } }')
  local b = open(second)
  local cb = client_for(b, "jdtls")
  check(cb.id ~= ca.id and cb.config.root_dir == base .. "/other", "second project gets distinct client")
  check(configs(b, cb)[1].cwd == cb.config.root_dir, "same-name class stays in second project")
  local empty = open(put("algorithm/Empty.java", ""))
  client_for(empty, "jdtls")
  check(text(empty) == "", "empty algorithm not filled with package")

  open(first)
  dap = require("languages.java.debug").ensure()
  vim.api.nvim_win_set_cursor(0, { 7, 0 })
  dap.toggle_breakpoint()
  press("<F5>")
  local term
  wait(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == "terminal" and text(buf):find("INPUT_READY", 1, true) then
        term = buf
        return true
      end
    end
    return false
  end, "F5 launched Java with a real input terminal", 60000)
  local job = assert(vim.b[term].terminal_job_id)
  jobs[#jobs + 1] = job
  vim.fn.chansend(job, "41\n")
  wait(function()
    return dap.session() and dap.session().current_frame ~= nil
  end, "Java breakpoint hit")
  local session = dap.session()
  check(session.current_frame.line == 7, "breakpoint stopped at requested source line")
  local value
  session:request(
    "evaluate",
    { expression = "n", context = "watch", frameId = session.current_frame.id },
    function(e, result)
      if not e then
        value = result.result
      end
    end
  )
  wait(function()
    return value ~= nil
  end, "debugger reads local variable")
  check(value == "41", "debugger sees terminal input value")
  dap.continue()
  wait(function()
    return text(term):find("RESULT=42", 1, true) ~= nil and not dap.session()
  end, "debuggee continued and exited")
end, debug.traceback)
if dap and dap.session() then
  dap.terminate()
  vim.wait(3000, function()
    return dap.session() == nil
  end, 30)
end
for _, job in ipairs(jobs) do
  if vim.fn.jobwait({ job }, 0)[1] == -1 then
    pcall(vim.fn.jobstop, job)
  end
end
for _, client in ipairs(vim.lsp.get_clients()) do
  if not old_clients[client.id] then
    client:stop(true)
  end
end
vim.wait(5000, function()
  for _, client in ipairs(vim.lsp.get_clients()) do
    if not old_clients[client.id] then
      return false
    end
  end
  return true
end, 30)
vim.fn.writefile({ vim.json.encode({ ok = ok, error = err, checks = results }) }, base .. "/runtime-result.json")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS " .. #results .. " complete-configuration Java runtime checks; test clients/jobs stopped")
vim.cmd("qa!")
