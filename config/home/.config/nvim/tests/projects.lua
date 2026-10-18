-- Isolated history fixtures; no user history or real plugin processes.
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local base = assert(vim.env.NVIM_CORE_TEST_TMP)
assert(base:match("^/tmp/nvim%-"))
assert(vim.fn.stdpath("state"):match("^/tmp/nvim%-"))
vim.fn.mkdir(base, "p")
vim.fn.mkdir(vim.fn.stdpath("state"), "p")
local path = { historyfile = base .. "/plugin-history", create_scaffolding = function() end }
local plugin = { session_projects = {}, recent_projects = { "untouched" } }
plugin.get_recent_projects = function()
  return plugin.session_projects
end
plugin.write_projects_to_history = function()
  error("upstream truncating writer must never run")
end
package.loaded["project_nvim.utils.path"] = path
package.loaded["project_nvim.utils.history"] = plugin
local history = require("core.projects.history")
if vim.env.NVIM_PROJECT_WRITER then
  plugin.session_projects = { assert(vim.env.NVIM_PROJECT_WRITER) }
  history.protect()
  for _ = 1, 50 do
    plugin.write_projects_to_history()
  end
  vim.cmd("qa!")
  return
end
local count = 0
local function check(value, label)
  assert(value, label)
  count = count + 1
end
local function directory(name, marker)
  local dir = base .. "/" .. name
  vim.fn.mkdir(dir, "p")
  if marker then
    vim.fn.writefile({}, dir .. "/" .. marker)
  end
  return dir
