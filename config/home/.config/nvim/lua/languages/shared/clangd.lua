-- C/C++ 引用同一份服务声明，消费者去重后统一注册。
return {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
  },
  -- 不含 lspconfig 默认的 c.doxygen/cpp.doxygen，避免未知 filetype 警告。
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname and #fname > 0 then
      on_dir(
        vim.fs.root(fname, { ".clangd", "compile_commands.json", "build/compile_commands.json", ".git" })
          or vim.fn.getcwd()
      )
    end
  end,
}
