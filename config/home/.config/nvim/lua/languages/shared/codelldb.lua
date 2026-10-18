-- DAP 标准适配器回调；入口 require 时不加载 dap，也不解析运行时路径。
-- C/C++/Rust 共用此函数，不依赖另一种语言先加载。
return function(callback)
  callback({
    type = "server",
    port = "${port}",
    executable = {
      command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
      args = { "--port", "${port}" },
    },
  })
end
