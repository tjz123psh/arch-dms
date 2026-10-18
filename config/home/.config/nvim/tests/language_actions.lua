-- 原生 vim.lsp.buf.code_action + 模拟传输：不启动服务、不写业务文件。
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
vim.g.mapleader = " "
local actions = require("languages.shared.actions")
local count = 0
local function eq(actual, expected, message)
  assert(
    vim.deep_equal(actual, expected),
    message .. "\nexpected=" .. vim.inspect(expected) .. "\nactual=" .. vim.inspect(actual)
  )
  count = count + 1
end
local messages, selections, applied, executed, requested = {}, {}, {}, {}, {}
vim.notify = function(msg)
  messages[#messages + 1] = msg
end
vim.ui.select = function(items, opts, callback)
  selections[#selections + 1] = { items = items, opts = opts, callback = callback }
end
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(buf, "/tmp/nvim-language-actions-test-buffer.go")
local uri = vim.uri_from_bufnr(buf)
local active, results, resolve_action = {}, {}, nil
local client = { id = 401, name = "test-lsp", offset_encoding = "utf-16" }
function client:_provider_foreach() end
function client:supports_method(method)
  return method ~= "codeAction/resolve" or resolve_action ~= nil
end
function client:exec_cmd(command, ctx)
  executed[#executed + 1] = { command = command, ctx = ctx }
end
function client:request(method, action, callback, bufnr)
  requested[#requested + 1] = { method = method, action = action, bufnr = bufnr }
  callback(nil, resolve_action)
  return true, 1
end
vim.lsp.get_clients = function(opts)
  local found = {}
  for _, c in ipairs(active) do
    if (not opts.name or opts.name == c.name) and (not opts.bufnr or opts.bufnr == 0 or opts.bufnr == buf) then
      found[#found + 1] = c
    end
  end
  return found
end
vim.lsp.get_client_by_id = function(id)
  return id == client.id and client or nil
end
local last_params
vim.lsp.buf_request_all = function(b, method, params, callback)
  eq(method, "textDocument/codeAction", "only code-action requests")
  last_params = params(client)
  callback({
    [client.id] = {
      result = results,
      context = { client_id = client.id, bufnr = b, method = method, params = last_params },
    },
  })
end
vim.lsp.util.apply_workspace_edit = function(edit, encoding)
  applied[#applied + 1] = { edit = edit, encoding = encoding }
end
local function reset(ft)
  vim.cmd("normal! \27")
  vim.bo.filetype = ft or "go"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "package main", "func main() { println(1 + 2) }" })
  vim.api.nvim_win_set_cursor(0, { 2, 24 })
  active = { client }
  results, resolve_action = {}, nil
  messages, selections, applied, executed, requested = {}, {}, {}, {}, {}
  last_params = nil
end
local function edit_action(kind, title)
  return { title = title or kind, kind = kind, edit = { changes = { [uri] = {} } } }
end
reset()
active = {}
actions.refactor()
eq(#messages, 1, "no-client warning")
eq(last_params, nil, "no-client does not request")
reset()
results = { edit_action("quickfix"), edit_action("source.organizeImports"), edit_action("refactor.extract.function") }
actions.refactor()
eq(last_params.context.only, { "refactor" }, "request only refactor")
eq(#selections[1].items, 1, "native kind filter removes quickfix/source")
eq(#applied, 0, "even single refactor asks first")
selections[1].callback(nil)
eq(#applied, 0, "cancel refactor changes nothing")
selections[1].callback(selections[1].items[1])
eq(#applied, 1, "chosen refactor applies")
eq(applied[1].encoding, "utf-16", "client encoding preserved")
reset()
results = { edit_action("quickfix", "Organize imports"), { title = "Organize imports", command = "wrong.command" } }
actions.organize_imports()
eq(last_params.context.only, { "source.organizeImports" }, "request only import organization")
eq(#applied + #executed, 0, "never infer action from title")
eq(messages[#messages], "No code actions available", "unsupported/no-action is reported")
reset()
results = { edit_action("source.organizeImports"), edit_action("source.fixAll") }
actions.organize_imports()
eq(#applied, 1, "single organize action applied")
eq(#selections, 0, "no prompt for one organize action")
reset()
results = { edit_action("source.organizeImports.a"), edit_action("source.organizeImports.b") }
actions.organize_imports()
eq(#selections[1].items, 2, "multiple organize actions offered")
eq(#applied, 0, "multiple actions not applied blindly")
selections[1].callback(selections[1].items[2])
eq(#applied, 1, "only selected organization applied")
reset()
results = { { title = "Unavailable", kind = "source.organizeImports", disabled = { reason = "disabled reason" } } }
actions.organize_imports()
eq(#applied, 0, "disabled organize action not applied")
eq(messages[#messages], "disabled reason", "disabled reason reported")
reset()
results = { { title = "Extract variable", kind = "refactor.extract", data = { ticket = 1 } } }
resolve_action = edit_action("refactor.extract")
resolve_action.command = { command = "server.finishRefactor", arguments = { 1 } }
actions.refactor()
selections[1].callback(selections[1].items[1])
eq(requested[1].method, "codeAction/resolve", "native resolve preserved")
eq(#applied, 1, "resolved edit applied")
eq(executed[1].command.command, "server.finishRefactor", "resolved client command executed")
eq(executed[1].ctx.client_id, client.id, "command uses originating client")
reset()
vim.api.nvim_win_set_cursor(0, { 2, 14 })
vim.cmd("normal! v")
vim.api.nvim_win_set_cursor(0, { 2, 20 })
actions.refactor()
eq(last_params.range.start, { line = 1, character = 14 }, "visual start")
eq(last_params.range["end"], { line = 1, character = 21 }, "visual end inclusive converted")
reset()
vim.cmd("normal! V")
actions.refactor()
eq(last_params.range.start.character, 0, "linewise selection starts at column zero")
reset()
vim.cmd("normal! \22")
actions.refactor()
eq(last_params, nil, "block selection rejected instead of wrong range")
eq(#messages, 1, "block selection explains why")
reset("java")
local organized = 0
package.loaded["jdtls"] = {
  organize_imports = function()
    organized = organized + 1
  end,
}
active = { { name = "spring-boot", id = 402 } }
actions.organize_imports()
eq(organized, 0, "Java requires attached jdtls, not any Java-related server")
active = { { name = "jdtls", id = 403 } }
actions.organize_imports()
eq(organized, 1, "Java keeps jdtls enhanced organization")
eq(last_params, nil, "Java does not take generic source action route")
reset("rust")
-- 不因初始化时缺少静态 codeActionProvider 而漏绑键；实际能力留到按键时检测。
client.server_capabilities = {}
require("languages.shared.lsp")(client, buf)
eq(vim.fn.maparg("<leader>Ra", "n", false, true).callback, actions.refactor, "shared normal Ra")
eq(vim.fn.maparg("<leader>Ra", "x", false, true).callback, actions.refactor, "shared visual Ra")
eq(vim.fn.maparg("<leader>ot", "n", false, true).callback, actions.organize_imports, "shared ot")
print("PASS " .. count .. " shared language action assertions")
vim.cmd("qa!")
