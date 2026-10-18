-- Markdown 声明入口：LSP、工具、语法、渲染插件与专属按键。
-- 渲染相关按键都先确认当前是 Markdown 缓冲区（.mdx 也算），避免在别的文件类型里误触发。
local function markdown_buffer()
  local ft = vim.bo.filetype
  return ft == "markdown" or ft == "markdown.mdx"
end

local function with_markdown(run)
  return function()
    if not markdown_buffer() then
      vim.notify("请先打开 Markdown 文件", vim.log.levels.INFO)
      return
    end
    run()
  end
end

return {
  lsp = { marksman = {} },
  tools = { "marksman" },
  treesitter = {
    parsers = { "markdown", "markdown_inline" },
    filetypes = { "markdown", "markdown.mdx" },
  },
  filetypes = { extension = { mdx = "markdown.mdx" } },
  plugins = { (require("languages.markdown.render")) },
  keys = {
    {
      "<leader>Mp",
      with_markdown(function()
        require("render-markdown").buf_toggle()
      end),
      mode = "n",
      desc = "Markdown：开关当前文档美化",
    },
    {
      -- 光标行附近多露一行原文（插件 anti_conceal 的 above/below 各 +1），读长段落时对照源码用。
      "<leader>Me",
      with_markdown(function()
        require("render-markdown").expand()
      end),
      mode = "n",
      desc = "Markdown：当前行上下各多露一行源码",
    },
    {
      "<leader>Mc",
      with_markdown(function()
        require("render-markdown").contract()
      end),
      mode = "n",
      desc = "Markdown：撤回一行（与 Me 对称）",
    },
  },
}
