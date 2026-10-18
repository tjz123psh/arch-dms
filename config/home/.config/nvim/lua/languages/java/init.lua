local plugins = {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    cmd = { "JavaBuildProjects", "JavaSetRuntime" },
    dependencies = { "JavaHello/spring-boot.nvim" },
    opts = {
      settings = {
        java = {
          inlayHints = { parameterNames = { enabled = "all" } },
          maven = { downloadSources = true, downloadJavadoc = false },
          referencesCodeLens = { enabled = true },
          implementationCodeLens = { enabled = true },
          completion = {
            favoriteStaticMembers = {
              "org.junit.Assert.*",
              "org.junit.jupiter.api.Assertions.*",
              "org.mockito.Mockito.*",
              "java.util.Objects.requireNonNull",
              "java.lang.Math.*",
            },
            importOrder = { "java", "javax", "jakarta", "com", "org", "" },
          },
          signatureHelp = { descriptionEnabled = true },
        },
      },
    },
    config = function(_, opts)
      require("languages.java.lsp").setup(opts)
    end,
  },
}
for _, spec in ipairs(require("languages.java.spring")) do
  plugins[#plugins + 1] = spec
end
local keys = { { "<leader>sp", "<cmd>SpringBootCreate<cr>", desc = "Spring Boot 项目向导" } }
for _, item in ipairs({ { "Gc", "class" }, { "Gi", "interface" }, { "Ge", "enum" }, { "Gr", "record" } }) do
  local kind = item[2]
  keys[#keys + 1] = {
    "<leader>" .. item[1],
    function()
      require("languages.java.files").generate(kind)
    end,
    desc = "生成: Java " .. kind,
  }
end

return {
  managed_lsp = { "jdtls", "spring-boot" },
  plugins = plugins,
  tools = { "jdtls", "java-debug-adapter", "java-test", "vscode-spring-boot-tools", "google-java-format" },
  treesitter = { parsers = { "java" }, filetypes = { "java" }, indent = { "java" } },
  formatters = { java = { "google-java-format" } },
  formatter_options = { ["google-java-format"] = { prepend_args = { "--aosp" } } },
  format_on_save = { java = false },
  buffer_options = { java = { tabstop = 4, shiftwidth = 4 } },
  keys = keys,
  commands = {
    JavaRun = {
      callback = function()
        require("languages.java.files").run()
      end,
      opts = { desc = "保存并运行当前 Java 源码（支持终端输入）" },
    },
    SpringBootCreate = {
      callback = function()
        require("languages.java.spring.wizard").create()
      end,
      opts = { desc = "Spring Boot 项目向导（官方 Initializr）" },
    },
  },
  actions = {
    java = {
      organize_imports = function()
        if #vim.lsp.get_clients({ bufnr = 0, name = "jdtls" }) == 0 then
          vim.notify("当前 Java 文件尚未附加 jdtls，未整理 import", vim.log.levels.WARN)
          return
        end
        require("jdtls").organize_imports()
      end,
    },
  },
}
