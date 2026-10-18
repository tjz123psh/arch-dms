-- 完整配置 + 本机已有 Maven 缓存；所有工程、产物、语言服务及 HTTP 服务均隔离。
local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-"))
assert(vim.fn.stdpath("data"):match("^/tmp/nvim%-java%-"))
vim.o.columns, vim.o.lines = 180, 55
local results, owned, old_clients = {}, {}, {}
for _, c in ipairs(vim.lsp.get_clients()) do
  old_clients[c.id] = true
end
local function check(ok, label)
  assert(ok, label)
  results[#results + 1] = label
  print("OK " .. label)
end
local function wait(fn, label, timeout)
  check(vim.wait(timeout or 30000, fn, 40), label)
end
local function put(name, value)
  local path = base .. "/" .. name
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(value, "\n", { plain = true }), path)
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
    client = vim.lsp.get_clients({ name = name, bufnr = buf })[1]
    return client and client.initialized
  end, name .. " attached to Spring project", 90000)
  return client
end
local function query(client, method, params, buf, predicate)
  local found, last_error, attempts
  attempts = 0
  local function request()
    attempts = attempts + 1
    client:request(method, params, function(err, value)
      last_error = err
      if not err and predicate(value) then
        found = value
      elseif attempts < 30 then
        vim.defer_fn(request, 1000)
      end
    end, buf)
  end
  request()
  wait(function()
    return found ~= nil
  end, method .. " returned expected Spring data: " .. vim.inspect(last_error), 65000)
  return found
end
local function press(key)
  local map = vim.fn.maparg(key, "n", false, true)
  check(type(map.callback) == "function", key .. " is configured")
  map.callback()
