local M = {}
local project = require("languages.java.project")
local terminals = require("languages.java.terminal")

function M.scan(root)
  local out = {}
  for _, path in ipairs(vim.fn.globpath(root, "src/main/java/**/*.java", false, true)) do
    local mains, err = require("languages.java.syntax").mains(table.concat(vim.fn.readfile(path), "\n"))
    if not mains then
      return nil, err
    end
    vim.list_extend(out, mains)
  end
  table.sort(out, function(a, b)
    return a.fqcn < b.fqcn
  end)
  return out
end

-- 一次读取 POM，区分标准属性、自定义属性与写死主类；不实现 Maven 继承解析器。
function M.configuration(root)
  local ok, lines = pcall(vim.fn.readfile, root .. "/pom.xml")
  if not ok then
    return {}
  end
  local pom = table.concat(lines, "\n"):gsub("<!%-%-.-%-%->", "")
  local block = ""
  for plugin in pom:gmatch("<plugin>.-</plugin>") do
    if plugin:find("<artifactId>%s*spring%-boot%-maven%-plugin%s*</artifactId>") then
      block = plugin
      break
    end
  end
  local main = block:match("<mainClass>%s*([^<]-)%s*</mainClass>")
  local flag = main and main:match("^%${([%w_.%-]+)}$") or nil
  if main and not flag then
    return { pinned = main, default = main }
  end
  flag = flag or "spring-boot.run.main-class"
  local default = pom:match("<" .. vim.pesc(flag) .. ">%s*([^<]-)%s*</" .. vim.pesc(flag) .. ">")
  return { flag = flag, default = default }
end

function M.arguments(tool, config, main, multi)
  if tool.kind == "gradle" then
    if multi then
      return nil, "Gradle 多入口需在 bootRun.mainClass 中指定主类；逐个选择调试请用 F5"
    end
    return { "bootRun" }
  end
  if config.pinned and config.pinned ~= main then
    return nil, "pom.xml 把主类固定为 " .. config.pinned .. "，未启动所选的 " .. main
  end
  local args = { "spring-boot:run" }
  if config.flag then
    args[#args + 1] = "-D" .. config.flag .. "=" .. main
  end
  return args
end

local function terminal(root, main)
  return terminals.get(root, "spring", main.fqcn)
end

local function run_one(tool, config, main, multi)
  local args, err = M.arguments(tool, config, main.fqcn, multi)
  if not args then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end
  local term = terminal(tool.root, main)
  local restarting = terminals.busy(term)
  if not terminals.run(term, project.command(tool, args), true) then
    return false
  end
  vim.notify((restarting and "重启 " or "启动 ") .. main.simple .. "；重开终端：:" .. term.id .. "ToggleTerm")
  return true
end

local generation = 0
local function run_all(tool, config, mains, current)
  -- 先验证所有入口，避免跑到一半才发现构建工具不支持选主类。
  for _, main in ipairs(mains) do
    local args, err = M.arguments(tool, config, main.fqcn, true)
    if not args then
      return vim.notify(err, vim.log.levels.WARN)
    end
  end
  local function step(index)
    if generation ~= current then
      return
    end
    local main = mains[index]
    if not main then
      return vim.notify("已依次启动 " .. #mains .. " 个入口")
    end
    local term = terminal(tool.root, main)
    if terminals.busy(term) then
      return step(index + 1)
    end
    if not run_one(tool, config, main, true) then
      return
    end
    local seconds = 0
    local function wait_started()
      if generation ~= current then
        return
      end
      seconds = seconds + 1
      local output = term._java_output or ""
      if output:find("Started " .. main.simple, 1, true) then
        return step(index + 1)
      end
      if
        output:find("APPLICATION FAILED TO START", 1, true)
        or output:find("BUILD FAILURE", 1, true)
        or not terminals.busy(term)
        or seconds >= 60
      then
        return vim.notify(
          main.simple .. " 未确认启动成功，已停止后续启动；请查看终端 " .. term.id,
          vim.log.levels.WARN
        )
      end
      vim.defer_fn(wait_started, 1000)
    end
    vim.defer_fn(wait_started, 1000)
  end
  step(1)
end

function M.run()
  generation = generation + 1
  local current = generation
  local tool, err = project.tool(project.root())
  if not tool then
    return vim.notify(err, vim.log.levels.WARN)
  end
  local mains, scan_err = M.scan(tool.root)
  if not mains or #mains == 0 then
    return vim.notify(scan_err or "src/main/java 下没有找到 main 入口", vim.log.levels.WARN)
  end
  local config = M.configuration(tool.root)
  if #mains == 1 then
    return run_one(tool, config, mains[1], false)
  end
  local choices = {}
  for _, main in ipairs(mains) do
    local term = terminal(tool.root, main)
    choices[#choices + 1] = {
      main = main,
      text = string.format(
        "%s  %s  [终端 %d]%s%s",
        main.simple,
        main.pkg,
        term.id,
        main.fqcn == config.default and "  ← pom 默认" or "",
        terminals.busy(term) and "  ● 已在跑" or ""
      ),
    }
  end
  choices[#choices + 1] = { text = "▶ 全部启动（按顺序，每个入口一个终端）" }
  vim.ui.select(choices, {
    prompt = "选择 Spring Boot 主类",
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if not choice or current ~= generation then
      return
    end
    if choice.main then
      run_one(tool, config, choice.main, true)
    else
      run_all(tool, config, mains, current)
    end
  end)
end

return M
