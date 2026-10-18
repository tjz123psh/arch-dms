-- 在临时无依赖项目上验证 Go/Rust/C/C++ 的真实共享操作；禁止联网下载。
local base = assert(vim.env.NVIM_LANGUAGE_TEST_TMP, "set a fresh isolated temporary directory")
assert(base:match("^/tmp/nvim%-language%-"), "isolated test directory required")
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local bin = vim.env.HOME .. "/.local/share/nvim/mason/bin/"
local shared = require("languages.shared.actions")
vim.o.hidden = true
local specs = {
  {
    ft = "go",
    name = "gopls",
    file = "main.go",
    cmd = { bin .. "gopls" },
    files = { ["go.mod"] = { "module example.com/language_actions", "go 1.20" } },
    source = { "package main", "import (", '  "os"', '  "fmt"', ")", "func main() {", "  fmt.Println(1 + 2)", "}" },
  },
  {
    ft = "rust",
    name = "rust_analyzer",
    file = "src/main.rs",
    cmd = { bin .. "rust-analyzer" },
    files = {
      ["Cargo.toml"] = { "[package]", 'name = "language_actions_probe"', 'version = "0.1.0"', 'edition = "2021"' },
    },
    settings = {
      ["rust-analyzer"] = { checkOnSave = false, cargo = { offline = true }, procMacro = { enable = false } },
    },
    source = {
      "use std::fmt::Debug;",
      "use std::collections::HashMap;",
      "fn main() {",
      "  let value = 1 + 2;",
      '  println!("{}", value);',
      "}",
    },
  },
  {
    ft = "c",
    name = "clangd",
    file = "main.c",
    cmd = { bin .. "clangd", "--background-index=false", "--clang-tidy=false" },
    source = {
      "#include <stdlib.h>",
      "#include <stdio.h>",
      "int main(void) {",
      "  int value = 1 + 2;",
      "  return value;",
      "}",
    },
  },
  {
    ft = "cpp",
    name = "clangd",
    file = "main.cpp",
    cmd = { bin .. "clangd", "--background-index=false", "--clang-tidy=false" },
    source = {
      "#include <vector>",
      "#include <string>",
      "int main() {",
      "  int value = 1 + 2;",
      "  return value;",
      "}",
    },
  },
}
local clients, reports = {}, {}
local function stop_client(client)
  if not vim.lsp.get_client_by_id(client.id) then
    return
  end
  client:stop()
  if not vim.wait(3000, function()
    return vim.lsp.get_client_by_id(client.id) == nil
  end, 20) then
    client:stop(true)
  end
end
local messages = {}
local function settle()
  local ready = false
  vim.defer_fn(function()
    ready = true
  end, 200)
  vim.wait(1000, function()
    return ready
  end, 20)
