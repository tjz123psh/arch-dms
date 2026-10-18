-- 语法高亮引擎：nvim-treesitter

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate", -- 安装后自动更新解析器
  lazy = false, -- 新版 nvim-treesitter 不支持 lazy-loading

  opts = function()
    local opts = require("languages").treesitter()
    opts.install_dir = vim.fn.stdpath("data") .. "/site"
    return opts
  end,

  config = function(_, opts)
    local ts = require("nvim-treesitter")

    ts.setup({ install_dir = opts.install_dir })

    local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
    local tree_sitter = mason_bin .. "/tree-sitter"
    if vim.fn.executable("tree-sitter") ~= 1 and vim.fn.executable(tree_sitter) == 1 then
      vim.env.PATH = mason_bin .. ":" .. (vim.env.PATH or "")
    end

    local ok_installed, installed = pcall(ts.get_installed, "parsers")
    if ok_installed then
      local seen = {}
      for _, lang in ipairs(installed) do
        seen[lang] = true
      end

      local missing = {}
      for _, lang in ipairs(opts.ensure_installed or {}) do
        if not seen[lang] then
          table.insert(missing, lang)
        end
      end

      local stamp = vim.fn.stdpath("state") .. "/treesitter-install-stamp"
      local function recently_attempted()
        local f = io.open(stamp, "r")
        if not f then
          return false
        end
        local t = tonumber(f:read("*l")) or 0
        f:close()
        return os.time() - t < 6 * 60 * 60
      end
      local function mark_attempt()
        local f = io.open(stamp, "w")
        if f then
          f:write(tostring(os.time()))
          f:close()
        end
      end

      if #missing > 0 then
        if vim.fn.executable("tree-sitter") ~= 1 then
          vim.notify(
            "Treesitter 解析器缺失，且未找到 tree-sitter CLI；请先安装 tree-sitter-cli",
            vim.log.levels.WARN
          )
        elseif recently_attempted() then
          vim.notify(
            ("Treesitter 解析器缺失：%s（6 小时内已尝试下载，未重复联网；可用 :TSInstall %s 手动安装）"):format(
              table.concat(missing, ", "),
              table.concat(missing, " ")
            ),
            vim.log.levels.INFO
          )
        else
          mark_attempt()
          ts.install(missing)
        end
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
      pattern = opts.highlight_filetypes,
      callback = function(args)
        local ok = pcall(vim.treesitter.start, args.buf)
        if ok and opts.indent_filetypes[vim.bo[args.buf].filetype] then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
