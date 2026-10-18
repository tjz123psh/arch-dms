-- 使用临时 Eclipse Java 工程和独立 jdtls workspace 验证真实查询协议；不启动业务 main。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP, "set isolated NVIM_JAVA_TEST_TMP")
assert(base:match("^/tmp/nvim%-java%-"), "temporary test directory required")
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local data = vim.env.HOME .. "/.local/share/nvim"
vim.opt.rtp:append(data .. "/lazy/nvim-jdtls")
local clients, results = {}, {}
vim.o.hidden = true -- 整理只修改隔离测试缓冲区，切项目时不必写回磁盘。
local function project(name)
  local dir = base .. "/" .. name
  assert(not vim.uv.fs_stat(dir), "use a new isolated test directory")
  vim.fn.mkdir(dir .. "/src", "p")
  vim.fn.writefile({
    '<?xml version="1.0"?><projectDescription><name>'
      .. name
      .. "</name><buildSpec><buildCommand><name>org.eclipse.jdt.core.javabuilder</name></buildCommand></buildSpec><natures><nature>org.eclipse.jdt.core.javanature</nature></natures></projectDescription>",
  }, dir .. "/.project")
  vim.fn.writefile({
    '<?xml version="1.0"?><classpath><classpathentry kind="src" path="src"/><classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/><classpathentry kind="output" path="bin"/></classpath>',
  }, dir .. "/.classpath")
  local class = "Audit" .. name
  vim.fn.writefile({
    "import java.util.Date;",
    "import java.util.ArrayList;",
    "public class " .. class .. " {",
    "  public static void main(String[] args) {",
    "    ArrayList<String> items = new ArrayList<>();",
    "    int count = args.length + 1;",
    "    System.out.println(count + items.size());",
    "  }",
    "}",
  }, dir .. "/src/" .. class .. ".java")
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/src/" .. class .. ".java"))
  vim.bo.filetype = "java"
  local buf = vim.api.nvim_get_current_buf()
  local id = require("jdtls").start_or_attach({
    cmd = {
      data .. "/mason/bin/jdtls",
      "--java-executable=/usr/lib/jvm/java-21-openjdk/bin/java",
      "-data",
      base .. "/workspace-" .. name,
    },
    root_dir = dir,
    init_options = {
      bundles = vim.fn.glob(
        data .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
        false,
        true
      ),
    },
    handlers = {
      ["workspace/executeClientCommand"] = function(_, params)
        return params.command == "_java.reloadBundles.command" and {} or vim.NIL
      end,
    },
  })
  local client = assert(vim.lsp.get_client_by_id(id))
  clients[#clients + 1] = client
  assert(
    vim.wait(60000, function()
      return client.initialized or client:is_stopped()
    end, 50),
    "jdtls init timeout"
  )
  assert(not client:is_stopped(), "jdtls stopped during init")
  local found, last_error
  local attempts = 0
  local function fetch()
    attempts = attempts + 1
    require("languages.java.debug").fetch(buf, client, function()
      return not client:is_stopped()
    end, function(err, configs)
      last_error = err
      if configs and #configs > 0 then
        found = configs
      elseif attempts < 10 then
        vim.defer_fn(fetch, 1000)
      end
    end)
  end
  fetch()
  assert(
    vim.wait(60000, function()
      return found ~= nil
    end, 50),
    "main discovery timeout: " .. tostring(last_error)
  )
  assert(#found == 1 and found[1].mainClass == class, vim.inspect(found))
  assert(found[1].cwd == dir and found[1].projectName == name, vim.inspect(found))
  assert(type(found[1].javaExec) == "string" and #found[1].classPaths > 0, vim.inspect(found))
  local shared = require("languages.shared.actions")
  shared.organize_imports()
  assert(
    vim.wait(10000, function()
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      return not text:find("import java.util.Date;", 1, true)
    end, 20),
    "jdtls enhanced organize imports did not apply"
  )
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(table.concat(lines, "\n"):find("import java.util.ArrayList;", 1, true), "used import removed")
  local expression = "args.length + 1"
  for row, line in ipairs(lines) do
    local col = line:find(expression, 1, true)
    if col then
      vim.api.nvim_win_set_cursor(0, { row, col - 1 })
      vim.cmd("normal! v")
      vim.api.nvim_win_set_cursor(0, { row, col + #expression - 2 })
      break
    end
  end
  local choices
  local original_select = vim.ui.select
  vim.ui.select = function(items, _, callback)
    choices = items
    callback(nil) -- 仅验证列表，取消，不执行重构。
  end
  shared.refactor()
  assert(
    vim.wait(10000, function()
      return choices ~= nil
    end, 20),
    "Java Ra did not show refactors"
  )
  vim.ui.select = original_select
  vim.cmd("normal! \27")
  assert(#choices > 0, "no Java refactors")
  local kinds = {}
  for _, item in ipairs(choices) do
    assert(item.action.kind:match("^refactor[.]?") ~= nil, "non-refactor leaked")
    kinds[#kinds + 1] = item.action.kind
  end
  assert(vim.deep_equal(lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false)), "canceling refactor changed buffer")
  results[#results + 1] = {
    class = found[1].mainClass,
    project = found[1].projectName,
    client = id,
    refactors = kinds,
    imports = "organized",
  }
end
local ok, err = xpcall(function()
  project("A")
  project("B")
end, debug.traceback)
for _, client in ipairs(clients) do
  client:stop(true)
end
vim.wait(5000, function()
  for _, client in ipairs(clients) do
    if not client:is_stopped() then
      return false
    end
  end
  return true
end, 50)
assert(ok, err)
print("PASS real JDTLS discovery: " .. vim.json.encode(results) .. "; test clients stopped")
vim.cmd("qa!")
