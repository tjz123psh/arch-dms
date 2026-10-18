-- 只编译/运行本脚本在 /tmp 下创建的短命 Java 程序。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-"))
package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
vim.treesitter.language.add("java", { path = vim.env.HOME .. "/.local/share/nvim/site/parser/java.so" })
local files = require("languages.java.files")
local jobs, notices = {}, {}
vim.notify = function(msg)
  notices[#notices + 1] = msg
end
local count = 0
local function check(value, label)
  assert(value, label)
  count = count + 1
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
  vim.bo.filetype = "java"
end
local function output(run)
  return table.concat(vim.api.nvim_buf_get_lines(run.bufnr, 0, -1, false), "\n")
end
local function run()
  local result = assert(files.run(), table.concat(notices, "\n"))
  jobs[#jobs + 1] = result.job_id
  return result
end
local function finish(result, expected)
  check(
    vim.wait(15000, function()
      return vim.fn.jobwait({ result.job_id }, 0)[1] ~= -1
    end, 20),
    "program exits"
  )
  check(output(result):find(expected, 1, true), output(result))
  check(
    vim.wait(2000, function()
      return vim.uv.fs_stat(result.output) == nil
    end, 20),
    "temporary classes removed"
  )
end
local ok, err = xpcall(function()
  local path = put(
    "plain with space/Main.java",
    [[import java.util.Scanner;
public class Main {
  public static void main(String[] args) {
    System.out.println("OLD");
    Scanner in = new Scanner(System.in);
    System.out.println("SUM=" + (in.nextInt() + in.nextInt()));
    System.out.println("CWD=" + System.getProperty("user.dir"));
  }
}]]
  )
  open(path)
  vim.api.nvim_buf_set_lines(0, 3, 4, false, { '    System.out.println("READY");' })
  local result = run()
  check(
    vim.wait(10000, function()
      return output(result):find("READY", 1, true) ~= nil
    end, 20),
    "waits for real stdin"
  )
  check(table.concat(vim.fn.readfile(path), "\n"):find("READY", 1, true), "runner explicitly saved edited buffer")
  vim.fn.chansend(result.job_id, "7 11\n")
  finish(result, "SUM=18")
  check(output(result):find("CWD=" .. vim.fs.dirname(path), 1, true), "runner cwd is source directory")
  check(not vim.uv.fs_stat(vim.fs.dirname(path) .. "/Main.class"), "no artifacts beside source")

  put("packaged/src/demo/Helper.java", "package demo; class Helper { static int answer() { return 42; } }")
  path = put(
    "packaged/src/demo/Algo$Main.java",
    [[package demo;
public class Algo$Main { public static void main(String[] args) { System.out.println("ANSWER=" + Helper.answer()); } }]]
  )
  open(path)
  finish(run(), "ANSWER=42")
  check(not vim.uv.fs_stat(base .. "/packaged/src/demo/Algo$Main.class"), "packaged output is temporary")

  path = put("compile-failure/Bad.java", "public class Bad { public static void main(String[] a) { int n = ; } }")
  open(path)
  result = run()
  check(
    vim.wait(10000, function()
      return vim.fn.jobwait({ result.job_id }, 0)[1] ~= -1
    end, 20),
    "compile error exits"
  )
  check(output(result):find("Bad.java", 1, true), "compile error visible in terminal")
  check(
    vim.wait(2000, function()
      return vim.uv.fs_stat(result.output) == nil
    end, 20),
    "compile failure cleaned output"
  )

  path = put("readonly/ReadOnly.java", "public class ReadOnly { public static void main(String[] a) {} }")
  open(path)
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// unsaved" })
  vim.bo.readonly = true
  local before = #vim.api.nvim_list_bufs()
  check(files.run() == nil, "save failure blocks execution")
  check(#vim.api.nvim_list_bufs() == before, "save failure does not open terminal")
  vim.bo.readonly = false
  vim.bo.modified = false

  local main = put("templates/demo/Main.java", "package demo; class Main {}")
  local generated = {}
  for _, kind in ipairs({ "class", "interface", "enum", "record" }) do
    open(main)
    local name = "Generated" .. kind
    vim.ui.input = function(_, cb)
      cb("demo." .. name)
    end
    files.generate(kind)
    local path = base .. "/templates/demo/" .. name .. ".java"
    check(vim.api.nvim_buf_get_name(0) == path, kind .. " template opened")
    generated[#generated + 1] = path
  end
  local compile_dir = base .. "/template-classes"
  vim.fn.mkdir(compile_dir, "p")
  local compile = vim.system(vim.list_extend({ "javac", "-d", compile_dir }, generated), { text = true }):wait()
  check(compile.code == 0, "all four templates compile: " .. compile.stderr)
  for _, invalid in ipairs({ "../Escape", "demo..Main", "demo.class", "1Main", "demo.Bad-Name", "_" }) do
    check(not files.valid_name(invalid), "invalid template name: " .. invalid)
  end
  open(main)
  vim.ui.input = function(_, cb)
    cb("demo.Main")
  end
  files.generate("class")
  check(vim.fn.readfile(main)[1] == "package demo; class Main {}", "existing file not overwritten")
end, debug.traceback)
for _, job in ipairs(jobs) do
  if vim.fn.jobwait({ job }, 0)[1] == -1 then
    vim.fn.jobstop(job)
  end
end
assert(ok, err)
print("PASS " .. count .. " real standalone Java assertions; owned jobs stopped")
vim.cmd("qa!")