end
local dap
local ok, err = xpcall(function()
  local lombok = vim.fn.stdpath("data") .. "/mason/packages/jdtls/lombok.jar"
  check(vim.uv.fs_stat(lombok), "bundled Lombok available without installing anything")
  put(
    "pom.xml",
    [[<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>4.0.8</version><relativePath/></parent>
<groupId>demo</groupId><artifactId>nvim-refactor-smoke</artifactId><version>1.0</version>
<properties><java.version>21</java.version></properties><dependencies>
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc</artifactId></dependency>
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
<dependency><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId><version>local</version><scope>system</scope><systemPath>]]
      .. lombok
      .. [[</systemPath></dependency>
</dependencies><build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>]]
  )
  put(".mvn/maven.config", "-o")
  local props = put("src/main/resources/application.properties", "server.port=0\nserver.address=127.0.0.1")
  put(
    "src/main/java/demo/Greeting.java",
    'package demo; @lombok.Data public class Greeting { private String name = "ok"; }'
  )
  local app = put(
    "src/main/java/demo/App.java",
    [[package demo;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.bind.annotation.*;
@SpringBootApplication
@RestController
public class App {
  @GetMapping("/ping")
  public String ping() { return new Greeting().getName(); }
  @Bean Greeting greeting() { return new Greeting(); }
  public static void main(String[] args) { SpringApplication.run(App.class, args); }
}]]
  )
  local test_path = put(
    "src/test/java/demo/AppTest.java",
    [[package demo;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
class AppTest {
  @Test void works() {
    int actual = new Greeting().getName().length();
    assertEquals(2, actual);
  }
}]]
  )
  local buf = open(app)
  local java, boot = client_for(buf, "jdtls"), client_for(buf, "spring-boot")
  check(java.config.root_dir == base and boot.config.root_dir == base, "Java and Spring use same project root")
  query(java, "workspace/executeCommand", { command = "vscode.java.resolveMainClass" }, buf, function(value)
    return type(value) == "table" and #value == 1 and value[1].mainClass == "demo.App"
  end)
  local line = vim.api.nvim_buf_get_lines(buf, 9, 10, false)[1]
  query(
    java,
    "textDocument/hover",
    {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      position = { line = 9, character = line:find("getName", 1, true) - 1 },
    },
    buf,
    function(value)
      return value and vim.inspect(value):find("getName", 1, true) ~= nil
    end
  )
  check(#vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) == 0, "Lombok getter has no JDTLS error")
  query(boot, "workspace/symbol", { query = "@/" }, buf, function(value)
    return value and vim.inspect(value):find("/ping", 1, true) ~= nil
  end)
  query(boot, "workspace/symbol", { query = "@+" }, buf, function(value)
    return value and vim.inspect(value):find("greeting", 1, true) ~= nil
  end)
  local properties = open(props)
  client_for(properties, "spring-boot")
  vim.api.nvim_buf_set_lines(properties, 0, -1, false, { "server.po" })
  local completion = query(
    boot,
    "textDocument/completion",
    {
      textDocument = { uri = vim.uri_from_bufnr(properties) },
      position = { line = 0, character = 9 },
      context = { triggerKind = 1 },
    },
    properties,
    function(value)
      return value and vim.inspect(value):find("server.port", 1, true) ~= nil
    end
  )
  check(completion ~= nil, "Spring property completion works")
  vim.api.nvim_buf_set_lines(properties, 0, -1, false, { "server.port=0", "server.address=127.0.0.1" })
  vim.cmd("write")

  open(app)
  local terms = require("languages.java.terminal")
  local app_term = terms.get(base, "spring", "demo.App")
  owned[#owned + 1] = app_term
  press("<leader>sr")
  local port
  wait(function()
    port = (app_term._java_output or ""):match("Tomcat started on port (%d+)")
    return port ~= nil
  end, "Spring Boot launched on an isolated random port", 90000)
  local response = vim
    .system({ "curl", "--fail", "--silent", "--max-time", "5", "http://127.0.0.1:" .. port .. "/ping" }, { text = true })
    :wait()
  check(response.code == 0 and response.stdout == "ok", "running Spring endpoint returns expected response")

  local test = open(test_path)
  client_for(test, "jdtls")
  vim.api.nvim_win_set_cursor(0, { 7, 0 })
  local build = terms.get(base, "build")
  owned[#owned + 1] = build
  press("<leader>Jt")
  wait(function()
    return (build._java_output or ""):find("BUILD SUCCESS", 1, true) and not terms.busy(build)
  end, "configured terminal JUnit test succeeds", 90000)
  check((build._java_output or ""):find("Tests run: 1", 1, true), "only requested JUnit method ran")
  check(app_term.id ~= build.id and terms.busy(app_term), "test terminal leaves running Spring app alone")

  dap = require("languages.java.debug").ensure()
  vim.api.nvim_set_current_buf(test)
  vim.api.nvim_win_set_cursor(0, { 7, 0 })
  dap.toggle_breakpoint()
  press("<leader>Jg")
  wait(function()
    return dap.session() and dap.session().current_frame ~= nil
  end, "JUnit DAP breakpoint hit", 60000)
  check(dap.session().current_frame.line == 7, "JUnit debugger stopped at requested test line")
  dap.continue()
  wait(function()
    return dap.session() == nil
  end, "JUnit DAP completed", 30000)

  vim.fn.chansend(app_term.job_id, string.char(3))
  wait(function()
    return not terms.busy(app_term)
  end, "single application stopped before batch test")
  put(
    "src/main/java/demo/Worker.java",
    [[package demo;
public class Worker {
  public static void main(String[] args) { org.springframework.boot.SpringApplication.run(App.class, args); }
}]]
  )
  open(app)
  local worker = terms.get(base, "spring", "demo.Worker")
  owned[#owned + 1] = worker
  local select = vim.ui.select
  vim.ui.select = function(items, _, callback)
    check(#items == 3, "two main classes plus batch option discovered")
    callback(items[#items])
  end
  press("<leader>sr")
  vim.ui.select = select
  wait(function()
    return (worker._java_output or ""):find("Started Worker", 1, true) ~= nil
  end, "batch starts both Spring main classes in sequence", 90000)
  local app_port = (app_term._java_output or ""):match("Tomcat started on port (%d+)")
  local worker_port = (worker._java_output or ""):match("Tomcat started on port (%d+)")
  check(
    app_port and worker_port and app_port ~= worker_port and terms.busy(app_term) and terms.busy(worker),
    "both isolated applications remain live on different ports"
  )
  local answer = vim
    .system(
      { "curl", "--fail", "--silent", "--max-time", "5", "http://127.0.0.1:" .. worker_port .. "/ping" },
      { text = true }
    )
    :wait()
  check(answer.code == 0 and answer.stdout == "ok", "selected second main serves the endpoint")
end, debug.traceback)
if dap and dap.session() then
  dap.terminate()
  vim.wait(3000, function()
    return not dap.session()
  end, 40)
end
for _, term in ipairs(owned) do
  if term.job_id then
    pcall(vim.fn.chansend, term.job_id, string.char(3))
  end
end
vim.wait(5000, function()
  for _, term in ipairs(owned) do
    if require("languages.java.terminal").busy(term) then
      return false
    end
  end
  return true
end, 40)
for _, term in ipairs(owned) do
  if term.job_id then
    pcall(vim.fn.jobstop, term.job_id)
  end
end
for _, c in ipairs(vim.lsp.get_clients()) do
  if not old_clients[c.id] then
    c:stop(true)
  end
end
vim.wait(5000, function()
  for _, c in ipairs(vim.lsp.get_clients()) do
    if not old_clients[c.id] then
      return false
    end
  end
  return true
end, 40)
vim.fn.writefile({ vim.json.encode({ ok = ok, error = err, checks = results }) }, base .. "/runtime-result.json")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS " .. #results .. " Spring runtime checks; owned services stopped")
vim.cmd("qa!")
