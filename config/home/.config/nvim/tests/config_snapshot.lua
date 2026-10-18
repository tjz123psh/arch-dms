-- Run with the full configuration and isolated XDG paths; compare decoded JSON, not table order.
local out = assert(vim.env.NVIM_SNAPSHOT_OUT)
assert(out:match("^/tmp/nvim%-"), "snapshot output must stay in the test directory")
vim.o.columns, vim.o.lines = 120, 40
local function snapshot()
  local roots = {
    { vim.fn.stdpath("config"), "<config>" },
    { vim.fn.stdpath("data"), "<data>" },
    { vim.fn.stdpath("state"), "<state>" },
    { vim.fn.stdpath("cache"), "<cache>" },
  }
  local function normalize(value, seen)
    if type(value) == "function" then
      return "<function>"
    end
    if type(value) == "string" then
      for _, root in ipairs(roots) do
        value = value:gsub(vim.pesc(root[1]), root[2])
      end
      return value
    end
    if type(value) ~= "table" then
      return value
    end
    seen = seen or {}
    if seen[value] then
      return "<cycle>"
    end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
      result[key] = normalize(item, seen)
    end
    seen[value] = nil
    return result
  end
  local result = { options = {}, globals = {}, maps = {}, commands = {}, plugins = {}, plugin_options = {} }
  for _, name in ipairs({
    "number",
    "relativenumber",
    "signcolumn",
    "cursorline",
    "termguicolors",
    "fillchars",
    "scrolloff",
    "sidescrolloff",
    "splitbelow",
    "splitright",
    "winborder",
    "tabstop",
    "shiftwidth",
    "expandtab",
    "smartindent",
    "ignorecase",
    "smartcase",
    "hlsearch",
    "inccommand",
    "updatetime",
    "timeoutlen",
    "clipboard",
    "undofile",
    "shell",
    "completeopt",
    "confirm",
    "cmdheight",
    "modeline",
  }) do
    result.options[name] = vim.o[name]
  end
  for _, name in ipairs({
    "mapleader",
    "maplocalleader",
    "cjk_punct",
    "loaded_node_provider",
    "loaded_python3_provider",
    "loaded_perl_provider",
    "loaded_ruby_provider",
  }) do
    result.globals[name] = vim.g[name]
  end
  for _, mode in ipairs({ "n", "i", "v", "x", "s", "o", "t", "c" }) do
    local maps = {}
    for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
      local map = {}
      for _, key in ipairs({ "lhs", "rhs", "callback", "desc", "expr", "silent", "noremap", "nowait" }) do
        map[key] = mapping[key]
      end
      maps[#maps + 1] = map
    end
    table.sort(maps, function(a, b)
      return a.lhs < b.lhs
    end)
    result.maps[mode] = maps
  end
  for name, command in pairs(vim.api.nvim_get_commands({ builtin = false })) do
    local row = {}
    for _, key in ipairs({ "nargs", "bang", "bar", "complete", "range", "count", "register" }) do
      row[key] = command[key]
    end
    result.commands[name] = row
  end
  local config = require("lazy.core.config")
  for name in pairs(config.plugins) do
    result.plugins[#result.plugins + 1] = name
  end
  table.sort(result.plugins)
  for _, name in ipairs({
    "which-key.nvim",
    "blink.cmp",
    "conform.nvim",
    "nvim-lspconfig",
    "mason.nvim",
    "mason-tool-installer.nvim",
    "snacks.nvim",
    "noice.nvim",
    "neo-tree.nvim",
    "bufferline.nvim",
    "sidekick.nvim",
  }) do
    result.plugin_options[name] = require("lazy.core.plugin").values(config.plugins[name], "opts", false)
  end
  result.diagnostics = vim.diagnostic.config()
  result.dap = { adapters = require("dap").adapters, configurations = require("dap").configurations }
  result.skins = {}
  for _, skin in ipairs({ "soft", "pink" }) do
    vim.cmd.PickerSkin(skin)
    local highlights = {}
    for _, name in ipairs({
      "FloatBorder",
      "FloatTitle",
      "NormalFloat",
      "SnacksPickerBorder",
      "SnacksPickerListCursorLine",
      "SnacksPickerMatch",
      "SnacksInputBorder",
      "NoiceCmdlinePopup",
      "WizBorder",
      "WizTitle",
      "CheatSheetKey",
    }) do
      highlights[name] = vim.api.nvim_get_hl(0, { name = name })
    end
    result.skins[skin] = highlights
  end
  vim.fn.writefile({ vim.json.encode(normalize(result)) }, out)
  print("SNAPSHOT " .. #result.plugins .. " plugins; " .. vim.tbl_count(result.commands) .. " commands")
end
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    require("lazy").load({
      plugins = {
        "which-key.nvim",
        "nvim-dap",
        "toggleterm.nvim",
        "neo-tree.nvim",
        "alpha-nvim",
        "flash.nvim",
        "conform.nvim",
      },
    })
    vim.defer_fn(function()
      local ok, err = xpcall(snapshot, debug.traceback)
      if not ok then
        io.stderr:write(err .. "\n")
        vim.cmd("cquit 1")
      else
        vim.cmd("qa!")
      end
    end, 1300)
  end,
})
