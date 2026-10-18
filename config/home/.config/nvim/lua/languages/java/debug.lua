-- 捕获当前 jdtls 客户端逐步查询主类，不使用跨项目的 dap.configurations.java。
-- 上游 fetch_main_configs 在缓冲区 detach 后可回退到其它客户端，且部分错误不回调；
-- 这里直连捕获的 client，并给每次查询统一的失败/超时出口。
local M = {}

function M.fetch(bufnr, client, valid, callback)
  local finished = false
  local function finish(err, configs)
    if finished then
      return
    end
    finished = true
    callback(err, configs)
  end
  local function request(command, arguments, next_step)
    if finished then
      return
    end
    if not valid() then
      finish("Java 调试上下文已变化")
      return
    end
    local params = { command = command }
    if arguments ~= nil then
      params.arguments = arguments
    end
    local ok, sent = pcall(client.request, client, "workspace/executeCommand", params, function(err, result)
      if finished then
        return
      end
      if not valid() then
        finish("Java 调试上下文已变化")
      elseif err then
        finish(command .. ": " .. (err.message or vim.inspect(err)))
      else
        local handled, failure = pcall(next_step, result)
        if not handled then
          finish("Java 调试响应无法解析：" .. tostring(failure))
        end
      end
    end, bufnr)
    if not ok or not sent then
      finish("无法发送 Java 调试请求：" .. command)
    end
  end
  vim.defer_fn(function()
    finish("查询 Java 主类超时，请等待 jdtls 导入完成后重试")
  end, 15000)

  request("vscode.java.resolveMainClass", nil, function(mains)
    if type(mains) ~= "table" then
      finish("jdtls 未返回有效的主类列表")
      return
    end
    if #mains == 0 then
      finish(nil, {})
      return
    end
    local configs, remaining = {}, #mains
    for index, main in ipairs(mains) do
      if type(main) ~= "table" or type(main.mainClass) ~= "string" then
        finish("jdtls 返回的主类缺少名称")
        return
      end
      local class, project = main.mainClass, main.projectName or ""
      request("vscode.java.resolveJavaExecutable", { class, project }, function(java_exec)
        if type(java_exec) ~= "string" or java_exec == "" then
          finish("无法确定主类 " .. class .. " 的 Java 可执行文件")
          return
        end
        local settings = vim.json.encode({
          className = class,
          projectName = project,
          inheritedOptions = true,
          expectedOptions = { ["org.eclipse.jdt.core.compiler.problem.enablePreviewFeatures"] = "enabled" },
        })
        request("vscode.java.checkProjectSettings", settings, function(preview)
          request("vscode.java.resolveClasspath", { class, project }, function(paths)
            if type(paths) ~= "table" or type(paths[1]) ~= "table" or type(paths[2]) ~= "table" then
              finish("无法确定主类 " .. class .. " 的 classpath")
              return
            end
            configs[index] = {
              type = "java",
              request = "launch",
              name = "Launch " .. project .. ": " .. class,
              mainClass = class,
              projectName = project,
              cwd = client.config.root_dir, -- 保留精确 LSP 根，适配器据此选择客户端。
              modulePaths = paths[1],
              classPaths = paths[2],
              javaExec = java_exec,
              console = "integratedTerminal",
              vmArgs = preview == true and "--enable-preview" or nil,
            }
            remaining = remaining - 1
            if remaining == 0 then
              finish(nil, configs)
            end
          end)
        end)
      end)
    end
  end)
end

local wired = false
function M.ensure()
  local dap = require("dap")
  if not wired then
    -- 上游 LspAttach 可能已注册默认适配器；重新接线才能启用自动热替换。
    dap.adapters.java = nil
    require("jdtls").setup_dap({ hotcodereplace = "auto" })
    wired = true
  end
  return dap
end

function M.test(nearest)
  M.ensure()
  local jdtls = require("jdtls")
  return (nearest and jdtls.test_nearest_method or jdtls.test_class)()
end

local debug_generation = 0
function M.scan(launch)
  debug_generation = debug_generation + 1 -- 新操作让之前的请求/选择框失效。
  local generation = debug_generation
  local dap = M.ensure()
  if launch and dap.session() then
    dap.continue()
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
  if not client or not client.config.root_dir then
    vim.notify("当前 Java 缓冲区尚未附加 jdtls，请等待项目导入", vim.log.levels.WARN)
    return
  end
  local root = client.config.root_dir
  local function valid()
    if generation ~= debug_generation or not vim.api.nvim_buf_is_valid(bufnr) then
      return false
    end
    if vim.api.nvim_buf_get_name(bufnr) ~= filename or client.config.root_dir ~= root then
      return false
    end
    local attached = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
    return attached ~= nil and attached.id == client.id
  end
  local function run(config)
    if not valid() or dap.session() or vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end
    debug_generation = debug_generation + 1 -- 一个选择回调最多启动一次。
    vim.api.nvim_buf_call(bufnr, function()
      dap.run(config)
    end)
  end
  local function attempt(n)
    if not valid() or vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end
    M.fetch(bufnr, client, valid, function(err, configs)
      if not valid() or vim.api.nvim_get_current_buf() ~= bufnr or (launch and dap.session()) then
        return
      end
      if err then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
      if not launch then
        vim.notify("当前项目找到 " .. #configs .. " 个主类；F5 将重新查询并选择", vim.log.levels.INFO)
        return
      end
      if #configs == 1 then
        run(configs[1])
      elseif #configs > 1 then
        vim.ui.select(configs, {
          prompt = "选择当前项目要调试的主类",
          format_item = function(c)
            return c.mainClass .. "  [" .. c.projectName .. "]"
          end,
        }, function(choice)
          if choice then
            run(choice)
          end
        end)
      elseif n < 4 then
        vim.notify("jdtls 仍在导入项目，重试 " .. (n + 1) .. "/4…", vim.log.levels.WARN)
        vim.defer_fn(function()
          attempt(n + 1)
        end, 2500)
      else
        vim.notify(
          "未发现主类，请确认 main 声明及项目导入状态（:JavaBuildProjects）",
          vim.log.levels.WARN
        )
        -- 手动兜底也只针对最初捕获的项目；取消或空输入不启动。
        vim.ui.input({ prompt = "手动输入完整主类名（取消则不启动）: " }, function(main_class)
          if main_class and vim.trim(main_class) ~= "" then
            run({
              type = "java",
              name = "Java 调试",
              request = "launch",
              mainClass = vim.trim(main_class),
              cwd = root,
            })
          end
        end)
      end
    end)
  end
  attempt(1)
end

return M
