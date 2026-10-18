-- AI 面板：toggle 只隐藏/显示，close 才结束直连会话；不启用 tmux/NES。
return {
  "folke/sidekick.nvim",
  opts = { nes = { enabled = false } },
  config = function(_, opts)
    require("sidekick").setup(opts)
    -- 面板窗口把 Normal/NormalNC 映射到 SidekickChat，而上游从未定义这个组。
    -- WinHighlight 指向未定义的组会退回「UI 默认背景」（猫猫 base #1e1e2e），
    -- 于是透明主题下只有面板是一块实心色。链到 Normal 后与编辑区一样透出桌面，
    -- 换主题也会自动跟随（Normal 的 bg 变什么它就是什么）。
    vim.api.nvim_set_hl(0, "SidekickChat", { link = "Normal" })
  end,
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "AI CLI：开关面板",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select({ filter = { installed = true } })
      end,
      desc = "AI CLI：选工具（只列已安装）",
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      mode = { "n", "x" },
      desc = "AI CLI：发送当前上下文",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "AI CLI：断开会话",
    },
    {
      "<C-.>",
      function()
        require("sidekick.cli").focus()
      end,
      mode = { "n", "t", "i", "x" },
      desc = "AI CLI：聚焦 CLI 窗口",
    },
  },
}
