local M = {}
local project = require("languages.java.project")

-- 客户端级 handler 会盖掉上游转发：nil/异常/重新加载 bundles 必须按 RPC 契约返回。
function M.execute_client_command(_, params, ctx)
  params = params or {}
  local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
  local fn = (client.commands or {})[params.command] or vim.lsp.commands[params.command]
  if fn then
    local ok, result = pcall(fn, params.arguments, ctx)
    if not ok then
      return nil, vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, tostring(result))
    end
    return result == nil and vim.NIL or result
  end
  return params.command == "_java.reloadBundles.command" and {} or vim.NIL
end

local function bundles(data)
  local result = {}
  for _, pattern in ipairs({
    "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    "/mason/packages/java-test/extension/server/*.jar",
  }) do
    for _, jar in ipairs(vim.fn.glob(data .. pattern, false, true)) do
      -- runner/agent/ASM 不是要装入 jdtls 的 OSGi bundle。
      if
        not jar:match("runner%-jar%-with%-dependencies")
        and not jar:match("jacocoagent")
        and not jar:match("org%.objectweb%.asm")
      then
        result[#result + 1] = jar
      end
    end
  end
  return vim.list_extend(result, require("spring_boot").java_extensions())
end

function M.setup(opts)
  local jdtls = require("jdtls")
  local data = vim.fn.stdpath("data")
  opts = vim.deepcopy(opts or {})
  opts.cmd = opts.cmd or { data .. "/mason/bin/jdtls" }
  opts.init_options = { bundles = bundles(data) }
  opts.capabilities = require("blink.cmp").get_lsp_capabilities(opts.capabilities)
  local runtimes = {}
  for _, runtime in ipairs({
    { name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk" },
    { name = "JavaSE-1.8", path = "/usr/lib/jvm/java-8-openjdk" },
  }) do
    if vim.fn.isdirectory(runtime.path) == 1 then
      runtime.default = #runtimes == 0
      runtimes[#runtimes + 1] = runtime
    end
  end
  opts.settings =
    vim.tbl_deep_extend("force", opts.settings or {}, { java = { configuration = { runtimes = runtimes } } })
  if vim.fn.executable("/usr/lib/jvm/java-21-openjdk/bin/java") == 1 then
    opts.cmd[#opts.cmd + 1] = "--java-executable=/usr/lib/jvm/java-21-openjdk/bin/java"
  end
  for _, path in ipairs({ data .. "/java-extras/lombok.jar", data .. "/mason/packages/jdtls/lombok.jar" }) do
    if vim.uv.fs_stat(path) then
      opts.cmd[#opts.cmd + 1] = "--jvm-arg=-javaagent:" .. path
      break
    end
  end
  opts.handlers = { ["workspace/executeClientCommand"] = M.execute_client_command }
  opts.on_attach = function(client, buf)
    vim.lsp.semantic_tokens.enable(false, { bufnr = buf }) -- 保持 Treesitter 颜色，不被 Java/Spring token 来回覆盖。
    require("languages.shared.lsp")(client, buf)
  end
  require("languages.java.ui").setup()

  local function start(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "java" or vim.api.nvim_buf_get_name(buf) == "" then
      return
    end
    require("languages.java.keymaps").setup(buf)
    local config = vim.deepcopy(opts)
    config.root_dir = project.lsp_root(buf)
    local workspace = vim.fn.fnamemodify(config.root_dir, ":t") .. "-" .. vim.fn.sha256(config.root_dir):sub(1, 10)
    vim.list_extend(config.cmd, { "-data", data .. "/site/jdtls-workspace/" .. workspace })
    -- start_or_attach 本身会复用、重新附加或重启；无需另存一套 started_bufs 状态。
    vim.api.nvim_buf_call(buf, function()
      jdtls.start_or_attach(config, nil, {
        bufnr = buf,
        reuse_client = function(client, new)
          return client.name == "jdtls" and client.config.root_dir == new.root_dir
        end,
      })
    end)
  end
  local function ready()
    if #vim.lsp.get_clients({ name = "jdtls", bufnr = 0 }) == 0 then
      vim.notify("请先打开 Java 文件并等待 jdtls 导入完成", vim.log.levels.WARN)
      return false
    end
    return true
  end
  vim.api.nvim_create_user_command("JavaBuildProjects", function()
    if ready() then
      jdtls.build_projects()
    end
  end, { desc = "jdtls: 重新导入并构建项目" })
  vim.api.nvim_create_user_command("JavaSetRuntime", function(args)
    if ready() then
      jdtls.set_runtime(args.args ~= "" and args.args or nil)
    end
  end, {
    nargs = "?",
    desc = "切换 Java 项目 JDK",
    complete = function(lead)
      local names = {}
      for _, runtime in ipairs(runtimes) do
        if vim.startswith(runtime.name, lead) then
          names[#names + 1] = runtime.name
        end
      end
      return names
    end,
  })
  local group = vim.api.nvim_create_augroup("java_jdtls", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(event)
      start(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.java",
    callback = function(event)
      if project.root(event.buf) and #vim.lsp.get_clients({ bufnr = event.buf, name = "jdtls" }) > 0 then
        vim.api.nvim_buf_call(event.buf, function()
          jdtls.compile("incremental")
        end)
      end
    end,
  })
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "java" then
    vim.schedule(function()
      start(buf)
    end)
  end
end

return M
