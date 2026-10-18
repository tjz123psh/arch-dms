return {
  {
    "JavaHello/spring-boot.nvim",
    cmd = "SpringBoot",
    ft = { "java", "yaml", "jproperties" },
    opts = {
      project_filter = function(root)
        return require("spring_boot.util").has_spring_boot_dependency(root)
      end,
      server = {
        root_dir = function(buf, on_dir)
          -- 无构建文件的单文件目录不回落到 cwd，避免误附加到另一个 Spring 项目。
          if require("languages.java.project").root(buf) then
            require("spring_boot.launch").root_dir(buf, on_dir)
          end
        end,
        handlers = {
          ["workspace/executeClientCommand"] = function(...)
            return require("languages.java.lsp").execute_client_command(...)
          end,
        },
      },
    },
    config = function(_, opts)
      require("spring_boot.launch").root_markers = require("languages.java.project").markers
      require("spring_boot").setup(opts)
    end,
  },
}
