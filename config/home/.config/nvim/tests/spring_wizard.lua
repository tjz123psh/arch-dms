-- nvim -u NONE -i NONE -n --headless -l tests/spring_wizard.lua
-- 纯 Lua + 模拟 UI/进程/文件系统；不联网，不启动插件、构建工具或业务。
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local count = 0
local function eq(actual, expected, label)
  assert(
    vim.deep_equal(actual, expected),
    label .. "\nexpected=" .. vim.inspect(expected) .. "\nactual=" .. vim.inspect(actual)
  )
  count = count + 1
end
local function fails(fn, pattern, label)
  local ok, err = pcall(fn)
  eq(ok, false, label)
  eq(tostring(err):find(pattern, 1, true) ~= nil, true, label .. " diagnostic")
end
local function pack(...)
  return { n = select("#", ...), ... }
end
local function upvalue(fn, key, seen)
  seen = seen or {}
  if seen[fn] then
    return
  end
  seen[fn] = true
  local children = {}
  for i = 1, math.huge do
    local name, value = debug.getupvalue(fn, i)
    if not name then
      break
    end
    if name == key then
      return value
    end
    if type(value) == "function" then
      children[#children + 1] = value
    end
  end
  for _, child in ipairs(children) do
    local found = upvalue(child, key, seen)
    if found ~= nil then
      return found
    end
  end
end
local queue, notices, timers, picker_records, commands = {}, {}, {}, {}, {}
vim.schedule = function(fn)
  queue[#queue + 1] = fn
end
vim.notify = function(text, level)
  notices[#notices + 1] = { text = text, level = level }
end
local function drain()
  local n = 0
  while #queue > 0 do
    n = n + 1
    assert(n < 1000, "unexpected scheduled callback loop")
    table.remove(queue, 1)()
  end
end
local function start(fn)
  local task = {}
  task.co = coroutine.create(function()
    task.result = pack(pcall(fn))
  end)
  assert(coroutine.resume(task.co))
  return task
end
local function result(task)
  drain()
  eq(coroutine.status(task.co), "dead", "coroutine completed")
  return task.result
end
vim.uv.new_timer = function()
  local timer = {}
  function timer:start(_, interval, cb)
    self.interval, self.cb, self.running = interval, cb, true
  end
  function timer:stop()
    self.running = false
  end
  function timer:close()
    self.closed = true
  end
  timers[#timers + 1] = timer
  return timer
end
local defaults = {
  win = {
    input = {
      keys = { ["<cr>"] = { "confirm", mode = { "n", "i" } }, ["<esc>"] = "close", ["<Tab>"] = "select_and_next" },
    },
    list = { keys = { ["<cr>"] = "confirm", ["<esc>"] = "close", ["j"] = "list_down" } },
  },
}
package.loaded["snacks.picker.config.defaults"] = { defaults = defaults }
local List = {
  render = function(self)
    return self.dirty
  end,
}
package.loaded["snacks.picker.core.list"] = List
local ui, apply_count = require("core.ui"), 0
local apply = ui.apply
ui.apply = function()
  apply_count = apply_count + 1
  apply()
end
local wizard = require("languages.java.spring.wizard")
eq(apply_count, 0, "require does not initialize UI")
eq(wizard.setup, nil, "command registration belongs to the language declaration consumer")
eq(vim.fn.exists(":SpringBootCreate"), 0, "module does not register commands")
local function helper(key)
  return assert(upvalue(wizard.create, key), "missing helper " .. key)
end
local bridge, CANCEL = helper("bridge"), helper("CANCEL")

local sync = start(function()
  return bridge(function(done)
    done(nil, "sync", nil)
    done("duplicate")
  end)
end)
eq(result(sync), { n = 4, true, nil, "sync", nil }, "synchronous bridge preserves nil returns and first result")
local first, second, completions = nil, nil, 0
local async = start(function()
  local a = bridge(function(done)
    first = done
  end)
  local b = bridge(function(done)
    second = done
  end)
  completions = completions + 1
  return a, b
end)
eq(coroutine.status(async.co), "suspended", "asynchronous bridge yields")
first("one")
eq(coroutine.status(async.co), "suspended", "next bridge pending")
first("late duplicate")
eq(completions, 0, "old completion cannot resume next bridge")
second("two")
second("duplicate")
eq(result(async), { n = 3, true, "one", "two" }, "asynchronous bridge returns once")
eq(completions, 1, "single completion")
local spawn = start(function()
  return bridge(function()
    error("spawn error", 0)
  end)
end)
eq(result(spawn), { n = 2, false, "spawn error" }, "caller exception escapes without hanging")

local valid_package, sanitize = helper("valid_package"), helper("sanitize_package")
for _, name in ipairs({ "com.example.demo", "org._internal.v2", "a.$b", "pkg.__", "record.var.module" }) do
  eq(valid_package(name), true, "valid Java package " .. name)
end
for _, name in ipairs({
  "",
  "1bad..pkg",
  "a-b.c",
  "com..demo",
  ".demo",
  "demo.",
  "a.2b",
  "a/b",
  "a\\b",
  "a b",
  "a.class",
  "a.true",
  "a.null",
  "a._",
  "a;bad",
  "包.名",
}) do
  eq(valid_package(name), false, "invalid supported package " .. name)
end
eq(valid_package(nil), false, "nil package")
eq(sanitize("1bad..class.a-b._"), "_1bad._pkg.class_.a_b.__", "sanitize each package segment")
eq(valid_package(sanitize("1bad..class.a-b._")), true, "suggested package is valid")
for _, name in ipairs({ "demo", "demo-api", "my.app", "_demo" }) do
  eq(helper("valid_segment")(name), true, "valid segment")
end
for _, name in ipairs({ "", ".", "..", "../escape", "a/b", "-bad", "a b" }) do
  eq(helper("valid_segment")(name), false, "invalid segment")
end

local metadata = {
  type = {
    values = {
      { id = "gradle-project", action = "/starter.zip" },
      { id = "maven-build", action = "/pom.xml" },
      { id = "maven-project", action = "/starter.zip" },
      { id = "gradle-project-kotlin", action = "/starter.zip" },
      { action = "/starter.zip" },
    },
  },
  language = { values = { { id = "java" }, { id = "kotlin" } } },
  javaVersion = { values = { { id = "17" }, { id = "21" }, { id = "25" } } },
  bootVersion = {
    values = {
      { id = "4.2.0.M2" },
      { id = "4.1.1.RELEASE" },
      { id = "4.0.8.RELEASE" },
      { id = "4.1.1" },
      { id = "4.2.0.BUILD-SNAPSHOT" },
      { id = "4.3.0-RC1" },
      { id = "4.3.0-M5" },
      { id = "3.9.12.RELEASE" },
      { id = 27 },
      "bad",
    },
  },
  packaging = { values = { { id = "jar" }, { id = "war" } } },
  dependencies = {
    values = {
      { name = "Web", values = { { id = "web", name = "Spring Web", description = "HTTP REST MVC" } } },
      {
        name = "Developer Tools",
        values = { { id = "devtools", name = "DevTools", description = "Reload" }, { id = "web", name = "duplicate" } },
      },
    },
  },
}
local builds = helper("build_options")(metadata)
eq(
  vim.tbl_map(function(v)
    return v.type
  end, builds),
  { "maven-project", "gradle-project-kotlin" },
  "project archive types only; Kotlin DSL mapping"
)
eq(
  helper("build_options")({ type = { values = { { id = "gradle-project-kotlin", action = "/other" } } } }),
  {},
  "unexpected action rejected"
)
local boots = helper("boot_options")(metadata)
eq(
  vim.tbl_map(function(v)
    return v.id
  end, boots),
  { "4.1.1", "4.0.8", "3.9.12", "4.3.0-M5", "4.3.0-RC1", "4.2.0.M2", "4.2.0.BUILD-SNAPSHOT" },
  "normalized stable-first numeric versions and dedup"
)
eq(boots[1].hint, "最新正式版", "newest stable label")
for _, id in ipairs({ "4.3.0-RC1", "4.3.0.RC1", "4.3.0-RC", "4.3.0-M5", "4.2.0.M1", "4.2.0.BUILD-SNAPSHOT" }) do
  eq(helper("is_prerelease")(id), true, "prerelease " .. id)
end
eq(helper("vcmp")("4.10.0", "4.9.12") > 0, true, "numeric version comparison")
eq(helper("simple_options")({ values = { x = { id = "17" } } }), {}, "non-array metadata rejected")
eq(
  helper("simple_options")({ values = { false, 17, { id = 17 }, { id = "" }, { id = "17" } } }),
  { { id = "17" } },
  "malformed metadata options ignored"
)
local deps = helper("dependency_options")(metadata)
eq(deps, {
  { id = "devtools", name = "DevTools", group = "Dev Tools", description = "Reload" },
  { id = "web", name = "Spring Web", group = "Web", description = "HTTP REST MVC" },
}, "two-level dependency list retains details, dedup, short group, sorting")
eq(
  helper("selected_ids")({ { item = { id = "web" } }, { item = { id = "devtools" } } }),
  { "web", "devtools" },
  "selected dependency array"
)
eq(helper("selected_ids")({}), {}, "zero dependencies is a valid confirmation")
fails(function()
  helper("selected_ids")({ web = true })
end, "非数组", "non-array selected rejected")
fails(function()
  helper("selected_ids")({ { id = "web" } })
end, "缺少依赖 ID", "malformed selection rejected")

local picker_hook
_G.Snacks = {
  picker = {
    pick = function(opts)
      local items = opts.finder()
      local pk = {
        opts = opts,
        list = {
          selected = {},
          current = function()
            return items[1]
          end,
        },
        closed = 0,
      }
      function pk:close()
        self.closed = self.closed + 1
        opts.on_close()
      end
      picker_records[#picker_records + 1] = { opts = opts, pk = pk, items = items }
      if picker_hook then
        return picker_hook(opts, pk, items)
      end
      return pk
    end,
  },
}
local pick = helper("pick")
local picked = start(function()
  return pick({ { id = "java", hint = "recommended" } }, "single")
end)
local record = picker_records[#picker_records]
record.opts.actions.confirm(record.pk, record.items[1])
record.opts.actions.confirm(record.pk, record.items[1])
eq(result(picked), { n = 2, true, { id = "java", hint = "recommended" } }, "confirm wins over on_close, once")
eq(record.pk.closed, 1, "picker closed once")
eq(record.opts.win.input.keys["<c-s>"].mode, { "n", "i" }, "Ctrl-S works in both modes")
eq(record.opts.win.input.keys["<Esc>"].mode, { "n", "i" }, "Escape cancels from insert mode in one press")
eq(record.opts.win.input.keys["<Tab>"], "select_and_next", "default multiselect binding retained")
eq(defaults.win.input.keys["<c-s>"], nil, "default bindings not mutated")
eq(record.opts.layout.hidden, { "preview" }, "single picker compact layout")
local cancelled = start(function()
  return pick(deps, "deps", { multiple = true })
end)
record = picker_records[#picker_records]
record.pk:close()
eq(result(cancelled)[2] == CANCEL, true, "Esc close is cancellation, not empty selection")
local empty = start(function()
  return pick({}, "deps", { multiple = true })
end)
record = picker_records[#picker_records]
eq(record.opts.show_empty, true, "empty dependency metadata remains confirmable")
eq(record.opts.layout.hidden, nil, "dependency details visible")
record.opts.actions.confirm(record.pk)
eq(result(empty), { n = 2, true, {} }, "empty dependency confirmation")
local bad = start(function()
  return pick(deps, "deps", { multiple = true })
end)
record = picker_records[#picker_records]
record.pk.list.selected = { web = true }
record.opts.actions.confirm(record.pk)
eq(result(bad)[1], false, "non-array multi aborts")
eq(tostring(bad.result[2]):find("非数组", 1, true) ~= nil, true, "non-array multi reports actual error")
eq(bad.result[2] == CANCEL, false, "metadata/structure error is not disguised as cancel")
eq(record.pk.closed, 1, "invalid selection closes picker")
local rich = start(function()
  return pick(deps, "deps", { multiple = true })
end)
record = picker_records[#picker_records]
eq(record.items[2].text:find("HTTP REST MVC", 1, true) ~= nil, true, "dependency descriptions searchable")
eq(record.items[2].text:find("Web", 1, true) ~= nil, true, "dependency groups searchable")
record.pk.list.selected = { record.items[2], record.items[1] }
record.opts.actions.confirm(record.pk)
eq(result(rich), { n = 2, true, { "web", "devtools" } }, "multiple items retained in selected order")
local long_id = string.rep("a", 42)
local long = start(function()
  return pick({ { id = long_id, name = "long", group = "AI" } }, "long", { multiple = true })
end)
record = picker_records[#picker_records]
eq(record.opts.format(record.items[1], record.pk)[2][1], long_id, "long dependency ID is not truncated")
record.pk:close()
result(long)
picker_hook = function()
  return nil
end
local missing = start(function()
  return pick(deps, "dedupe")
end)
eq(result(missing)[2] == CANCEL, true, "nil picker cannot hang")
local before_timers = #timers
picker_hook = function(opts, pk)
  opts.on_close()
  return pk
end
local instant_close = start(function()
  return pick(deps, "instant close")
end)
eq(result(instant_close)[2] == CANCEL, true, "synchronous on_close delivered")
eq(#timers, before_timers, "closed picker cannot start pulse")
picker_hook = nil
fails(function()
  pick({}, "missing version")
end, "没有可选项", "empty single picker reports metadata error")

local footer = helper("layout_footer")({ { "中ab·c", "WizKey" } }, 4, 3)
eq(
  vim.tbl_map(function(line)
    return line.text
  end, footer),
  { "中ab", "·c" },
  "footer uses actual display widths"
)
local start_pulse, stop_pulse = helper("start_pulse"), helper("stop_pulse")
vim.api.nvim_set_hl(0, "SnacksPickerCursorLine", { link = "ErrorMsg" })
vim.api.nvim_set_hl(0, "SnacksPickerListCursorLine", {})
local saved_link = vim.api.nvim_get_hl(0, { name = "SnacksPickerCursorLine", link = true })
start_pulse()
timers[#timers].cb()
stop_pulse()
local border_after_stop = vim.api.nvim_get_hl(0, { name = "WizBorder" })
drain()
eq(vim.api.nvim_get_hl(0, { name = "WizBorder" }), border_after_stop, "queued pulse does not recolor after close")
eq(
  vim.api.nvim_get_hl(0, { name = "SnacksPickerCursorLine", link = true }),
  saved_link,
  "original highlight link restored"
)
eq(vim.api.nvim_get_hl(0, { name = "SnacksPickerListCursorLine" }), {}, "empty highlight restored too")
for _, skin in ipairs({ "soft", "pink" }) do
  vim.g.picker_skin = skin
  ui.apply()
  eq(vim.api.nvim_get_hl(0, { name = "WizSel" }).fg ~= nil, true, skin .. " selection color exists")
end

local function zip_listing(entries, expected)
  local out = { "Archive: /private/starter.zip", "Zip file size: 100, number of entries: " .. (expected or #entries) }
  for _, entry in ipairs(entries) do
    out[#out + 1] = (entry.mode or "-rw-r--r--")
      .. "  2.0 unx "
      .. (entry.size or 10)
      .. " bX 2 defN 26-Oct-14 17:27 "
      .. entry.path
  end
  out[#out + 1] = #entries .. " files, 20 bytes uncompressed, 10 bytes compressed: 50%"
  return table.concat(out, "\n")
end
local archive_entries = helper("archive_entries")
eq(
  #archive_entries(zip_listing({ { path = "src/", mode = "drwxr-xr-x", size = 0 }, { path = "src/Demo.java" } })),
  2,
  "safe ZIP list accepted"
)
for _, path in ipairs({
  "../escape",
  "/absolute",
  "src/../../bad",
  "src/./x",
  "src//x",
  "C:/escape",
  "src\\x",
  "src/x\ny",
  "src/x^Jy",
}) do
  fails(function()
    archive_entries(zip_listing({ { path = path } }))
  end, "ZIP", "unsafe ZIP path " .. path)
end
for _, mode in ipairs({ "lrwxrwxrwx", "crw-r--r--", "prw-r--r--" }) do
  fails(function()
    archive_entries(zip_listing({ { path = "evil", mode = mode } }))
  end, "ZIP", "unsupported archive kind")
end
fails(function()
  archive_entries(zip_listing({ { path = "x" }, { path = "x" } }))
end, "重复", "duplicate ZIP paths")
fails(function()
  archive_entries(zip_listing({ { path = "x" }, { path = "x/y" } }))
end, "冲突", "file-directory collision")
fails(function()
  archive_entries(zip_listing({ { path = "big", size = 32 * 1024 * 1024 + 1 } }))
end, "解压量", "uncompressed size cap")
fails(function()
  archive_entries(zip_listing({ { path = "x" } }, 2))
end, "不完整", "entry count mismatch")
fails(function()
  archive_entries(zip_listing({}, 1001))
end, "条目数", "entry count cap")

-- 模拟磁盘有身份号；清理若越过本轮 mkdtemp 路径，测试立即失败。
local fs, owned, deleted, unlinked, calls, clock, serial = {}, {}, {}, {}, {}, 0, 0
local disk_parent = "/mock/projects"
local function node(kind)
  serial = serial + 1
  return { type = kind, dev = 1, ino = serial }
end
local function canonical(path)
  return vim.fs.normalize(path)
end
vim.uv.fs_realpath = function(path)
  path = canonical(path)
  return fs[path] and path or nil
end
vim.uv.fs_lstat = function(path)
  return fs[canonical(path)]
end
vim.uv.fs_stat = function(path)
  local entry = fs[canonical(path)]
  if entry and entry.type == "link" then
    return fs[entry.target]
  end
  return entry
end
vim.uv.fs_mkdtemp = function(template)
  local path = template:gsub("XXXXXX$", "test" .. (serial + 1))
  assert(not fs[path])
  fs[path] = node("directory")
  owned[path] = true
  return path
end
vim.uv.fs_mkdir = function(path)
  assert(not fs[path])
  fs[path] = node("directory")
  return true
end
vim.uv.fs_unlink = function(path)
  unlinked[#unlinked + 1] = path
  fs[path] = nil
  return true
end
vim.uv.now = function()
  return clock
end
vim.fn.delete = function(path, flags)
  assert(owned[path] and flags == "rf", "cleanup attempted unowned path " .. path)
  deleted[#deleted + 1] = path
  for file in pairs(fs) do
    if file == path or file:sub(1, #path + 1) == path .. "/" then
      fs[file] = nil
    end
  end
  return 0
end
local missing_tool
vim.fn.executable = function(tool)
  return tool == missing_tool and 0 or 1
end
local changed_dir
vim.fn.chdir = function(path)
  changed_dir = path
end
vim.fn.globpath = function(dir, pattern)
  eq(dir:sub(1, 1), "/", "main class search uses absolute directory")
  local language, ext =
    pattern:find("kotlin", 1, true) and "kotlin" or "java", pattern:find("kotlin", 1, true) and "kt" or "java"
  local path = dir .. "/src/main/" .. language .. "/com/example/demo/DemoApplication." .. ext
  return fs[path] and { path } or {}
end
vim.cmd = function(command)
  commands[#commands + 1] = command
end
local system_hook
vim.system = function(argv, opts, done)
  calls[#calls + 1] = { argv = vim.deepcopy(argv), opts = vim.deepcopy(opts) }
  assert(system_hook, "unexpected process")
  local response = system_hook(argv, opts)
  done(response)
  return {}
end
local function arg(argv, key)
  for i, value in ipairs(argv) do
    if value == key then
      return argv[i + 1]
    end
  end
end
local function query(argv)
  local out = {}
  for i, value in ipairs(argv) do
    if value == "--data-urlencode" then
      local key, data = argv[i + 1]:match("^([^=]+)=(.*)$")
      out[key] = data
    end
  end
  return out
end
local function reset_disk()
  fs, owned, deleted, unlinked, calls = {}, {}, {}, {}, {}
  fs[disk_parent] = node("directory")
  fs[disk_parent .. "/keep.zip"] = node("file")
  changed_dir, commands, notices, picker_records = nil, {}, {}, {}
end
local archive, language, download_query
local scenario
local function fake_process(argv, opts)
  if argv[#argv] == "https://start.spring.io/metadata/client" then
    eq(opts.timeout, 10000, "metadata process timeout")
    if scenario == "metadata-fail" then
      return { code = 22, stderr = "HTTP 503", stdout = "" }
    end
    if scenario == "metadata-invalid" then
      return { code = 0, stdout = "not JSON" }
    end
    return { code = 0, stdout = vim.json.encode(metadata) }
  elseif argv[1] == "curl" then
    eq(arg(argv, "--max-time"), "60", "download curl timeout")
    eq(opts.timeout, 65000, "download process timeout")
    eq(argv[2], "--disable", "curl config cannot override safeguards")
    eq(argv[#argv], "https://start.spring.io/starter.zip", "official ZIP endpoint only")
    eq(fs[disk_parent .. "/demo"], nil, "target absent during download")
    download_query = query(argv)
    language = download_query.language or "java"
    local main = "src/main/"
      .. language
      .. "/com/example/demo/DemoApplication."
      .. (language == "kotlin" and "kt" or "java")
    archive = { { path = "pom.xml" }, { path = "mvnw" }, { path = main } }
    fs[arg(argv, "--output")] = node("file")
    if scenario == "download-fail" then
      return { code = 22, stderr = "server error", stdout = "HTTP 503" }
    end
    if scenario == "download-timeout" then
      return { code = 124, stderr = "timeout", stdout = "HTTP 000" }
    end
    if scenario == "spawn-fail" then
      error("ENOENT spawning curl", 0)
    end
    return { code = 0, stdout = "HTTP 200" }
  elseif argv[1] == "unzip" and argv[2] == "-Z" then
    eq(opts.timeout, 10000, "ZIP listing timeout")
    eq(opts.env.UNZIPOPT, "", "unzip environment cannot override options")
    if scenario == "zip-traversal" then
      return { code = 0, stdout = zip_listing({ { path = "../escape" } }) }
    end
    return { code = 0, stdout = zip_listing(archive) }
  elseif argv[1] == "unzip" then
    eq(opts.timeout, 30000, "unzip extraction timeout")
    eq(argv[3], "-n", "unzip never overwrites")
    eq(fs[disk_parent .. "/demo"], nil, "target absent during extraction")
    if scenario == "unzip-fail" then
      return { code = 9, stderr = "bad ZIP" }
    end
    local tree = arg(argv, "-d")
    for _, entry in ipairs(archive) do
      fs[tree .. "/" .. entry.path] = node("file")
    end
    return { code = 0, stdout = "" }
  elseif argv[1] == "mv" then
    eq(
      vim.list_slice(argv, 1, 5),
      { "mv", "--no-copy", "--update=none-fail", "-T", "--" },
      "atomic no-replace publication"
    )
    eq(opts.timeout, 10000, "publication process timeout")
    local from, to = argv[6], argv[7]
    if scenario == "race" then
      fs[to] = node("directory")
      return { code = 1, stderr = "not replacing existing target" }
    end
    assert(not fs[to])
    local moved = {}
    for file, stat in pairs(fs) do
      if file == from or file:sub(1, #from + 1) == from .. "/" then
        moved[to .. file:sub(#from + 1)] = stat
        fs[file] = nil
      end
    end
    for file, stat in pairs(moved) do
      fs[file] = stat
    end
    return { code = 0, stdout = "" }
  end
  error("unexpected process " .. vim.inspect(argv))
end
system_hook = fake_process
local target = helper("project_target")
reset_disk()
eq(target(disk_parent, "demo"), disk_parent .. "/demo", "absolute target")
for _, kind in ipairs({ "directory", "file", "link" }) do
  fs[disk_parent .. "/demo"] = node(kind)
  fails(function()
    target(disk_parent, "demo")
  end, "目标已存在", "existing " .. kind .. " rejected")
end
fs[disk_parent .. "/demo"] = nil
fails(function()
  target(disk_parent, "../elsewhere")
end, "目录名", "target cannot escape parent")
fails(function()
  target(disk_parent .. "/keep.zip", "demo")
end, "不是目录", "file parent rejected")
reset_disk()
fs["/"] = node("directory")
eq(target("/", "demo"), "/demo", "root parent is not reduced to empty string")

local generate = helper("generate_project")
for _, mode in ipairs({ "ok", "download-fail", "download-timeout", "spawn-fail", "zip-traversal", "unzip-fail", "race" }) do
  reset_disk()
  scenario = mode
  local task = start(function()
    return generate(disk_parent, "demo", { type = "maven-project", language = "java", dependencies = "" })
  end)
  local ret = result(task)
  eq(ret[1], mode == "ok", mode .. " generation outcome")
  eq(#deleted, 1, mode .. " cleans exactly one owned temporary directory")
  eq(unlinked[1], deleted[1] .. "/starter.zip", mode .. " deletes exact ZIP only")
  eq(fs[disk_parent .. "/keep.zip"].type, "file", mode .. " unrelated ZIP untouched")
  if mode ~= "ok" and mode ~= "race" then
    eq(fs[disk_parent .. "/demo"], nil, mode .. " leaves no target")
  end
  if mode == "race" then
    eq(fs[disk_parent .. "/demo"].type, "directory", "racing target preserved")
    eq(fs[disk_parent .. "/demo/pom.xml"], nil, "racing target not filled")
  elseif mode == "download-fail" then
    eq(tostring(ret[2]):find("HTTP 503", 1, true) ~= nil, true, "download reports HTTP failure")
    eq(#calls, 1, "HTTP failure never invokes unzip")
  elseif mode == "zip-traversal" then
    eq(#calls, 2, "unsafe ZIP never extracted")
  elseif mode == "ok" then
    eq(download_query.dependencies, "", "explicit zero dependencies passed to API")
    eq(fs[disk_parent .. "/demo/pom.xml"].type, "file", "successful project published")
  end
end
reset_disk()
fs[disk_parent .. "/demo"] = node("directory")
local existing = start(function()
  return generate(disk_parent, "demo", {})
end)
eq(result(existing)[1], false, "generator rejects preexisting target")
eq(#calls, 0, "preexisting target rejected before network or staging")
eq(next(owned), nil, "preexisting target creates no temporary files")

local function new_wizard()
  return assert(loadfile(root .. "/lua/languages/java/spring/wizard.lua"))()
end
local inputs, picks = {}, {}
vim.ui.input = function(opts, done)
  eq(opts.default, nil, "input default is prompt-only")
  local step = opts.prompt:match("^(%d+)")
  local value = inputs[step]
  if value == false then
    done(nil)
  else
    done(value or (step == "11" and disk_parent or ""))
  end
end
local function auto_picker(opts, pk, items)
  vim.schedule(function()
    local chosen = picks[opts.title]
    if chosen == nil then
      chosen = picks[opts.title:match("^(%d+)")]
    end
    if chosen == nil then
      chosen = items[1] and items[1].item.id
    end
    if chosen == false then
      pk:close()
      return
    end
    if opts.source == "spring-wizard-deps" then
      for _, id in ipairs(picks.dependencies or {}) do
        for _, item in ipairs(items) do
          if item.item.id == id then
            pk.list.selected[#pk.list.selected + 1] = item
          end
        end
      end
      opts.actions.confirm(pk)
    else
      for _, item in ipairs(items) do
        if item.item.id == chosen then
          opts.actions.confirm(pk, item)
          return
        end
      end
      pk:close()
    end
  end)
  return pk
end
picker_hook = auto_picker
for _, lang in ipairs({ "java", "kotlin" }) do
  reset_disk()
  scenario, inputs = "ok", {}
  picks = {
    ["1"] = lang == "java" and "maven" or "gradle",
    ["2"] = lang,
    ["3"] = "21",
    dependencies = lang == "java" and {} or { "web", "devtools" },
  }
  local current = new_wizard()
  local before = apply_count
  current.create()
  drain()
  eq(current._running, false, lang .. " eleven step flow finished")
  eq(apply_count - before, 1, "UI initialized once per create")
  eq(download_query.type, lang == "java" and "maven-project" or "gradle-project-kotlin", lang .. " build API mapping")
  eq(download_query.language, lang, "language preserved")
  eq(download_query.bootVersion, "4.1.1", "normalized API version")
  eq(download_query.dependencies, lang == "java" and "" or "web,devtools", "selected dependencies passed")
  eq(changed_dir, disk_parent .. "/demo", "change into created project")
  eq(
    commands[1]:find(lang == "java" and "DemoApplication.java" or "DemoApplication.kt", 1, true) ~= nil,
    true,
    "opens selected language main"
  )
  eq(#picker_records, 7, "six selection steps and final confirmation")
end
reset_disk()
scenario, inputs, picks = "ok", {}, { ["1"] = false }
local cancelled_flow = new_wizard()
cancelled_flow.create()
cancelled_flow.create()
drain()
eq(cancelled_flow._running, false, "cancel releases running guard")
eq(notices[1].level, vim.log.levels.WARN, "reentry rejected")
eq(notices[#notices].text, "已取消，未改动任何文件", "cancel report")
eq(#calls, 1, "cancel creates no project")
reset_disk()
scenario, inputs, picks = "ok", { ["10"] = "1bad..pkg" }, {}
local invalid_flow = new_wizard()
invalid_flow.create()
drain()
eq(invalid_flow._running, false, "invalid package releases running guard")
eq(#calls, 1, "invalid package stops before download")
eq(notices[#notices].text:find("包名", 1, true) ~= nil, true, "invalid package reported")
reset_disk()
scenario, inputs, picks = "ok", { ["7"] = false }, {}
local cancelled_input = new_wizard()
cancelled_input.create()
drain()
eq(cancelled_input._running, false, "input Esc releases running guard")
eq(#calls, 1, "input cancellation does not download")
eq(notices[#notices].text, "已取消，未改动任何文件", "input cancellation report")
reset_disk()
scenario, inputs, picks = "ok", {}, { ["确认创建"] = "no" }
local no = new_wizard()
no.create()
drain()
eq(no._running, false, "final no releases running guard")
eq(next(owned), nil, "final no creates no staging directory")
eq(#calls, 1, "final no skips template download")
reset_disk()
scenario, inputs, picks = "ok", {}, {}
local confirmations = 0
picker_hook = function(opts, pk, items)
  if opts.title == "确认创建" then
    confirmations = confirmations + 1
    picks["确认创建"] = confirmations == 1 and "redo" or "no"
  end
  return auto_picker(opts, pk, items)
end
local restarted, before_apply = new_wizard(), apply_count
restarted.create()
drain()
eq(restarted._running, false, "restart remains in one guarded wizard")
eq(#picker_records, 14, "restart repeats all selection steps and confirmation")
eq(confirmations, 2, "restart returns to final confirmation")
eq(#calls, 1, "restart reuses metadata without creating files")
eq(apply_count - before_apply, 1, "restart does not repeat UI initialization")
picker_hook = auto_picker
reset_disk()
missing_tool = "unzip"
local unavailable = new_wizard()
unavailable.create()
drain()
eq(unavailable._running, false, "missing prerequisite releases guard")
eq(#calls, 0, "missing prerequisite checked before network")
eq(notices[#notices].text:find("unzip", 1, true) ~= nil, true, "actual missing tool reported")
missing_tool = nil
for _, mode in ipairs({ "metadata-fail", "metadata-invalid" }) do
  reset_disk()
  scenario, inputs, picks = mode, {}, {}
  local current = new_wizard()
  current.create()
  drain()
  eq(current._running, false, mode .. " finishes")
  eq(#picker_records, 0, mode .. " no broken picker shown")
  eq(notices[#notices].level, vim.log.levels.ERROR, mode .. " error not cancellation")
end
reset_disk()
scenario, inputs, picks = "ok", {}, { ["1"] = false }
local cached = new_wizard()
cached.create()
drain()
cached.create()
drain()
eq(#calls, 1, "metadata cached for ten minutes")
clock = clock + 601000
cached.create()
drain()
eq(#calls, 2, "metadata expires")
local normal = { picker = { opts = { source = "files" } }, cursor = 1, dirty = false }
List.render(normal)
eq(normal.dirty, false, "rerender patch does not touch other picker sources")
local wizlist = { picker = { opts = { source = "spring-wizard" } }, cursor = 2, dirty = false }
List.render(wizlist)
eq(wizlist.dirty, true, "wizard cursor move requests rerender")
for _, timer in ipairs(timers) do
  eq(timer.closed, true, "no pulse timers leaked")
end
print("spring_wizard: " .. count .. " assertions passed (pure Lua; UI/process/filesystem mocked)")
