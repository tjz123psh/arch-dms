-- Full isolated configuration; deterministic stackTrace listener contract check.
local dap = require("dap")
local listener = assert(dap.listeners.after.stackTrace["nvim-dap-virtual-text"])
local requests = 0
local session = {
  threads = {},
  _request_scopes = function()
    requests = requests + 1
  end,
}
local frames = { stackFrames = { { id = 1, name = "one" }, { id = 2, name = "two" }, { id = 3, name = "one" } } }
local ok, err = pcall(listener, session, { message = "thread resumed" }, nil)
if vim.env.NVIM_EXPECT_LEGACY == "1" then
  assert(not ok and tostring(err):find("pairs", 1, true), "expected legacy error response crash")
  listener(session, nil, frames)
  assert(requests == 0, "legacy listener unexpectedly processed the response position")
  io.stdout:write("REPRODUCED legacy stackTrace signature error and ignored successful frames\n")
else
  assert(ok, tostring(err))
  listener(session, nil, frames)
  assert(requests == 2, "valid frame response must request each function once")
  listener(session, nil, nil)
  assert(requests == 2, "empty response must be harmless")
  io.stdout:write("PASS stackTrace errors/empty responses and all-frame success forwarding\n")
end
vim.cmd("qa!")
