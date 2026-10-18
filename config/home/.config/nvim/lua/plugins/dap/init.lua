-- 调试适配器协议：nvim-dap

-- require 留在回调中，声明键位不提前加载调试器；Java 的局部 F5 仍优先。
local function action(method)
  return function()
    require("dap")[method]()
  end
end

local function breakpoint(logpoint)
  local label = logpoint and "日志" or "断点条件"
  local value = vim.fn.input(label .. "（Esc 取消）: ")
  if value == "" then
    vim.notify(
      logpoint and "已取消：日志为空，不设置日志断点"
        or "已取消：条件为空，不设置条件断点",
      vim.log.levels.INFO
    )
    return
  end
  -- 空字符串会退化为普通断点，因此取消不能传给 DAP。
  if logpoint then
    require("dap").set_breakpoint(nil, nil, value)
  else
    require("dap").set_breakpoint(value)
  end
end

return {
  "mfussenegger/nvim-dap",
  keys = {
    { "<F5>", action("continue"), desc = "继续执行" },
    { "<F9>", action("toggle_breakpoint"), desc = "切换断点" },
    { "<F10>", action("step_over"), desc = "单步跳过" },
    { "<F11>", action("step_into"), desc = "单步进入" },
    { "<F12>", action("step_out"), desc = "单步跳出" },
    { "<leader>dl", action("run_last"), desc = "重跑上次调试" },
    {
      "<leader>db",
      function()
        require("dap").list_breakpoints(true)
      end,
      desc = "断点列表",
    },
    {
      "<leader>dB",
      function()
        breakpoint(false)
      end,
      desc = "条件断点",
    },
    {
      "<leader>dL",
      function()
        breakpoint(true)
      end,
      desc = "日志断点",
    },
    { "<leader>dC", action("clear_breakpoints"), desc = "清除所有断点" },
  },
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    {
      "theHamsta/nvim-dap-virtual-text",
      opts = {
        all_frames = true,
        virt_text_pos = "eol",
      },
      config = function(_, opts)
        require("nvim-dap-virtual-text").setup(opts)
        -- 当前锁定版仍把第二参数当响应；DAP 请求监听实际为 session, err, response。
        local listeners = require("dap").listeners.after.stackTrace
        local render = listeners["nvim-dap-virtual-text"]
        listeners["nvim-dap-virtual-text"] = function(session, err, response)
          if not err and type(response) == "table" and type(response.stackFrames) == "table" then
            return render(session, response)
          end
        end
      end,
    },
  },

  opts = function()
    return require("languages").dap()
  end,

  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")

    for name, adapter in pairs(opts.adapters or {}) do
      dap.adapters[name] = adapter
    end
    for lang, configs in pairs(opts.configurations or {}) do
      dap.configurations[lang] = configs
    end

    dapui.setup({
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          size = math.max(28, math.min(45, math.floor(vim.o.columns * 0.32))),
          position = "right",
        },
        {
          elements = { "repl", "console" },
          size = 10,
          position = "bottom",
        },
      },
    })

    dap.listeners.before.attach.dapui_config = dapui.open
    dap.listeners.before.launch.dapui_config = dapui.open
    dap.listeners.before.event_terminated["dapui_config"] = dapui.close
    dap.listeners.before.event_exited["dapui_config"] = dapui.close

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "✕", texthl = "DiagnosticSignHint" })
    vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticSignInfo" })
    vim.fn.sign_define("DapStopped", { text = "→", texthl = "SignColumn", linehl = "debugPC" })
  end,
}
