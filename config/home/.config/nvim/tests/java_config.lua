-- NVIM_JAVA_TEST_TMP=/tmp/nvim-java-... nvim -u NONE -i NONE -n --headless -l tests/java_config.lua
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-"))
package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
vim.treesitter.language.add("java", { path = vim.env.HOME .. "/.local/share/nvim/site/parser/java.so" })
local syntax = require("languages.java.syntax")
local project = require("languages.java.project")
local spring = require("languages.java.spring.run")
local count = 0
local function eq(actual, expected, label)
  assert(vim.deep_equal(actual, expected), label .. "\n" .. vim.inspect(actual) .. " != " .. vim.inspect(expected))
  count = count + 1
end
local function file(path, text)
  path = base .. "/" .. path
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
  return path
end
local function buffer(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = "java"
  return vim.api.nvim_get_current_buf()
end
local text = [=[/* package fake; public static void main(String[] args) {} */
package demo;
class Main {
  String fake = "public static void main(String[] args) {}";
  public static void main(String[] args) {}
  static class Worker { static public void main(java.lang.String... args) {} }
  public static void main(int wrong) {}
  void helper() { class Local { public static void main(String[] args) {} } }
}
class Other { public static void main(String args[]) {} }
]=]
eq(syntax.package(text), "demo", "package ignores comments")
local mains = assert(syntax.mains(text))
eq(
  vim.tbl_map(function(m)
    return m.fqcn
  end, mains),
  { "demo.Main", "demo.Main$Worker", "demo.Other" },
  "real main nodes"
)
eq(
  #assert(syntax.mains('class Fake { String s = "public static void main(String[] args) {}"; }')),
  0,
  "string is not main"
)
eq(syntax.package("class Main {}"), nil, "default package")
for _, args in ipairs({
  "final String[] args",
  "@Deprecated String[] args",
  "String args[]",
  "java.lang.String... args",
}) do
  eq(
    #assert(syntax.mains("class Main { public static void main(" .. args .. ") {} }")),
    1,
    "legal main arguments: " .. args
  )
end
for _, args in ipairs({ "String[][] args", "String[]... args", "String[] a, int b", "int wrong" }) do
  eq(
    #assert(syntax.mains("class Main { public static void main(" .. args .. ") {} }")),
    0,
    "not a main signature: " .. args
  )
end
local maven = file("maven/pom.xml", "<project/>")
local java = file("maven/src/main/java/demo/Main.java", text)
local standalone = file("algorithm with $ space/Main.java", "class Main {}")
local packaged = file("source/demo/tools/Main.java", "package demo.tools; class Main {}")
local b = buffer(java)
eq(project.root(b), vim.fs.dirname(maven), "pom root without wrapper")
vim.fn.chdir(vim.fs.dirname(maven))
local single = buffer(standalone)
eq(project.lsp_root(single), vim.fs.dirname(standalone), "standalone never uses unrelated cwd")
local packed = buffer(packaged)
eq(project.lsp_root(packed), base .. "/source", "package source root")
eq(project.source_root(base .. "/wrong/Main.java", "demo"), nil, "mismatched package rejected")

file("maven/mvnw", "#!/bin/sh\nexit 0")
local tool = assert(project.tool(base .. "/maven"))
eq(tool.bin, { "sh", base .. "/maven/mvnw" }, "wrapper without executable bit")
eq(tool.kind, "maven", "Maven detected")
file("gradle/build.gradle.kts", "plugins { java }")
file("gradle/gradlew", "#!/bin/sh\nexit 0")
eq(assert(project.tool(base .. "/gradle")).kind, "gradle", "Gradle detected")
eq(
  project.command({ bin = { "mvn" } }, { "spring-boot:run", "-Dmain.class=demo.App$Worker" }),
  "'mvn' 'spring-boot:run' '-Dmain.class=demo.App$Worker'",
  "main dollar quoted"
)

local function pom(body)
  file("maven/pom.xml", "<project>" .. body .. "</project>")
  return spring.configuration(base .. "/maven")
end
local custom = pom([=[<properties><main.class>demo.Main</main.class></properties><build><plugins><plugin>
<artifactId>spring-boot-maven-plugin</artifactId><configuration><mainClass>${main.class}</mainClass></configuration>
</plugin></plugins></build>]=])
eq(custom, { flag = "main.class", default = "demo.Main" }, "custom main property parsed once")
eq(
  spring.arguments(tool, custom, "demo.App$Worker", true),
  { "spring-boot:run", "-Dmain.class=demo.App$Worker" },
  "custom property selected"
)
local inherited = pom("<parent><artifactId>parent</artifactId></parent>")
eq(inherited.flag, "spring-boot.run.main-class", "inherited plugin uses standard property")
local pinned = pom(
  "<plugin><artifactId>spring-boot-maven-plugin</artifactId><configuration><mainClass>demo.Fixed</mainClass></configuration></plugin>"
)
eq(spring.arguments(tool, pinned, "demo.Wrong", true), nil, "pinned main never launches wrong choice")
eq(spring.arguments(tool, pinned, "demo.Fixed", true), { "spring-boot:run" }, "pinned selected main allowed")
eq(spring.arguments({ kind = "gradle" }, {}, "demo.Main", true), nil, "Gradle multi-main fails closed")
eq(spring.arguments({ kind = "gradle" }, {}, "demo.Main", false), { "bootRun" }, "Gradle single main retained")
file("maven/src/test/java/TestMain.java", "class TestMain { public static void main(String[] a) {} }")
eq(#assert(spring.scan(base .. "/maven")), 3, "Spring scan excludes test source set")

local java_config = require("languages.java.lsp")
local original_client = vim.lsp.get_client_by_id
local calls = {}
vim.lsp.get_client_by_id = function()
  return { commands = {
    probe = function(args)
      calls[#calls + 1] = args
      return false
    end,
  } }
end
vim.lsp.commands.probe = function()
  error("global must not win")
end
local function dispatch(command)
  return java_config.execute_client_command(nil, { command = command, arguments = { "hello" } }, { client_id = 42 })
end
eq(dispatch("probe"), false, "client commands take priority and retain false")
eq(calls[1], { "hello" }, "arguments forwarded")
vim.lsp.commands.global_probe = function()
  return "classpath"
end
eq(dispatch("global_probe"), "classpath", "global Spring handshake forwarded")
vim.lsp.commands.empty_probe = function() end
eq(dispatch("empty_probe"), vim.NIL, "nil success becomes JSON null")
eq(dispatch("unknown"), vim.NIL, "unknown receives response")
eq(dispatch("_java.reloadBundles.command"), {}, "reload bundles receives JSON list")
vim.lsp.commands.error_probe = function()
  error("expected failure")
end
local result, err = dispatch("error_probe")
eq(result, nil, "error not encoded as successful result")
eq(err.code, -32603, "correct RPC error code")
vim.lsp.get_client_by_id = original_client

-- 安装版 Spring 的真实 gate：不启动服务器，覆盖 cwd、文件名和项目筛选。
vim.opt.rtp:append(vim.env.HOME .. "/.local/share/nvim/lazy/spring-boot.nvim")
local boot_config = require("spring_boot.config")
local launch = require("spring_boot.launch")
boot_config.ls_path = "/mock/server.jar"
boot_config.project_filter = require("spring_boot.util").has_spring_boot_dependency
launch.root_markers = project.markers
local gate = require("languages.java.spring")[1].opts.server.root_dir
file("boot/pom.xml", "<project><parent><artifactId>spring-boot-starter-parent</artifactId></parent></project>")
local bootjava = file("boot/src/main/java/App.java", "class App {}")
local appyaml = file("boot/src/main/resources/application.yml", "server:\n  port: 0")
local other = file("boot/other.yml", "name: example")
local function root_for(path, ft)
  local buf = buffer(path)
  vim.bo[buf].filetype = ft
  local found
  gate(buf, function(root)
    found = root
  end)
  return found
end
file("maven/pom.xml", "<project/>") -- 恢复普通 Maven fixture，避免前面的参数测试留下 Spring 插件。
vim.fn.chdir(base .. "/boot")
eq(root_for(standalone, "java"), nil, "standalone is not current Spring project")
eq(root_for(java, "java"), nil, "plain Maven has no Spring client")
eq(root_for(bootjava, "java"), base .. "/boot", "Spring pom without wrapper accepted")
eq(root_for(appyaml, "yaml"), base .. "/boot", "application yaml accepted")
eq(root_for(other, "yaml"), nil, "unrelated yaml not accepted")
file("boot-gradle/build.gradle.kts", 'plugins { id("org.springframework.boot") version "4.0.8" }')
eq(
  root_for(file("boot-gradle/src/main/java/App.java", "class App {}"), "java"),
  base .. "/boot-gradle",
  "Spring Gradle accepted"
)
print("PASS " .. count .. " Java configuration assertions")
vim.cmd("qa!")