end
local alpha = directory("alpha", "pom.xml")
local beta = directory("space project", "build.gradle")
local gamma = directory("gamma", "go.mod")
local nested = directory("alpha/nested", "pom.xml")
local own = vim.fn.stdpath("state") .. "/project-history.list"
vim.fn.writefile({ alpha, beta }, own)
vim.fn.writefile({ beta, gamma }, path.historyfile)
plugin.session_projects = { alpha }
check(vim.deep_equal(history.list(), { beta, gamma, alpha }), "three-source union preserves last occurrence order")
check(vim.tbl_contains(vim.fn.readfile(own), gamma), "plugin-only entry mirrored to own file")
check(vim.tbl_contains(vim.fn.readfile(path.historyfile), alpha), "own-only entry appended back")
check(vim.deep_equal(plugin.recent_projects, { "untouched" }), "never assign upstream recent_projects")
vim.fn.writefile({}, path.historyfile)
check(#history.list() == 3 and #vim.fn.readfile(path.historyfile) == 3, "empty upstream history recovers from mirror")
vim.fn.writefile({ base .. "/missing", alpha }, path.historyfile)
check(not vim.tbl_contains(history.list(), base .. "/missing"), "missing disk-history path is not shown")
history.mirror(nested)
check(vim.tbl_contains(vim.fn.readfile(own), nested), "DirChanged mirror keeps recognized project")
local marker_only = directory("darcs-only", "_darcs")
history.mirror(marker_only)
check(
  not vim.tbl_contains(vim.fn.readfile(own), marker_only),
  "mirror markers are not silently widened to plugin markers"
)

history.protect()
local before = table.concat(vim.fn.readfile(path.historyfile), "\n")
local extra = directory("extra")
plugin.session_projects = { extra, extra }
plugin.write_projects_to_history()
local added = 0
for _, line in ipairs(vim.fn.readfile(path.historyfile)) do
  if line == extra then
    added = added + 1
  end
end
check(added == 1, "guard deduplicates before append")
check(
  table.concat(vim.fn.readfile(path.historyfile), "\n"):sub(1, #before) == before,
  "guard preserves existing byte prefix"
)
local open = io.open
io.open = function(file, mode)
  if file == path.historyfile and mode == "a" then
    return nil, "test write failure"
  end
  return open(file, mode)
end
before = table.concat(vim.fn.readfile(path.historyfile), "\n")
plugin.session_projects = { directory("unwritable") }
plugin.write_projects_to_history()
io.open = open
check(table.concat(vim.fn.readfile(path.historyfile), "\n") == before, "write failure never truncates")
local recent = plugin.get_recent_projects
plugin.get_recent_projects = function()
  error("test invalid history")
end
plugin.write_projects_to_history()
plugin.get_recent_projects = recent
check(table.concat(vim.fn.readfile(path.historyfile), "\n") == before, "read/merge exception never truncates")

local writers = {}
for _, dir in ipairs({ directory("writer-one"), directory("writer-two") }) do
  writers[#writers + 1] = {
    dir = dir,
    process = vim.system(
      { vim.v.progpath, "-u", "NONE", "-i", "NONE", "-n", "--headless", "-l", root .. "/tests/projects.lua" },
      {
        cwd = root,
        text = true,
        timeout = 10000,
        env = {
          NVIM_CORE_TEST_TMP = base,
          NVIM_PROJECT_WRITER = dir,
          XDG_STATE_HOME = dir .. "/state",
          XDG_CACHE_HOME = dir .. "/cache",
        },
      }
    ),
  }
end
local results = {}
for _, job in ipairs(writers) do
  results[#results + 1] = job.process:wait()
end
for i, result in ipairs(results) do
  check(result.code == 0, "concurrent history writer: " .. tostring(result.stderr))
  check(vim.tbl_contains(vim.fn.readfile(path.historyfile), writers[i].dir), "concurrent writer entry remains")
end
check(
  table.concat(vim.fn.readfile(path.historyfile), "\n"):sub(1, #before) == before,
  "concurrent append preserves previous history"
)

local calls, state = 0, { path = alpha }
package.loaded["neo-tree.sources.manager"] = {
  _for_each_state = function(_, fn)
    fn(state)
  end,
  navigate = function(_, dir)
    calls = calls + 1
    state.path = dir
  end,
}
local project = {
  set_pwd = function(dir)
    vim.api.nvim_set_current_dir(dir)
    return true
  end,
}
package.loaded["project_nvim.project"] = project
package.loaded["project_nvim.config"] = { options = { ignore_lsp = {} } }
local projects = require("core.projects")
projects.setup()
projects.setup()
check(#vim.api.nvim_get_autocmds({ group = "ProjectHistoryMirror" }) == 1, "setup does not duplicate directory hooks")
projects.patch()
local wrapped = project.set_pwd
projects.patch()
check(project.set_pwd == wrapped, "patch does not wrap set_pwd twice")
projects.switch(beta)
check(vim.wait(1000, function()
  return state.path == beta
end, 10) and calls == 1, "shared tree refresh changes the root once")

local captured
package.loaded.lazy = { load = function() end }
local function capture_picker(opts)
  captured = opts
end
local function directory_icon()
  return "dir", "Directory"
end
package.loaded.snacks = { picker = { pick = capture_picker }, util = { icon = directory_icon } }
vim.api.nvim_set_current_dir(nested)
require("core.projects.picker").show()
check(captured and captured.source == "project-history", "dedicated picker source")
check(captured.layout.preset == "picker_compact", "project list keeps the compact preset")
check(captured.layout.backdrop == 60, "project list keeps its backdrop")
local layout = captured.layout.layout
check(
  layout.height == math.min(math.max(math.floor(vim.o.lines * 0.6), 8), vim.o.lines - 4),
  "project box height follows the window, not the compact 40%"
)
check(layout.height > math.floor(vim.o.lines * 0.4), "project box must be taller than the shared compact preset")
local wide = math.min(160, math.floor(vim.o.columns * 0.8), vim.o.columns - 4)
check(
  layout.width >= wide and layout.width <= math.min(160, vim.o.columns - 4),
  "project box is sized by the window, not by content"
)
check(layout.width > math.floor(vim.o.columns * 0.55), "project box must be wider than the shared compact preset")
check(
  captured.items[1].project_dir == nested and captured.items[1].project_current,
  "longest matching root is pinned and marked"
)
local closed = 0
captured.confirm({
  close = function()
    closed = closed + 1
  end,
}, nil)
check(closed == 1 and vim.fn.getcwd() == nested, "empty confirmation closes without changing directory")
captured.confirm({
  close = function()
    closed = closed + 1
  end,
}, { project_dir = beta })
check(vim.fn.getcwd() == beta and closed == 2, "space-containing project confirms through Lua API")
check(
  vim.wait(1000, function()
    return state.path == beta
  end, 10),
  "tree follows confirmed project"
)
print("PASS " .. count .. " isolated project history/picker assertions")
vim.cmd("qa!")
