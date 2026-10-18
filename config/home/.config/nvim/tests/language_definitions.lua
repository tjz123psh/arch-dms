-- 运行：lua tests/language_definitions.lua（也支持 luajit）；不加载完整配置、插件或真实服务。
local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/language_definitions%.lua$") or "."
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local count = 0
local function eq(actual, expected, message)
  local function compare(a, b, path)
    assert(type(a) == type(b), path .. ": expected " .. type(b) .. ", got " .. type(a))
    if type(b) == "table" then
      for key, value in pairs(b) do
        compare(a[key], value, path .. "." .. tostring(key))
      end
      for key in pairs(a) do
        assert(b[key] ~= nil, path .. ": unexpected key " .. tostring(key))
      end
    else
      assert(a == b, path .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
    end
  end
  compare(actual, expected, message)
  count = count + 1
end
local function keys(value)
  local result = {}
  for key in pairs(value or {}) do
    result[#result + 1] = key
  end
  table.sort(result, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return result
end
local function words(value)
  local result = {}
  for word in value:gmatch("%S+") do
    result[#result + 1] = word
  end
  table.sort(result)
  return result
end

local names = {
  "rust", -- 故意先加载 Rust，证明不依赖 C/C++ 入口。
  "c",
  "cpp",
  "go",
  "lua",
  "html",
  "css",
  "json",
  "yaml",
  "xml",
  "markdown",
}
local allowed = {
  ["languages.shared.clangd"] = true,
  ["languages.shared.codelldb"] = true,
  ["languages.markdown.render"] = true,
}
for _, name in ipairs(names) do
  allowed["languages." .. name] = true
end
local real_require, real_vim = require, _G.vim
local real_execute, real_popen = os.execute, io.popen
local function forbidden()
  error("language declaration attempted to start a process")
end
os.execute, io.popen = forbidden, forbidden
_G.vim = setmetatable({}, {
  __index = function(_, key)
    error("language declaration eagerly accessed vim." .. tostring(key))
  end,
  __newindex = function(_, key)
    error("language declaration eagerly changed vim." .. tostring(key))
  end,
})
_G.require = function(name)
  assert(allowed[name], "language declaration loaded an external module: " .. name)
  return real_require(name)
end
local function load_declarations(order)
  for name in pairs(allowed) do
    package.loaded[name] = nil
  end
  local definitions = {}
  for index, name in ipairs(order) do
    local definition = require("languages." .. name)
    eq(type(definition), "table", name .. " is a declaration table")
    eq(getmetatable(definition), nil, name .. " is a plain table")
    definitions[name] = definition
    if index == 1 and name == "rust" then
      eq(package.loaded["languages.c"], nil, "Rust does not load C")
      eq(package.loaded["languages.cpp"], nil, "Rust does not load C++")
      eq(type(definition.dap.adapters.codelldb), "function", "Rust declares its own shared adapter")
    end
  end
  eq(definitions.c.lsp.clangd, definitions.cpp.lsp.clangd, "C/C++ share clangd table")
  eq(definitions.c.dap.adapters.codelldb, definitions.cpp.dap.adapters.codelldb, "C/C++ share adapter")
  eq(definitions.c.dap.adapters.codelldb, definitions.rust.dap.adapters.codelldb, "Rust shares adapter")
  eq(rawequal(definitions.c.lsp.clangd, definitions.cpp.lsp.clangd), true, "clangd identity is shared")
  return definitions
end
load_declarations(names)
local reverse = {}
for index = #names, 1, -1 do
  reverse[#reverse + 1] = names[index]
end
local definitions = load_declarations(reverse)
_G.require = real_require

local fields = {
  c = "buffer_options dap formatters lsp tools treesitter",
  cpp = "buffer_options dap formatters lsp tools treesitter",
  go = "dap filetypes lsp tools treesitter",
  rust = "dap formatters lsp lsp_enabled tools treesitter",
  lua = "buffer_options commands formatters lsp plugins tools treesitter",
  html = "lsp tools treesitter",
  css = "lsp tools treesitter",
  json = "lsp tools treesitter",
  yaml = "filetypes lsp tools treesitter",
  xml = "lsp tools",
  markdown = "filetypes keys lsp plugins tools treesitter",
}
local servers = {
  c = { "clangd" },
  cpp = { "clangd" },
  go = { "gopls" },
  rust = { "rust_analyzer" },
  lua = { "lua_ls" },
  html = { "html" },
  css = { "cssls" },
  json = { "jsonls" },
  yaml = { "yamlls" },
  xml = { "lemminx" },
  markdown = { "marksman" },
}
local tools_by_language = {
  c = { "clangd", "codelldb", "clang-format" },
  cpp = { "clangd", "codelldb", "clang-format" },
  go = { "gopls", "delve" },
  rust = { "rust-analyzer", "codelldb" },
  lua = { "lua-language-server", "stylua" },
  html = { "html-lsp" },
  css = { "css-lsp" },
  json = { "json-lsp" },
  yaml = { "yaml-language-server" },
  xml = { "lemminx" },
  markdown = { "marksman" },
}
local treesitter = {
  c = { parsers = { "c" }, filetypes = { "c" }, indent = { "c" } },
  cpp = { parsers = { "cpp" }, filetypes = { "cpp" }, indent = { "cpp" } },
  go = { parsers = { "go" }, filetypes = { "go" }, indent = { "go" } },
  rust = { parsers = { "rust" }, filetypes = { "rust" }, indent = { "rust" } },
  lua = { parsers = { "lua" }, filetypes = { "lua" }, indent = { "lua" } },
  html = { parsers = { "html" }, filetypes = { "html" } },
  css = { parsers = { "css", "scss" }, filetypes = { "css", "scss" } },
  json = { parsers = { "json" }, filetypes = { "json", "jsonc" } },
  yaml = { parsers = { "yaml" }, filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" } },
  markdown = { parsers = { "markdown", "markdown_inline" }, filetypes = { "markdown", "markdown.mdx" } },
}
local formatters = {
  c = { c = { "clang-format" } },
  cpp = { cpp = { "clang-format" } },
  rust = { rust = { "rustfmt" } },
  lua = { lua = { "stylua" } },
}
local buffer_options = {
  c = { c = { tabstop = 4, shiftwidth = 4 } },
  cpp = { cpp = { tabstop = 4, shiftwidth = 4 } },
  lua = { lua = { tabstop = 2, shiftwidth = 2 } },
}
local filetypes = {
  go = { extension = { gotmpl = "gotmpl" } },
  markdown = { extension = { mdx = "markdown.mdx" } },
  yaml = {
    filename = {
      [".gitlab-ci.yml"] = "yaml.gitlab",
      [".gitlab-ci.yaml"] = "yaml.gitlab",
      ["docker-compose.yml"] = "yaml.docker-compose",
      ["docker-compose.yaml"] = "yaml.docker-compose",
    },
    pattern = {
      [".*/docker%-compose%..*%.yml"] = "yaml.docker-compose",
      [".*/docker%-compose%..*%.yaml"] = "yaml.docker-compose",
      [".*/compose%.yml"] = "yaml.docker-compose",
      [".*/compose%.yaml"] = "yaml.docker-compose",
      [".*/templates/.*%.yml"] = "yaml.helm-values",
      [".*/templates/.*%.yaml"] = "yaml.helm-values",
    },
  },
}
local all_tools, all_parsers = {}, {}
for _, name in ipairs(names) do
  local definition = definitions[name]
  eq(keys(definition), words(fields[name]), name .. " contract fields")
  eq(keys(definition.lsp), servers[name] or {}, name .. " LSP ownership")
  eq(definition.tools or {}, tools_by_language[name] or {}, name .. " Mason tools")
  eq(definition.treesitter or {}, treesitter[name] or {}, name .. " Treesitter ownership")
  eq(definition.formatters or {}, formatters[name] or {}, name .. " formatters")
  eq(definition.buffer_options or {}, buffer_options[name] or {}, name .. " buffer options")
  eq(definition.filetypes or {}, filetypes[name] or {}, name .. " filetype aliases")
  for _, tool in ipairs(definition.tools or {}) do
    all_tools[tool] = true
  end
  for _, parser in ipairs((definition.treesitter or {}).parsers or {}) do
    all_parsers[parser] = true
  end
end
eq(
  keys(all_tools),
  words(
    "clangd clang-format codelldb css-lsp delve gopls html-lsp json-lsp lemminx lua-language-server marksman rust-analyzer stylua yaml-language-server"
  ),
  "complete scoped Mason baseline; no rustfmt/tree-sitter-cli"
)
eq(
  keys(all_parsers),
  words("c cpp css go html json lua markdown markdown_inline rust scss yaml"),
  "retained scoped parser baseline; no removed or Java/helper entries"
)
for _, name in ipairs({ "html", "css", "json", "yaml", "markdown" }) do
  eq(definitions[name].lsp[servers[name][1]], {}, name .. " retains default LSP configuration")
end
eq(definitions.go.lsp.gopls, {
  settings = {
    gopls = { gofumpt = true, analyses = { unusedparams = true, unreachable = true }, staticcheck = true },
  },
}, "gopls settings")
eq(
  definitions.rust.lsp.rust_analyzer,
  { settings = { ["rust-analyzer"] = { check = { command = "clippy" }, procMacro = { enable = true } } } },
  "rust-analyzer settings"
)
eq(keys(definitions.rust.lsp_enabled), { "rust_analyzer" }, "Rust enable guard ownership")
eq(definitions.xml.lsp.lemminx, { filetypes = { "xml", "xsd", "xslt", "svg" } }, "XML excludes unknown xsl filetype")

-- 只提供被迁移回调确实需要的模拟 API；不依赖本机 runtimepath、工具链或插件安装。
local runtime_files, runtime_reads, path_reads = { "/runtime/first/lua" }, 0, 0
local executable_status, deferred, notifications, input_requests = {}, {}, {}, {}
local buffer_name, project_root = "/fixture/project/src/main.cpp", "/fixture/repository"
local root_queries, luafiles, input_answer = {}, {}, nil
_G.vim = {
  api = {
    nvim_get_runtime_file = function(pattern, all)
      eq({ pattern, all }, { "lua", true }, "Lua runtime library query")
      runtime_reads = runtime_reads + 1
      return runtime_files
    end,
    nvim_buf_get_name = function(bufnr)
      eq(bufnr, 27, "clangd uses requested buffer")
      return buffer_name
    end,
  },
  fs = {
    root = function(fname, markers)
      root_queries[#root_queries + 1] = { fname, markers }
      return project_root
    end,
  },
  fn = {
    stdpath = function(kind)
      eq(kind, "data", "adapter uses data directory")
      path_reads = path_reads + 1
      return "/fixture/data"
    end,
    executable = function(name)
      assert(name == "rustc" or name == "cargo", "unexpected toolchain check: " .. name)
      return executable_status[name] or 0
    end,
    getcwd = function()
      return "/fixture/project"
    end,
    input = function(prompt, default, completion)
      input_requests[#input_requests + 1] = { prompt, default, completion }
      if input_answer ~= nil then
        return input_answer
      end
      return prompt == "进程 PID: " and "12345" or "/fixture/binary"
    end,
    expand = function(pattern)
      assert(pattern == "%:t:r" or pattern == "%:p", "unexpected path expansion")
      return pattern == "%:t:r" and "main" or "/fixture/config.lua"
    end,
  },
  log = { levels = { WARN = 2, INFO = 1 } },
  schedule = function(callback)
    deferred[#deferred + 1] = callback
  end,
  notify = function(message, level)
    notifications[#notifications + 1] = { message, level }
  end,
  bo = { filetype = "lua" },
  cmd = {
    luafile = function(path)
      luafiles[#luafiles + 1] = path
    end,
  },
}
eq(runtime_reads, 0, "no early Lua runtime library read")
eq(type(definitions.lua.lsp.lua_ls), "function", "Lua server is a zero-argument factory")
local lua_config = definitions.lua.lsp.lua_ls()
eq(lua_config, {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim", "jit" } },
      workspace = { checkThirdParty = false, library = { "/runtime/first/lua" } },
      telemetry = { enable = false },
    },
  },
}, "Lua complete settings")
runtime_files = { "/runtime/later/lua", "/plugins/lua" }
local later_config = definitions.lua.lsp.lua_ls()
eq(later_config.settings.Lua.workspace.library, runtime_files, "Lua factory reads current runtimepath")
eq(lua_config.settings.Lua.workspace.library, { "/runtime/first/lua" }, "Lua factories do not share mutable config")
eq(runtime_reads, 2, "runtime library queried only when consumed")

for _, status in ipairs({ { 1, 1, true }, { 0, 1, false }, { 1, 0, false }, { 0, 0, false } }) do
  executable_status = { rustc = status[1], cargo = status[2] }
  deferred, notifications = {}, {}
  eq(definitions.rust.lsp_enabled.rust_analyzer(), status[3], "Rust guard requires rustc and cargo")
  eq(#deferred, status[3] and 0 or 1, "Rust missing-tool warning remains scheduled")
  eq(notifications, {}, "Rust warning is not emitted synchronously")
  if not status[3] then
    deferred[1]()
    eq(
      notifications,
      { { "Rust 工具链未安装，已跳过 rust-analyzer。安装 rust 后重新打开项目即可。", 2 } },
      "Rust warning text and severity"
    )
  end
end

local clangd = definitions.c.lsp.clangd
eq(keys(clangd), { "cmd", "filetypes", "root_dir" }, "clangd configuration fields")
eq(
  clangd.cmd,
  { "clangd", "--background-index", "--clang-tidy", "--completion-style=detailed", "--header-insertion=iwyu" },
  "clangd command"
)
eq(clangd.filetypes, { "c", "cpp", "objc", "objcpp", "cuda", "proto" }, "clangd filetypes")
local chosen_roots = {}
local function on_dir(dir)
  chosen_roots[#chosen_roots + 1] = dir
end
clangd.root_dir(27, on_dir)
eq(
  root_queries,
  { { buffer_name, { ".clangd", "compile_commands.json", "build/compile_commands.json", ".git" } } },
  "clangd project markers"
)
eq(chosen_roots, { "/fixture/repository" }, "clangd detected root")
project_root = nil
clangd.root_dir(27, on_dir)
eq(chosen_roots, { "/fixture/repository", "/fixture/project" }, "clangd cwd fallback")
for _, unnamed in ipairs({ "", false }) do
  buffer_name = unnamed or nil
  clangd.root_dir(27, on_dir)
end
eq(#chosen_roots, 2, "clangd does not attach unnamed buffer")
eq(#root_queries, 2, "clangd does not search unnamed roots")

local adapter_names = { c = "codelldb", cpp = "codelldb", rust = "codelldb", go = "delve" }
local expected_adapters = {
  codelldb = {
    type = "server",
    port = "${port}",
    executable = { command = "/fixture/data/mason/bin/codelldb", args = { "--port", "${port}" } },
  },
  delve = {
    type = "server",
    port = "${port}",
    executable = { command = "/fixture/data/mason/bin/dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
  },
}
eq(path_reads, 0, "adapter paths not resolved before DAP consumes adapters")
for _, name in ipairs({ "c", "cpp", "rust", "go" }) do
  local adapter_name = adapter_names[name]
  local dap = definitions[name].dap
  eq(keys(dap), { "adapters", "configurations" }, name .. " DAP fields")
  eq(keys(dap.adapters), { adapter_name }, name .. " adapter ownership")
  eq(keys(dap.configurations), { name }, name .. " debug configuration ownership")
  local calls = 0
  dap.adapters[adapter_name](function(adapter)
    calls = calls + 1
    eq(adapter, expected_adapters[adapter_name], name .. " resolved adapter")
  end, { request = "launch" })
  eq(calls, 1, name .. " DAP adapter callback invoked once")
end
eq(path_reads, 4, "adapter paths resolved on demand")
local launch_path = {
  name = "启动调试（输路径）",
  type = "codelldb",
  request = "launch",
  program = "/fixture/binary",
  cwd = "${workspaceFolder}",
  stopOnEntry = false,
}
local launch_file = {
  name = "启动调试（取当前文件名）",
  type = "codelldb",
  request = "launch",
  program = "/fixture/project/main",
  cwd = "${workspaceFolder}",
  stopOnEntry = false,
}
local attach = {
  name = "附加到进程",
  type = "codelldb",
  request = "attach",
  pid = 12345,
  cwd = "${workspaceFolder}",
  stopOnEntry = false,
}
local expected_configs = {
  c = { launch_path, launch_file },
  cpp = { launch_path, launch_file, attach },
  rust = {
    {
      name = "启动调试（cargo 项目）",
      type = "codelldb",
      request = "launch",
      program = "/fixture/binary",
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
    attach,
  },
  go = {
    {
      name = "启动调试",
      type = "delve",
      request = "launch",
      program = "${workspaceFolder}",
      cwd = "${workspaceFolder}",
    },
  },
}
for _, name in ipairs({ "c", "cpp", "rust", "go" }) do
  local resolved = {}
  for index, config in ipairs(definitions[name].dap.configurations[name]) do
    resolved[index] = {}
    for key, value in pairs(config) do
      if type(value) == "function" then
        resolved[index][key] = value()
      else
        resolved[index][key] = value
      end
    end
  end
  eq(resolved, expected_configs[name], name .. " complete debug configurations")
end
eq(input_requests, {
  { "可执行文件路径: ", "/fixture/project/", "file" },
  { "可执行文件路径: ", "/fixture/project/", "file" },
  { "进程 PID: " },
  { "可执行文件路径: ", "/fixture/project/target/debug/", "file" },
  { "进程 PID: " },
}, "debug prompts and default paths")
input_answer = ""
eq(definitions.cpp.dap.configurations.cpp[3].pid(), nil, "C++ cancelled PID remains nil")
eq(definitions.rust.dap.configurations.rust[2].pid(), nil, "Rust cancelled PID remains nil")

local render = {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "markdown.mdx" },
  cmd = "RenderMarkdown",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  opts = {
    render_modes = { "n", "c" },
    anti_conceal = { enabled = true, above = 0, below = 0 },
    sign = { enabled = false },
    heading = { backgrounds = {}, border = false },
    code = {
      style = "language",
      disable_background = true,
      inline = false,
      width = "block",
      border = "none",
      highlight_border = false,
    },
    latex = { enabled = false },
  },
}
eq(definitions.markdown.plugins, { render }, "Markdown plugin unchanged")
eq(
  rawequal(definitions.markdown.plugins[1], package.loaded["languages.markdown.render"]),
  true,
  "Markdown entry references local plugin module"
)
eq(definitions.lua.plugins, { { "folke/lazydev.nvim", ft = "lua", opts = {} } }, "lazydev remains Lua-only plugin spec")
eq(keys(definitions.lua.commands), { "R" }, "Lua command ownership")
local command = definitions.lua.commands.R
eq(keys(command), { "callback", "opts" }, "Lua command shape")
eq(
  command.opts,
  { force = true, desc = "执行当前磁盘 Lua 文件（非完整配置重载）" },
  "Lua command options"
)
notifications = {}
vim.bo.filetype = "text"
command.callback({})
eq(notifications, { { ":R 只能在 .lua 文件中使用", 2 } }, "Lua R rejects other filetypes")
eq(luafiles, {}, "R does not execute other filetypes")
vim.bo.filetype = "lua"
command.callback({})
eq(luafiles, { "/fixture/config.lua" }, "R executes the current disk file only")

eq(#definitions.markdown.keys, 3, "three Markdown keys")
local mdkeys = definitions.markdown.keys
local toggle_key, expand_key, contract_key = mdkeys[1], mdkeys[2], mdkeys[3]
for _, entry in ipairs({ toggle_key, expand_key, contract_key }) do
  eq(keys(entry), { 1, 2, "desc", "mode" }, "Markdown key shape")
  eq(entry.mode, "n", "Markdown key mode is normal")
end
eq(
  { toggle_key[1], toggle_key.desc },
  { "<leader>Mp", "Markdown：开关当前文档美化" },
  "Markdown toggle key unchanged"
)
eq(
  { expand_key[1], expand_key.desc },
  { "<leader>Me", "Markdown：当前行上下各多露一行源码" },
  "Markdown expand key"
)
eq(
  { contract_key[1], contract_key.desc },
  { "<leader>Mc", "Markdown：撤回一行（与 Me 对称）" },
  "Markdown contract key"
)
local calls, plugin_loads = {}, 0
_G.require = function(name)
  eq(name, "render-markdown", "Markdown callbacks lazily load the renderer")
  plugin_loads = plugin_loads + 1
  return {
    buf_toggle = function()
      calls[#calls + 1] = "buf_toggle"
    end,
    expand = function()
      calls[#calls + 1] = "expand"
    end,
    contract = function()
      calls[#calls + 1] = "contract"
    end,
  }
end
for _, ft in ipairs({ "text", "yaml", "markdown_inline" }) do
  notifications = {}
  vim.bo.filetype = ft
  toggle_key[2]()
  expand_key[2]()
  contract_key[2]()
  eq(notifications, {
    { "请先打开 Markdown 文件", 1 },
    { "请先打开 Markdown 文件", 1 },
    { "请先打开 Markdown 文件", 1 },
  }, "Markdown keys guard other filetypes")
end
eq(plugin_loads, 0, "non-Markdown buffers never load the renderer")
for _, ft in ipairs({ "markdown", "markdown.mdx" }) do
  vim.bo.filetype = ft
  toggle_key[2]()
  expand_key[2]()
  contract_key[2]()
end
eq(
  calls,
  { "buf_toggle", "expand", "contract", "buf_toggle", "expand", "contract" },
  "Markdown keys route to toggle/expand/contract (mdx included)"
)

_G.require, _G.vim = real_require, real_vim
os.execute, io.popen = real_execute, real_popen
print("PASS " .. count .. " language declaration assertions; 11 entries; no plugins/processes/full config started")
