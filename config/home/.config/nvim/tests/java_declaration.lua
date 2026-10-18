-- lua tests/java_declaration.lua（也支持 luajit）；只测声明和模拟回调，不启动 Neovim 配置或插件。
local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/java_declaration%.lua$") or "."
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
local count = 0
local function eq(actual, expected, label)
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
  compare(actual, expected, label)
  count = count + 1
end
local real_require, real_vim = require, _G.vim
local real_execute, real_popen = os.execute, io.popen
local function forbidden()
  error("Java declaration attempted to start a process")
end
os.execute, io.popen = forbidden, forbidden
_G.vim = setmetatable({}, {
  __index = function(_, key)
    error("Java declaration eagerly accessed vim." .. tostring(key))
  end,
  __newindex = function(_, key)
    error("Java declaration eagerly changed vim." .. tostring(key))
  end,
})
_G.require = function(name)
  assert(name == "languages.java" or name == "languages.java.spring", "eager runtime/plugin require: " .. name)
  return real_require(name)
end
local declaration
for _, spring_first in ipairs({ false, true }) do
  package.loaded["languages.java"], package.loaded["languages.java.spring"] = nil, nil
  if spring_first then
    require("languages.java.spring")
  end
  declaration = require("languages.java")
  eq(type(declaration), "table", "Java returns a declaration")
  eq(getmetatable(declaration), nil, "Java returns a plain table")
  eq(#declaration.plugins, 2, "only existing Java and Spring plugins")
  eq(declaration.plugins[2] == require("languages.java.spring")[1], true, "Spring remains a nested feature")
end
_G.require, _G.vim = real_require, real_vim
os.execute, io.popen = real_execute, real_popen

eq(declaration.managed_lsp, { "jdtls", "spring-boot" }, "Java servers remain self-managed")
eq(declaration.lsp, nil, "no generic Java LSP startup")
eq(declaration.lsp_enabled, nil, "no new Java LSP gate")
eq(declaration.dap, nil, "Java DAP remains wired by nvim-jdtls")
eq(
  declaration.tools,
  { "jdtls", "java-debug-adapter", "java-test", "vscode-spring-boot-tools", "google-java-format" },
  "unchanged Mason tools"
)
eq(declaration.treesitter, { parsers = { "java" }, filetypes = { "java" }, indent = { "java" } }, "Java Treesitter")
eq(declaration.formatters, { java = { "google-java-format" } }, "Java formatter")
eq(declaration.formatter_options, { ["google-java-format"] = { prepend_args = { "--aosp" } } }, "AOSP formatter style")
eq(declaration.format_on_save, { java = false }, "no Java formatting on save")
eq(declaration.buffer_options, { java = { tabstop = 4, shiftwidth = 4 } }, "four-space indentation")
local jdtls, spring = declaration.plugins[1], declaration.plugins[2]
eq(jdtls[1], "mfussenegger/nvim-jdtls", "same JDTLS plugin")
eq(jdtls.ft, "java", "Java filetype trigger")
eq(jdtls.cmd, { "JavaBuildProjects", "JavaSetRuntime" }, "JDTLS command triggers")
eq(jdtls.dependencies, { "JavaHello/spring-boot.nvim" }, "Spring extension dependency")
eq(jdtls.opts, {
  settings = {
    java = {
      inlayHints = { parameterNames = { enabled = "all" } },
      maven = { downloadSources = true, downloadJavadoc = false },
      referencesCodeLens = { enabled = true },
      implementationCodeLens = { enabled = true },
      completion = {
        favoriteStaticMembers = {
          "org.junit.Assert.*",
          "org.junit.jupiter.api.Assertions.*",
          "org.mockito.Mockito.*",
          "java.util.Objects.requireNonNull",
          "java.lang.Math.*",
        },
        importOrder = { "java", "javax", "jakarta", "com", "org", "" },
      },
      signatureHelp = { descriptionEnabled = true },
    },
  },
}, "unchanged JDTLS preferences")
eq(spring[1], "JavaHello/spring-boot.nvim", "same Spring plugin")
eq(spring.ft, { "java", "yaml", "jproperties" }, "Spring filetype triggers")
eq(spring.cmd, "SpringBoot", "Spring command trigger")
eq(
  declaration.commands.JavaRun.opts,
  { desc = "保存并运行当前 Java 源码（支持终端输入）" },
  "JavaRun options"
)
eq(
  declaration.commands.SpringBootCreate.opts,
  { desc = "Spring Boot 项目向导（官方 Initializr）" },
  "SpringBootCreate options"
)

local calls, selected_root = {}, nil
local markers = { "pom.xml" }
local launch = {
  root_dir = function(buf, on_dir)
    calls.gate = (calls.gate or 0) + 1
    eq(buf, 19, "Spring root buffer forwarded")
    on_dir(selected_root)
  end,
}
local rpc_error = { code = -32603 }
local modules = {
  ["languages.java.files"] = {
    run = function()
      calls.run = (calls.run or 0) + 1
    end,
    generate = function(kind)
      calls.generated = kind
    end,
  },
  ["languages.java.spring.wizard"] = {
    create = function()
      calls.wizard = (calls.wizard or 0) + 1
    end,
  },
  ["languages.java.project"] = {
    markers = markers,
    root = function(buf)
      eq(buf, 19, "Spring build-root guard uses requested buffer")
      return selected_root
    end,
  },
  ["languages.java.lsp"] = {
    setup = function(opts)
      calls.lsp_opts = opts
    end,
    execute_client_command = function(err, params, ctx)
      calls.rpc = { err, params, ctx }
      return nil, rpc_error
    end,
  },
  ["spring_boot.launch"] = launch,
  ["spring_boot.util"] = {
    has_spring_boot_dependency = function(path)
      calls.filter_root = path
      return false
    end,
  },
  spring_boot = {
    setup = function(opts)
      calls.spring_opts = opts
    end,
  },
}
_G.require = function(name)
  return assert(modules[name], "unexpected callback module: " .. name)
end
declaration.commands.JavaRun.callback({})
declaration.commands.SpringBootCreate.callback({})
eq(calls.run, 1, "JavaRun routes to Java files helper")
eq(calls.wizard, 1, "SpringBootCreate routes to nested wizard")
eq(#declaration.keys, 5, "only five existing global language keys")
local expected_keys = {
  ["<leader>Gc"] = "class",
  ["<leader>Gi"] = "interface",
  ["<leader>Ge"] = "enum",
  ["<leader>Gr"] = "record",
}
local seen = {}
for _, key in ipairs(declaration.keys) do
  eq(key.mode or "n", "n", "global key normal mode")
  eq(seen[key[1]], nil, "no duplicate global key")
  seen[key[1]] = true
  if key[1] == "<leader>sp" then
    eq(key[2], "<cmd>SpringBootCreate<cr>", "Spring wizard global key")
  else
    local kind = assert(expected_keys[key[1]], "unexpected global key " .. key[1])
    calls.generated = nil
    key[2]()
    eq(calls.generated, kind, "template callback captures " .. kind)
    eq(key.desc, "生成: Java " .. kind, "template description")
  end
end
jdtls.config(nil, jdtls.opts)
eq(calls.lsp_opts == jdtls.opts, true, "JDTLS options forwarded unchanged")
eq(spring.opts.project_filter("/mock/project"), false, "Spring dependency filter result retained")
eq(calls.filter_root, "/mock/project", "Spring dependency filter root forwarded")
local found
local function on_dir(path)
  found = path
end
spring.opts.server.root_dir(19, on_dir)
eq(calls.gate, nil, "single-file Spring gate never falls back to cwd")
selected_root = "/mock/project"
spring.opts.server.root_dir(19, on_dir)
eq(calls.gate, 1, "build project delegates to installed Spring gate")
eq(found, selected_root, "Spring root callback forwarded")
local params, ctx = { command = "probe" }, { client_id = 42 }
local result, err = spring.opts.server.handlers["workspace/executeClientCommand"](false, params, ctx)
eq(result, nil, "Spring wrapper retains nil on RPC error")
eq(err == rpc_error, true, "Spring wrapper retains second RPC error result")
eq(calls.rpc, { false, params, ctx }, "Spring RPC arguments forwarded unchanged")
spring.config(nil, spring.opts)
eq(launch.root_markers == markers, true, "Spring shares Java root markers")
eq(calls.spring_opts == spring.opts, true, "Spring options forwarded unchanged")
_G.require = real_require
print("PASS " .. count .. " Java declaration assertions; no plugins/processes loaded")
