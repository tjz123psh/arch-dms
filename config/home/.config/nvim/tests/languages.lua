-- nvim -u NONE -i NONE -n --headless -l tests/languages.lua
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.g.mapleader = " "
local registry = require("languages")
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
end
local runtime_reads, original_runtime = 0, vim.api.nvim_get_runtime_file
vim.api.nvim_get_runtime_file = function(...)
  runtime_reads = runtime_reads + 1
  return original_runtime(...)
end
check(registry.validate(), "valid declaration graph")
check(runtime_reads == 0, "validation does not evaluate runtime factories")
local names = {}
for _, name in ipairs(registry.names) do
  names[name] = true
  check(vim.uv.fs_stat(root .. "/lua/languages/" .. name .. "/init.lua") ~= nil, name .. " has its own folder entry")
  for _, path in ipairs(vim.fn.globpath(root .. "/lua/languages/" .. name, "**/*.lua", false, true)) do
    local text = table.concat(vim.fn.readfile(path), "\n")
    for target in text:gmatch([=[require%s*%(%s*["']languages%.([%w_]+)]=]) do
      check(target == name or target == "shared", name .. " must not depend on another language: " .. target)
    end
    check(not text:find("core.java", 1, true) and not text:find("plugins.lang", 1, true), "no retired source reference")
  end
end
for name, kind in vim.fs.dir(root .. "/lua/languages") do
  if kind == "directory" and name ~= "shared" then
    check(names[name], "unregistered language folder: " .. name)
  end
end
check(#registry.tools() == 20, "same 20 deduplicated tools")
check(#registry.names == 12, "twelve configured languages remain")
local ts = registry.treesitter()
check(#ts.ensure_installed == 16, "sixteen retained/shared parsers")
for _, name in ipairs({ "bash", "python", "vim", "javascript", "typescript", "vue", "svelte" }) do
  check(not names[name], name .. " is no longer registered")
  check(not vim.uv.fs_stat(root .. "/lua/languages/" .. name), name .. " directory removed")
end
for _, parser in ipairs({ "bash", "vim", "vimdoc", "javascript", "typescript", "tsx", "vue", "svelte" }) do
  check(not vim.tbl_contains(ts.ensure_installed, parser), "removed parser declaration: " .. parser)
end
for _, ft in ipairs({ "bash", "sh", "vim", "javascript", "typescript", "typescriptreact", "vue", "svelte" }) do
  check(not vim.tbl_contains(ts.highlight_filetypes, ft), "removed highlight declaration: " .. ft)
end
local servers = registry.servers()
check(
  runtime_reads == 1 and type(servers.lua_ls.settings.Lua.workspace.library) == "table",
  "Lua libraries resolve only when consumed"
)
check(not servers.jdtls and not servers["spring-boot"], "custom Java servers never auto-started by generic LSP")
local dap = registry.dap()
check(
  type(dap.adapters.codelldb) == "function" and type(dap.adapters.delve) == "function",
  "deferred adapter callbacks"
)
check(
  #dap.configurations.c == 2
    and #dap.configurations.cpp == 3
    and #dap.configurations.rust == 2
    and #dap.configurations.go == 1,
  "all debugger configurations preserved"
)
local java = require("languages.java")
java.lsp = { jdtls = {} }
check(not pcall(registry.validate), "reject duplicate manual server ownership")
java.lsp = nil
local rust = require("languages.rust")
rust.lsp.clangd = { cmd = { "wrong" } }
check(not pcall(registry.validate), "reject conflicting shared server")
rust.lsp.clangd = nil
registry.setup()
local hooks = vim.api.nvim_get_autocmds({ group = "language_options" })
for _, hook in ipairs(hooks) do
  check(hook.pattern ~= "python", "Python-specific indentation override removed")
end
registry.setup()
check(vim.deep_equal(hooks, vim.api.nvim_get_autocmds({ group = "language_options" })), "setup is idempotent")
for _, command in ipairs({ "R", "JavaRun", "SpringBootCreate" }) do
  check(vim.fn.exists(":" .. command) == 2, "command " .. command)
end
for _, key in ipairs({ "sp", "Gc", "Gi", "Ge", "Gr", "Mp", "Me", "Mc" }) do
  check(vim.fn.maparg("<leader>" .. key, "n") ~= "", "key " .. key)
end
for _, sample in ipairs({ { "java", 4 }, { "lua", 2 }, { "c", 4 }, { "cpp", 4 } }) do
  vim.bo.filetype = sample[1]
  check(vim.bo.shiftwidth == sample[2] and vim.bo.tabstop == sample[2], "buffer options " .. sample[1])
end
check(vim.filetype.match({ filename = "x.gotmpl" }) == "gotmpl", "Go template alias")
check(vim.filetype.match({ filename = "x.mdx" }) == "markdown.mdx", "MDX alias")
check(vim.filetype.match({ filename = "docker-compose.yml" }) == "yaml.docker-compose", "YAML alias")
check(registry.conform().format_on_save.java == false, "Java save formatting policy preserved")
check(
  not package.loaded.dap
    and not package.loaded.jdtls
    and not package.loaded.spring_boot
    and not package.loaded["languages.java.lsp"]
    and not package.loaded["languages.java.spring.wizard"],
  "registration does not load implementation/plugins"
)
package.loaded.languages = nil
local independent = require("languages")
independent.names = vim.tbl_filter(function(name)
  return name ~= "c" and name ~= "cpp"
end, independent.names)
check(
  independent.validate() and independent.dap().adapters.codelldb ~= nil,
  "Rust debugger independent from C/C++ registration"
)
vim.api.nvim_get_runtime_file = original_runtime
print("PASS " .. checks .. " language architecture assertions")
vim.cmd("qa!")