end
vim.notify = function(message)
  messages[#messages + 1] = tostring(message)
end
local ok, err = xpcall(function()
  for _, spec in ipairs(specs) do
    local dir = base .. "/" .. spec.ft
    assert(not vim.uv.fs_stat(dir), "use fresh fixture root: " .. dir)
    vim.fn.mkdir(dir .. "/src", "p")
    for name, lines in pairs(spec.files or {}) do
      vim.fn.writefile(lines, dir .. "/" .. name)
    end
    local file = dir .. "/" .. spec.file
    vim.fn.writefile(spec.source, file)
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.bo.filetype = spec.ft
    local buf = vim.api.nvim_get_current_buf()
    local indexed = spec.ft ~= "rust"
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.experimental = { serverStatusNotification = true }
    local id = vim.lsp.start({
      name = spec.name,
      cmd = spec.cmd,
      root_dir = dir,
      capabilities = capabilities,
      handlers = {
        ["experimental/serverStatus"] = function(_, status)
          indexed = status.quiescent == true
        end,
      },
      settings = spec.settings,
      cmd_env = { CARGO_NET_OFFLINE = "true", GOPROXY = "off", GOSUMDB = "off", GOTOOLCHAIN = "local" },
    })
    local client = assert(vim.lsp.get_client_by_id(id))
    clients[#clients + 1] = client
    assert(
      vim.wait(30000, function()
        return client.initialized or client:is_stopped()
      end, 20),
      spec.ft .. " init timeout"
    )
    assert(not client:is_stopped(), spec.ft .. " server stopped")
    assert(
      vim.wait(30000, function()
        return indexed
      end, 20),
      spec.ft .. " indexing did not settle"
    )
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { diagnostics = {}, only = { "source.organizeImports" }, triggerKind = 1 }
    local raw
    for _ = 1, 20 do
      raw = client:request_sync("textDocument/codeAction", params, 30000, buf)
      if not (raw and raw.err and raw.err.code == -32801) then
        break
      end
      settle() -- rust-analyzer 初始化索引时可能返回 ContentModified，只重试这个暂态错误。
    end
    assert(raw and not raw.err, spec.ft .. " organize request failed: " .. vim.inspect(raw))
    local kinds = {}
    for _, action in ipairs(raw.result or {}) do
      kinds[#kinds + 1] = action.kind or "<no kind>"
    end
    local provider = client.server_capabilities.codeActionProvider
    local declared = type(provider) == "table" and provider.codeActionKinds or {}
    local pending, completed, menu, transient = 0, false, nil, false
    local request = client.request
    client.request = function(self, method, p, callback, b)
      if method == "textDocument/codeAction" or method == "codeAction/resolve" then
        pending = pending + 1
        return request(self, method, p, function(e, result, ctx, conf)
          transient = transient or (e ~= nil and e.code == -32801)
          callback(e, result, ctx, conf)
          pending = pending - 1
          completed = true
        end, b)
      end
      return request(self, method, p, callback, b)
    end
    vim.ui.select = function(items, _, callback)
      menu = items
      callback(nil)
    end
    local function drive(fn)
      for _ = 1, 20 do
        pending, completed, menu, messages, transient = 0, false, nil, {}, false
        fn()
        assert(
          vim.wait(30000, function()
            return completed and pending == 0
          end, 20),
          spec.ft .. " action timeout: " .. vim.inspect(messages)
        )
        if not transient then
          return
        end
        settle()
      end
      error(spec.ft .. " remained busy indexing")
    end
    drive(shared.organize_imports)
    local after_imports = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local import_messages = vim.deepcopy(messages)
    if spec.ft == "go" then
      assert(not table.concat(after_imports, "\n"):find('"os"', 1, true), "Go unused import was not removed")
      assert(table.concat(after_imports, "\n"):find('"fmt"', 1, true), "Go used import was removed")
    end
    local expression = "1 + 2"
    local selected = false
    for row, line in ipairs(after_imports) do
      local col = line:find(expression, 1, true)
      if col then
        vim.api.nvim_win_set_cursor(0, { row, col - 1 })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { row, col + #expression - 2 })
        selected = true
        break
      end
    end
    assert(selected, "fixture expression missing")
    drive(shared.refactor)
    vim.cmd("normal! \27")
    local refactors = {}
    for _, item in ipairs(menu or {}) do
      assert(item.action.kind == "refactor" or item.action.kind:sub(1, 9) == "refactor.", "non-refactor leaked into Ra")
      refactors[#refactors + 1] = { kind = item.action.kind, title = item.action.title }
    end
    assert(#refactors > 0, spec.ft .. " fixture returned no refactors after indexing")
    assert(
      vim.deep_equal(after_imports, vim.api.nvim_buf_get_lines(buf, 0, -1, false)),
      "cancel Ra changed " .. spec.ft .. " source"
    )
    reports[#reports + 1] = {
      language = spec.ft,
      declaredKinds = declared,
      organizeKinds = kinds,
      organizeChanged = not vim.deep_equal(spec.source, after_imports),
      organizeMessages = import_messages,
      refactors = refactors,
      refactorMessages = vim.deepcopy(messages),
    }
    stop_client(client)
  end
end, debug.traceback)
for _, client in ipairs(clients) do
  stop_client(client)
end
vim.wait(5000, function()
  for _, client in ipairs(clients) do
    if not client:is_stopped() then
      return false
    end
  end
  return true
end, 20)
print("LANGUAGE_ACTION_RESULTS=" .. vim.json.encode(reports))
assert(ok, err)
print("PASS real Go/Rust/C/C++ shared actions; all test clients stopped")
vim.cmd("qa!")
