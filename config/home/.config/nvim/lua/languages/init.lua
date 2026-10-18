local M = {}

-- 明确注册：不会把语言目录里的 helper 当作插件或另一种语言加载。
M.names = {
  "c",
  "cpp",
  "go",
  "java",
  "rust",
  "lua",
  "html",
  "css",
  "json",
  "yaml",
  "xml",
  "markdown",
}
local fields = {
  lsp = true,
  lsp_enabled = true,
  managed_lsp = true,
  tools = true,
  treesitter = true,
  formatters = true,
  formatter_options = true,
  format_on_save = true,
  filetypes = true,
  buffer_options = true,
  plugins = true,
  commands = true,
  keys = true,
  dap = true,
  actions = true,
}
local definitions, initialized

local function all()
  if not definitions then
    local loaded = { { name = "shared", value = require("languages.shared") } }
    for _, name in ipairs(M.names) do
      local value = require("languages." .. name)
      assert(type(value) == "table", "languages/" .. name .. "/init.lua must return a declaration")
      for field, data in pairs(value) do
        assert(fields[field], "unknown languages/" .. name .. " field: " .. field)
        assert(type(data) == "table", "languages/" .. name .. "." .. field .. " must be a table")
      end
      loaded[#loaded + 1] = { name = name, value = value }
    end
    definitions = loaded -- 只缓存完整结果，加载失败不能留下半份注册表。
  end
  return definitions
end

local function list(field, nested)
  local result, seen = {}, {}
  for _, definition in ipairs(all()) do
    local values = definition.value[field] or {}
    values = nested and (values[nested] or {}) or values
    for _, value in ipairs(values) do
      assert(type(value) == "string", definition.name .. "." .. field .. " must contain names")
      if not seen[value] then
        result[#result + 1], seen[value] = value, true
      end
    end
  end
  return result
end

local function map(field, nested)
  local result, owners = {}, {}
  for _, definition in ipairs(all()) do
    local values = definition.value[field] or {}
    values = nested and (values[nested] or {}) or values
    for key, value in pairs(values) do
      assert(
        result[key] == nil or vim.deep_equal(result[key], value),
        ("conflicting %s.%s: %s and %s"):format(field, key, owners[key] or "", definition.name)
      )
      result[key], owners[key] = vim.deepcopy(value), definition.name
    end
  end
  return result
end

function M.servers()
  local result = map("lsp")
  for name, config in pairs(result) do
    if type(config) == "function" then
      result[name] = config()
    end
    assert(type(result[name]) == "table", name .. " must resolve to an LSP configuration")
  end
  return result
end

function M.action(filetype, name)
  for _, definition in ipairs(all()) do
    local actions = (definition.value.actions or {})[filetype]
    if actions and actions[name] then
      return actions[name]
    end
  end
end

function M.lsp_enabled()
  return map("lsp_enabled")
end
function M.tools()
  return list("tools")
end

function M.plugins()
  local specs = {}
  for _, definition in ipairs(all()) do
    vim.list_extend(specs, vim.deepcopy(definition.value.plugins or {}))
  end
  return specs
end

function M.treesitter()
  local indent = {}
  for _, ft in ipairs(list("treesitter", "indent")) do
    indent[ft] = true
  end
  return {
    ensure_installed = list("treesitter", "parsers"),
    highlight_filetypes = list("treesitter", "filetypes"),
    indent_filetypes = indent,
  }
end

function M.conform()
  return {
    formatters_by_ft = map("formatters"),
    formatters = map("formatter_options"),
    format_on_save = map("format_on_save"),
  }
end

function M.dap()
  return { adapters = map("dap", "adapters"), configurations = map("dap", "configurations") }
end

function M.validate()
  local servers = map("lsp") -- 不执行工厂函数：Lua runtimepath 必须在 LSP 接入时才读取。
  for _, name in ipairs(list("managed_lsp")) do
    assert(servers[name] == nil, name .. " is manually managed; automatic startup would duplicate it")
  end
  for name, condition in pairs(M.lsp_enabled()) do
    assert(servers[name] ~= nil and type(condition) == "function", "invalid LSP condition: " .. name)
  end
  local dap = M.dap()
  for ft, configs in pairs(dap.configurations) do
    for _, config in ipairs(configs) do
      assert(dap.adapters[config.type], ft .. " uses undeclared DAP adapter: " .. tostring(config.type))
    end
  end
  local commands, keys = {}, {}
  for _, definition in ipairs(all()) do
    for name, command in pairs(definition.value.commands or {}) do
      assert(not commands[name], "duplicate language command: " .. name)
      assert(type(command.callback) == "function" or type(command.callback) == "string", "invalid command: " .. name)
      commands[name] = true
    end
    for _, key in ipairs(definition.value.keys or {}) do
      for _, mode in ipairs(type(key.mode) == "table" and key.mode or { key.mode or "n" }) do
        local id = mode .. ":" .. key[1]
        assert(not keys[id], "duplicate language key: " .. id)
        keys[id] = true
      end
    end
  end
  M.conform()
  map("actions")
  map("buffer_options")
  return true
end

function M.setup()
  if initialized then
    return
  end
  M.validate()
  vim.filetype.add({
    extension = map("filetypes", "extension"),
    filename = map("filetypes", "filename"),
    pattern = map("filetypes", "pattern"),
  })
  local buffer_options = map("buffer_options")
  local group = vim.api.nvim_create_augroup("language_options", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = vim.tbl_keys(buffer_options),
    callback = function(event)
      for option, value in pairs(buffer_options[vim.bo[event.buf].filetype] or {}) do
        vim.bo[event.buf][option] = value
      end
    end,
  })
  for _, definition in ipairs(all()) do
    for name, command in pairs(definition.value.commands or {}) do
      vim.api.nvim_create_user_command(name, command.callback, vim.deepcopy(command.opts or {}))
    end
    for _, key in ipairs(definition.value.keys or {}) do
      local opts = vim.deepcopy(key)
      opts[1], opts[2], opts.mode = nil, nil, nil
      vim.keymap.set(key.mode or "n", key[1], key[2], opts)
    end
  end
  initialized = true
end

return M
