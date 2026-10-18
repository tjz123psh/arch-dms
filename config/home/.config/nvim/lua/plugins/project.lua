-- 项目管理：project.nvim

return {
  "ahmedkhalf/project.nvim",
  lazy = false,
  config = function()
    require("project_nvim").setup({
      detection_methods = { "pattern", "lsp" },
      patterns = {
        ".git",
        "_darcs",
        ".hg",
        ".bzr",
        ".svn",
        "Makefile",
        "CMakeLists.txt",
        "package.json",
        "go.mod",
        "Cargo.toml",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
      },
      manual_mode = false,
      -- 笔记库不参与自动跳根：Obsidian 整库一个 .git，在里面打开任何笔记时
      -- project.nvim 都会把 cwd 切到库根（.git 所在层），neo-tree 因
      -- `bind_to_cwd` 随之搬走，看起来像"文件树倒退"。
      -- 这里的 glob 经 globtopattern 转换后 * 会跨目录匹配（锚定为 ^…$），
      -- 所以 `~/obsidian/*` 覆盖其下任意深度的文件；真工程照旧自动跟根。
      exclude_dirs = { "~/obsidian/*" },
    })
    require("core.projects").patch()
  end,
}
