-- nvim -u NONE -i NONE -n --headless -l tests/java_workflows.lua
-- 仅运行 Lua/Java 解析器及模拟接口，不启动 LSP、Maven、Gradle 或业务程序。
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.treesitter.language.add("java", { path = vim.env.HOME .. "/.local/share/nvim/site/parser/java.so" })
local count = 0
local function eq(actual, expected, label)
  assert(
    vim.deep_equal(actual, expected),
    label .. "\nexpected=" .. vim.inspect(expected) .. "\nactual=" .. vim.inspect(actual)
  )
  count = count + 1
end
local notices, timers = {}, {}
vim.notify = function(msg)
  notices[#notices + 1] = msg
end
vim.defer_fn = function(fn, ms)
  timers[#timers + 1] = { fn = fn, ms = ms }
end
local function tick(ms)
  local pending = timers
  timers = {}
  for _, timer in ipairs(pending) do
    if timer.ms == ms then
      timer.fn()
    else
      timers[#timers + 1] = timer
    end
  end
end
local function buffer(path, text, needle)
  vim.cmd("enew!")
  local b = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(b, path)
  local lines = vim.split(text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  for i, line in ipairs(lines) do
    if line:find(needle, 1, true) then
      vim.api.nvim_win_set_cursor(0, { i, line:find(needle, 1, true) - 1 })
      break
    end
  end
  return b
end
local selector = require("languages.java.syntax").selector
local source = [[package demo;
class ExampleTest {
  @Test void alpha() { alphaBody(); }

  @ParameterizedTest
  @CsvSource({"name, 2"})
  void beta(
    String name,
    int number
  ) throws Exception
  {
    assertEquals(call(name), number); // beta body
  }

  @Test void inline() { inlineBody(); }
  @Nested class Inner {
    @Test void nested() { nestedBody(); }
  }
  void lambdaTest() {
    Runnable task = () -> { lambdaBody(); };
  }
  void anonymousTest() {
    Runnable task = new Runnable() {
      public void run() { anonymousBody(); }
    };
  }
  void localTest() {
    class Local { void local() { localBody(); } }
  }
  ExampleTest() { constructorBody(); }
}]]
local seq = 0
local function ast(text, needle, expected, method)
  seq = seq + 1
  buffer("/mock/ast/" .. seq .. "/ExampleTest.java", text, needle)
  eq(selector(0, method ~= false), expected, "AST " .. needle)
end
ast(source, "alphaBody", "demo.ExampleTest#alpha")
ast(source, "assertEquals", "demo.ExampleTest#beta")
ast(source, "void beta", "demo.ExampleTest#beta")
ast(source, "String name,", "demo.ExampleTest#beta")
ast(source, "@ParameterizedTest", "demo.ExampleTest#beta")
ast(source, "@CsvSource", "demo.ExampleTest#beta")
ast(source, "inlineBody", "demo.ExampleTest#inline")
ast(source, "nestedBody", "demo.ExampleTest$Inner#nested")
ast(source, "nestedBody", "demo.ExampleTest$Inner", false)
ast(source, "package demo", "demo.ExampleTest", false)
ast(source, "lambdaBody", "demo.ExampleTest#lambdaTest")
ast(source, "anonymousBody", nil)
ast(source, "localBody", nil)
ast(source, "constructorBody", nil)
ast(source, "class ExampleTest", nil)
-- 方法间空行不应落到上一个测试。
seq = seq + 1
buffer("/mock/ast/" .. seq .. "/ExampleTest.java", source, "class ExampleTest")
vim.api.nvim_win_set_cursor(0, { 4, 0 })
eq(selector(0, true), nil, "blank between methods")
ast(
  [[class ExampleTest {
  @Test void test() {
    String s = "void bogus() { }"; /* body marker */
  }
}]],
  "body marker",
  "ExampleTest#test"
)
ast(
  [[class ExampleTest {
  @Test void test() {
    int broken = ; // bad syntax
  }
}]],
  "bad syntax",
  nil
)
ast(
  [[package demo;
class ExampleTest {
  @Test void good() { goodBody(); }
  void bad() { int broken = ; }
}]],
  "goodBody",
  "demo.ExampleTest#good"
)
ast(
  [[class ExampleTest {
  static { class Local { void test() { staticLocalBody(); } } }
}]],
  "staticLocalBody",
  nil
)
ast(
  [[class ExampleTest {
  { class Local { void test() { instanceLocalBody(); } } }
}]],
  "instanceLocalBody",
  nil
)
local get_parser = vim.treesitter.get_parser
vim.treesitter.get_parser = function()
  error("missing parser")
end
eq(selector(0, true), nil, "missing parser fails closed")
vim.treesitter.get_parser = get_parser

-- 终端对象模拟：保留真实 ownership/busy/restart 逻辑。
local registry, sent, controls, processes = { [4] = { hidden = true } }, {}, {}, {}
local Terminal = {}
function Terminal:new(opts)
  opts.id = assert(opts.id)
  return setmetatable(opts, { __index = Terminal })
end
function Terminal:open()
  registry[self.id] = self
  self.job_id = self.job_id or (1000 + self.id)
  processes[self.job_id] = processes[self.job_id] or ""
end
function Terminal:send(command)
  sent[#sent + 1] = { id = self.id, cmd = command }
end
package.loaded["toggleterm.terminal"] = {
  Terminal = Terminal,
  get = function(id)
    return registry[id]
  end,
}
local terminals = require("languages.java.terminal")
local old_open, old_jobpid, old_chansend, old_jobwait = io.open, vim.fn.jobpid, vim.fn.chansend, vim.fn.jobwait
vim.fn.jobwait = function()
  return { -1 }
end
io.open = function(path, mode)
  local pid = tonumber(path:match("^/proc/(%d+)/task/%d+/children$"))
  if pid and processes[pid] ~= nil then
    return {
      read = function()
        return processes[pid]
      end,
      close = function() end,
    }
  end
  return old_open(path, mode)
end
vim.fn.jobpid = function(id)
  return id
end
vim.fn.chansend = function(id, data)
  controls[#controls + 1] = { id = id, data = data }
  return #data
end
local app_a = terminals.get("/mock/a", "spring", "demo.App")
local app_b = terminals.get("/mock/b", "spring", "demo.App")
local build_a = terminals.get("/mock/a", "build")
eq(app_a.id, 5, "skip occupied hidden and reserved general terminals")
eq(terminals.get("/mock/a", "spring", "demo.App"), app_a, "stable main identity")
eq(app_a.id ~= app_b.id and app_a.id ~= build_a.id, true, "roles and roots isolated")
local ids = {}
for i = 1, 12 do
  local term = terminals.get("/mock/a", "spring", "demo.App" .. i)
  eq(ids[term.id], nil, "no modulo collisions " .. i)
  ids[term.id] = true
end
local displaced = terminals.get("/mock/a", "spring", "demo.Displaced")
registry[displaced.id] = { hidden = true }
eq(terminals.run(displaced, "do-not-run", true), false, "do not send to foreign terminal")
eq(terminals.get("/mock/a", "spring", "demo.Displaced").id ~= displaced.id, true, "reallocate displaced reservation")
eq(terminals.run(app_a, "spring-command", true), true, "start owned app")
eq(terminals.run(app_a, "too-soon", true), false, "guard dispatch race")
tick(300)
processes[app_a.job_id] = "2222 "
eq(terminals.run(build_a, "test-command", false), true, "tests run alongside app")
eq(sent[#sent].id == build_a.id and sent[#sent - 1].id == app_a.id, true, "different target terminal")
tick(300)
processes[build_a.job_id] = "3333 "
local before = #sent
eq(terminals.run(build_a, "do-not-queue", false), false, "busy build refuses input")
eq(#sent, before, "busy build sends nothing")
eq(#controls, 0, "busy build never interrupts app")
app_a._java_output = "Started App OLD"
eq(terminals.run(app_a, "restarted-command", true), true, "request restart")
eq(#sent, before, "restart waits for process exit")
eq(controls[#controls].id, app_a.job_id, "interrupt only owned process")
eq(app_a._java_output, "", "clear old readiness output")
tick(100)
eq(#sent, before, "still waits while process exists")
processes[app_a.job_id] = ""
tick(100)
eq(sent[#sent].cmd:find("restarted-command", 1, true) ~= nil, true, "restart after exit")
tick(300)
app_a.on_stdout(app_a, 0, { "Started App", "fresh" })
eq(app_a._java_output, "Started App\nfresh", "collect only new output")
local stuck = terminals.get("/mock/stuck", "spring", "Stuck")
stuck:open()
processes[stuck.job_id] = "4444 "
before = #sent
terminals.run(stuck, "must-not-run", true)
for _ = 1, 100 do
  tick(100)
end
eq(#sent, before, "restart timeout never injects command")
eq(stuck._java_restarting, nil, "restart timeout releases guard")
local spaced = terminals.get("/mock/project with space", "build")
terminals.run(spaced, "test", false)
eq(sent[#sent].cmd, "cd -- '/mock/project with space' && test", "quote project path")
io.open, vim.fn.jobpid, vim.fn.chansend, vim.fn.jobwait = old_open, old_jobpid, old_chansend, old_jobwait

-- 真 discovery 模块 + 假 LSP transport：每一步必须使用捕获的 client/buffer。
local discovery = require("languages.java.debug")
local requests, outcomes = {}, {}
local alive = true
local client = { id = 41, config = { root_dir = "/mock/a" } }
function client:request(method, params, callback, bufnr)
  requests[#requests + 1] = { owner = self.id, method = method, params = params, callback = callback, bufnr = bufnr }
  return true, #requests
end
local function fetch()
  requests, outcomes = {}, {}
  discovery.fetch(12, client, function()
    return alive
  end, function(err, configs)
    outcomes[#outcomes + 1] = { err = err, configs = configs }
  end)
end
local function respond(i, value, err)
  requests[i].callback(err, value)
end
fetch()
respond(1, { { mainClass = "a.App", projectName = "a" } })
respond(2, "/jdk/bin/java")
respond(3, true)
respond(4, { {}, { "/mock/a/classes" } })
eq(#outcomes, 1, "discovery finishes once")
eq(outcomes[1].configs[1].cwd, "/mock/a", "discovery exact LSP cwd")
eq(outcomes[1].configs[1].vmArgs, "--enable-preview", "retain preview flag")
for _, req in ipairs(requests) do
  eq({ req.owner, req.bufnr }, { 41, 12 }, "all requests pinned")
end
tick(15000)
eq(#outcomes, 1, "completed discovery ignores watchdog")
fetch()
respond(1, {}, { message = "broken" })
eq(outcomes[1].err:find("broken", 1, true) ~= nil, true, "LSP error completes")
fetch()
respond(1, { { mainClass = "a.App" } })
alive = false
respond(2, "/jdk/bin/java")
eq(#requests, 2, "detach prevents subsequent requests")
eq(#outcomes, 1, "detach completes")
alive = true
fetch()
tick(15000)
eq(#outcomes, 1, "missing callback timeout completes")
respond(1, {})
eq(#outcomes, 1, "late callback ignored")
fetch()
respond(1, {})
eq(outcomes[1].configs, {}, "empty main list")

-- 调用真实 Java spec 的键位，模拟异步扫描，覆盖 A/B 切换、重复操作和选择取消。
vim.g.mapleader = " "
local current_clients, launches, scans = {}, {}, {}
local active_session = false
local continues = 0
local dap = {
  adapters = {},
  configurations = { java = { { mainClass = "stale.App", cwd = "/mock/stale" } } },
  session = function()
    return active_session
  end,
  continue = function()
    continues = continues + 1
  end,
  run = function(config)
    launches[#launches + 1] = config
  end,
}
package.loaded["dap"] = dap
package.loaded["jdtls"] = setmetatable({
  start_or_attach = function()
    return 1
  end,
}, {
  __index = function()
    return function() end
  end,
})
package.loaded["blink.cmp"] = {
  get_lsp_capabilities = function()
    return {}
  end,
}
package.loaded["spring_boot"] = {
  java_extensions = function()
    return {}
  end,
}
package.loaded["languages.shared.lsp"] = function() end
discovery.fetch = function(buf, cli, valid, callback)
  scans[#scans + 1] = { buf = buf, client = cli, valid = valid, callback = callback }
end
package.loaded["languages.java.ui"] = { setup = function() end }
vim.lsp.get_clients = function(opts)
  return current_clients[opts and opts.bufnr or vim.api.nvim_get_current_buf()] or {}
end
local workflow_runs = {}
package.loaded["languages.java.terminal"] = {
  get = function(dir, kind, main)
    return { id = 20, root = dir, kind = kind, main = main }
  end,
  busy = function()
    return false
  end,
  run = function(term, cmd)
    workflow_runs[#workflow_runs + 1] = { term = term, cmd = cmd }
    return true
  end,
}
local spring = require("languages.java.spring.run")
spring.scan = function()
  return { { fqcn = "demo.App", simple = "App", pkg = "demo" } }
end
spring.configuration = function()
  return { flag = "main.class" }
end
local spec = require("languages.java").plugins[1]
spec.config(nil, spec.opts)
local function java_buffer(name, id)
  local b = buffer("/mock/" .. name .. "/App.java", "class App {}", "class")
  current_clients[b] = { { id = id, config = { root_dir = "/mock/" .. name } } }
  vim.bo[b].filetype = "java"
  return b
end
local a = java_buffer("a", 1)
local b = java_buffer("b", 2)
local function press(key, buf)
  vim.api.nvim_set_current_buf(buf)
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert(type(mapping.callback) == "function", "missing mapping " .. key)
  mapping.callback()
end
local function config(name)
  return { mainClass = name .. ".App", cwd = "/mock/" .. name, projectName = name }
end
press("<F5>", a)
local old = scans[#scans]
press("<F5>", b)
old.callback(nil, { config("a") })
eq(#launches, 0, "stale A callback discarded")
scans[#scans].callback(nil, { config("b") })
eq(launches[1].cwd, "/mock/b", "B launches only B")
eq(dap.configurations.java[1].mainClass, "stale.App", "does not overwrite custom/global configurations")
press("<F5>", a)
local first = scans[#scans]
press("<F5>", a)
first.callback(nil, { config("a") })
eq(#launches, 1, "double F5 discards earlier scan")
local select_callback
vim.ui.select = function(_, _, callback)
  select_callback = callback
end
scans[#scans].callback(nil, { config("a"), config("other") })
select_callback(nil)
eq(#launches, 1, "picker cancellation")
press("<F5>", a)
scans[#scans].callback(nil, { config("a"), config("other") })
select_callback(config("a"))
select_callback(config("a"))
eq(#launches, 2, "picker launches at most once")
press("<F5>", a)
old = scans[#scans]
current_clients[a] = { { id = 99, config = { root_dir = "/mock/a" } } }
old.callback(nil, { config("a") })
eq(#launches, 2, "same-root restarted client invalidates old scan")
press("<F5>", a)
old = scans[#scans]
active_session = true
press("<F5>", a)
old.callback(nil, { config("a") })
eq(continues, 1, "active F5 continues")
eq(#launches, 2, "continue invalidates pending launch")
active_session = false
press("<leader>Jd", b)
scans[#scans].callback(nil, { config("b") })
eq(#launches, 2, "Jd scans current project without launching")
press("<F5>", a)
scans[#scans].callback(nil, {})
local scan_count = #scans
vim.api.nvim_set_current_buf(b)
tick(2500)
eq(#scans, scan_count, "retry stops after changing buffer")
-- 验证实际快捷键到构建命令的连接，包括内部类 $ 的 shell 转义。
local real_stat = vim.uv.fs_stat
local gradle = false
require("languages.java.project").tool = function(dir)
  return { root = dir, kind = gradle and "gradle" or "maven", bin = { gradle and "gradle" or "mvn" } }
end
vim.fs.root = function()
  return "/mock/workflow"
end
vim.uv.fs_stat = function(path, ...)
  if path == "/mock/workflow/pom.xml" or (gradle and path == "/mock/workflow/build.gradle") then
    return { type = "file" }
  end
  return real_stat(path, ...)
end
vim.api.nvim_set_current_buf(a)
vim.api.nvim_buf_set_lines(
  a,
  0,
  -1,
  false,
  { "package demo;", "class Outer {", "  class Inner {", "    @Test void test() { check(); }", "  }", "}" }
)
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<leader>Jt", a)
eq(workflow_runs[#workflow_runs].cmd, "'mvn' 'test' '-Dtest=demo.Outer$Inner#test'", "Maven selector shellescaped")
eq(workflow_runs[#workflow_runs].term.kind, "build", "test uses build owner")
gradle = true
press("<leader>Jt", a)
eq(
  workflow_runs[#workflow_runs].cmd,
  "'gradle' 'test' '--tests' 'demo.Outer$Inner.test'",
  "Gradle selector shellescaped"
)
gradle = false
press("<leader>sr", a)
eq(workflow_runs[#workflow_runs].term.kind, "spring", "Spring uses separate owner")
eq(workflow_runs[#workflow_runs].term.main, "demo.App", "Spring owner is fqcn not scan index")
vim.uv.fs_stat = real_stat
print("PASS " .. count .. " Java workflow assertions")
vim.cmd("qa!")
