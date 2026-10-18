local base = assert(vim.env.NVIM_JAVA_TEST_TMP)
assert(base:match("^/tmp/nvim%-java%-") and vim.fn.stdpath("data"):match("^/tmp/nvim%-java%-"))
local checks = 0
local function check(value, label)
  assert(value, label)
  checks = checks + 1
  print("OK " .. label)
end
local before = {}
for _, c in ipairs(vim.lsp.get_clients()) do
  before[c.id] = true
end
local ok, err = xpcall(function()
  local plugins = require("lazy.core.config").plugins
  check(not plugins["lazydev.nvim"]._.loaded, "lazydev not loaded in blank editor")
  vim.fn.mkdir(base .. "/lua", "p")
  vim.fn.writefile({ "{}" }, base .. "/lua/.luarc.json")
  local path = base .. "/lua/main.lua"
  local code = "local width = vim.api.nvim_win_get_width(0)"
  vim.fn.writefile({ code, "vim.g.language_structure_probe = 42" }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  check(plugins["lazydev.nvim"]._.loaded ~= nil, "Lua file loads lazydev on demand")
  local client
  check(
    vim.wait(30000, function()
      client = vim.lsp.get_clients({ bufnr = buf, name = "lua_ls" })[1]
      return client and client.initialized
    end, 30),
    "Lua language server attached"
  )
  local hover
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = 0, character = code:find("nvim_win_get_width", 1, true) },
  }
  local attempts = 0
  local function request()
    attempts = attempts + 1
    client:request("textDocument/hover", params, function(e, result)
      if not e and result and vim.inspect(result):find("nvim_win_get_width", 1, true) then
        hover = result
      elseif attempts < 20 then
        vim.defer_fn(request, 500)
      end
    end, buf)
  end
  request()
  check(
    vim.wait(30000, function()
      return hover ~= nil
    end, 30),
    "Lua retains Neovim API type information"
  )
  vim.cmd("R")
  check(vim.g.language_structure_probe == 42, ":R runs current Lua file through language command")
  local md = base .. "/README.md"
  vim.fn.writefile({ "# Title", "", "- item", "", "plain text" }, md)
  vim.cmd.edit(vim.fn.fnameescape(md))
  local mdbuf = vim.api.nvim_get_current_buf()
  check(plugins["render-markdown.nvim"]._.loaded ~= nil, "Markdown render plugin loads on Markdown")
  local lines = vim.api.nvim_buf_get_lines(mdbuf, 0, -1, false)
  local toggle = vim.fn.maparg("<leader>Mp", "n", false, true).callback
  check(type(toggle) == "function", "Markdown key comes from its language entry")
  toggle()
  toggle()
  check(
    vim.deep_equal(lines, vim.api.nvim_buf_get_lines(mdbuf, 0, -1, false)) and not vim.bo[mdbuf].modified,
    "Markdown toggling preserves source"
  )
  local expand = vim.fn.maparg("<leader>Me", "n", false, true).callback
  local contract = vim.fn.maparg("<leader>Mc", "n", false, true).callback
  check(
    type(expand) == "function" and type(contract) == "function",
    "Markdown expand/contract keys come from the language entry"
  )
  expand()
  contract()
  check(
    vim.deep_equal(lines, vim.api.nvim_buf_get_lines(mdbuf, 0, -1, false)) and not vim.bo[mdbuf].modified,
    "Markdown expand/contract preserve source"
  )
  local mdx = base .. "/README.mdx"
  vim.fn.writefile({ "# Title", "", "- item" }, mdx)
  vim.cmd.edit(vim.fn.fnameescape(mdx))
  local mdxbuf = vim.api.nvim_get_current_buf()
  check(vim.bo[mdxbuf].filetype == "markdown.mdx", "MDX maps to the markdown.mdx filetype")
  check(
    vim.wait(10000, function()
      return require("render-markdown.state").cache[mdxbuf] ~= nil
    end, 50),
    "renderer attaches to .mdx buffers"
  )
end, debug.traceback)
for _, c in ipairs(vim.lsp.get_clients()) do
  if not before[c.id] then
    c:stop(true)
  end
end
vim.wait(3000, function()
  return #vim.lsp.get_clients() == 0
end, 30)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS " .. checks .. " real Lua/Markdown assertions")
vim.cmd("qa!")
