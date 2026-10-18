-- 全局快捷键映射

local map = vim.keymap.set

map("n", "<Space>", "<Nop>", { desc = "Leader 键" })

map("t", "jk", "<C-\\><C-n>", { desc = "退出终端模式" })

map("n", "<C-h>", "<C-w>h", { desc = "切换到左边窗口" })
map("n", "<C-l>", "<C-w>l", { desc = "切换到右边窗口" })
map("n", "<C-j>", "<C-w>j", { desc = "切换到下边窗口" })
map("n", "<C-k>", "<C-w>k", { desc = "切换到上边窗口" })
map("n", "<leader>vh", "<cmd>split<cr>", { desc = "水平切分窗口" })
map("n", "<leader>vv", "<cmd>vsplit<cr>", { desc = "垂直切分窗口" })

map("n", "<C-s>", "<cmd>write<cr>", { desc = "保存当前文件" })
map("i", "<C-s>", "<C-o>:write<cr>", { desc = "保存当前文件（插入模式）" })
map("i", "<C-CR>", "<Esc>o", { desc = "在下方新建空行，继续编辑" })
map("n", "<leader>ff", function()
  require("snacks").picker.files()
end, { desc = "搜索文件名" })
map("n", "<leader>fg", function()
  require("snacks").picker.grep()
end, { desc = "搜索文件内容" })
map("n", "<leader>fb", function()
  require("snacks").picker.buffers()
end, { desc = "切换已打开的缓冲区" })
map("n", "<leader>fh", function()
  require("snacks").picker.help()
end, { desc = "搜索帮助文档" })
map("n", "<leader>fc", function()
  require("snacks").picker.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "搜索 Neovim 配置文件" })
map("n", "<leader>fp", "<cmd>Projects<cr>", { desc = "搜索项目" })
map("n", "<leader>fr", function()
  require("snacks").picker.recent()
end, { desc = "最近打开的文件" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "关闭当前窗口" })
map("n", "ZQ", function()
  require("core.autocmds").quit_without_save()
end, { desc = "放弃当前窗口修改并关闭（不自动保存）" })

map("n", "<leader>he", "<cmd>Noice errors<cr>", { desc = "最近的报错（noice 历史）" })
map("n", "<leader>hh", "<cmd>Noice history<cr>", { desc = "全部消息历史（noice）" })
map("n", "<leader>ba", "<cmd>BufferLineCloseOthers<cr>", { desc = "关闭其他缓冲区" })
map("n", "<leader>bd", "<cmd>BufDelete<cr>", { desc = "关闭当前缓冲区（保留分屏）" })
map("n", "<leader>wq", "<cmd>wq<cr>", { desc = "保存并关闭" })

require("core.movement")

map("n", "<leader>j", "mzJ`z", { desc = "合并下一行", silent = true })

map("n", "<leader>hk", function()
  require("core.ui.cheatsheet").show()
end, { desc = "快捷键速查" })
