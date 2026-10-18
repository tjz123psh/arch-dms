local M = {}
local project = require("languages.java.project")

function M.setup(bufnr)
  local jdtls, debug = require("jdtls"), require("languages.java.debug")
  local function map(key, callback, desc, mode)
    vim.keymap.set(mode or "n", key, callback, { buffer = bufnr, silent = true, desc = desc })
  end
  map("<leader>co", vim.lsp.buf.code_action, "Java 代码操作")
  map("<leader>ot", require("languages.shared.actions").organize_imports, "Java: 整理 import")
  map("<F5>", function()
    debug.scan(true)
  end, "Java: 调试（自动识别主类）")
  map("<leader>Jd", function()
    debug.scan(false)
  end, "Java: 重新扫描当前项目主类")
  map("<leader>Jr", function()
    require("languages.java.files").run()
  end, "Java: 运行当前源码文件（终端输入）")
  map("<leader>Jt", function()
    project.test(true)
  end, "Java: 终端运行光标处测试方法")
  map("<leader>JT", function()
    project.test(false)
  end, "Java: 终端运行当前测试类")
  map("<leader>Jg", function()
    debug.test(true)
  end, "Java: 调试最近测试方法（jdtls）")
  map("<leader>JG", function()
    debug.test(false)
  end, "Java: 调试文件测试类（jdtls）")
  for _, item in ipairs({
    { "Rv", "extract_variable", "提取变量" },
    { "RV", "extract_variable_all", "提取重复表达式" },
    { "Rc", "extract_constant", "提取常量" },
    { "Rm", "extract_method", "提取方法" },
  }) do
    local action = jdtls[item[2]]
    map("<leader>" .. item[1], action, "Java: " .. item[3])
    map("<leader>" .. item[1], function()
      action(true)
    end, "Java: " .. item[3] .. "（选区）", "x")
  end
  map("gA", jdtls.super_implementation, "跳转到父类/接口实现")
  map("<leader>sr", function()
    require("languages.java.spring.run").run()
  end, "Spring Boot: 运行（多个主类则选择）")
  for _, item in ipairs({
    { "mc", "compile", "编译" },
    { "mt", "test", "跑测试" },
    { "mp", "package", "打包（跳过测试）" },
    { "mi", "install", "安装到本地仓库" },
    { "mn", "clean", "清理" },
    { "ml", "dependencies", "依赖树" },
  }) do
    map("<leader>" .. item[1], function()
      project.build(item[2])
    end, "构建: " .. item[3])
  end
  map("<leader>mb", jdtls.build_projects, "构建: 让 jdtls 重新导入/构建项目")
end

return M
