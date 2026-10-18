-- ============================================
-- Markdown 编辑区美化：render-markdown.nvim
-- 只改变显示，不改文件内容；不打开独立预览窗口或浏览器。
-- ============================================

return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- lazy 的 ft 同时决定插件生效的 file_types（插件在没有 user.file_types 时直接取它），
  -- 所以 .mdx 必须一起列进来，否则 markdown.mdx 缓冲区不会被渲染。
  ft = { "markdown", "markdown.mdx" },
  cmd = "RenderMarkdown",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  opts = {
    -- 阅读时渲染；插入、可视选择时显示源码。光标所在行也保留原始标记。
    render_modes = { "n", "c" },
    anti_conceal = { enabled = true, above = 0, below = 0 },
    sign = { enabled = false },
    -- 保留标题图标和层级色，不铺整行背景，避免透明主题下出现大块色带。
    heading = { backgrounds = {}, border = false },
    code = {
      style = "language",
      disable_background = true,
      inline = false,
      width = "block",
      border = "none",
      highlight_border = false,
    },
    -- 不为预览额外安装 LaTeX 转换工具；公式保留源码。
    latex = { enabled = false },
  },
}
