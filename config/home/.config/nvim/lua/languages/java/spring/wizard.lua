-- Spring Boot 11 步向导；Snacks 单卡片，core.ui 统一 soft / pink 配色。
local M = {}
local CANCEL = {}
local meta_cache, meta_cached_at
local META_TTL = 600
local INITIALIZR = "https://start.spring.io"

-- 同步回调不 yield；异步只恢复一次，保留 nil 与多返回值。
local function bridge(caller)
  local co = assert(coroutine.running(), "向导桥必须在协程内调用")
  local completed, waiting, data = false, false, nil
  caller(function(...)
    if completed then
      return
    end
    completed, data = true, { n = select("#", ...), ... }
    if waiting and coroutine.status(co) == "suspended" then
      local ok, err = coroutine.resume(co, unpack(data, 1, data.n))
      if not ok then
        vim.notify("向导内部错误：" .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end)
  if completed then
    return unpack(data, 1, data.n)
  end
  waiting = true
  return coroutine.yield()
end

local function answer(value, err)
  if err then
    error(err, 0)
  end
  if value == nil then
    error(CANCEL, 0)
  end
  return value
end

local function run(argv, timeout, label)
  local res, err = bridge(function(done)
    local ok, spawn_err = pcall(vim.system, argv, {
      text = true,
      timeout = timeout,
      env = { LC_ALL = "C", UNZIP = "", UNZIPOPT = "", ZIPINFO = "", ZIPINFOOPT = "" },
    }, function(result)
      vim.schedule(function()
        done(result)
      end)
    end)
    if not ok then
      done(nil, tostring(spawn_err))
    end
  end)
  if not res or res.code ~= 0 then
    local detail = err or ((res.stderr or "") .. " " .. (res.stdout or ""))
    error(label .. "失败（退出码 " .. tostring(res and res.code) .. "）：" .. detail:sub(1, 1200), 0)
  end
  return res.stdout or ""
end

local function curl_args(seconds)
  return {
    "curl",
    "--disable",
    "--fail",
    "--silent",
    "--show-error",
    "--proto",
    "=https",
    "--connect-timeout",
    "5",
    "--max-time",
    tostring(seconds),
  }
end

local function values(node)
  return type(node) == "table" and type(node.values) == "table" and vim.islist(node.values) and node.values or {}
end

local function load_meta()
  if meta_cache and vim.uv.now() / 1000 - meta_cached_at < META_TTL then
    return meta_cache
  end
  local argv = curl_args(8)
  argv[#argv + 1] = INITIALIZR .. "/metadata/client"
  local ok, meta = pcall(vim.json.decode, run(argv, 10000, "获取 Initializr 元数据"))
  if not ok or type(meta) ~= "table" or #values(meta.bootVersion) == 0 or #values(meta.type) == 0 then
    error("Initializr 元数据解析失败或缺少版本/项目类型", 0)
  end
  meta_cache, meta_cached_at = meta, vim.uv.now() / 1000
  return meta
end

-- 历史 metadata 带 .RELEASE，实际构建坐标需去掉；RC/M/SNAPSHOT 不冒充正式版。
local function normalize_boot(id)
  return (id:gsub("%.RELEASE$", ""))
end

local function is_prerelease(id)
  local s = id:upper()
  return s:find("SNAPSHOT", 1, true) ~= nil
    or s:match("[%-._]RC%d*$") ~= nil
    or s:match("[%-._][MR]%d+$") ~= nil
    or s:match("[%-._]BUILD$") ~= nil
end

local function vcmp(a, b)
  local pa, pb = {}, {}
  for x in a:gmatch("%d+") do
    pa[#pa + 1] = tonumber(x)
  end
  for x in b:gmatch("%d+") do
    pb[#pb + 1] = tonumber(x)
  end
  for i = 1, math.max(#pa, #pb) do
    local diff = (pa[i] or 0) - (pb[i] or 0)
    if diff ~= 0 then
      return diff
    end
  end
  return 0
end

local function simple_options(node)
  local out, seen = {}, {}
  for _, v in ipairs(values(node)) do
    if type(v) == "table" and type(v.id) == "string" and v.id ~= "" and not seen[v.id] then
      seen[v.id] = true
      out[#out + 1] = { id = v.id }
    end
  end
  return out
end

local function boot_options(meta)
  local out, seen = {}, {}
  for _, v in ipairs(simple_options(meta.bootVersion)) do
    local id = normalize_boot(v.id)
    if not seen[id] then
      seen[id] = true
      out[#out + 1] = { id = id, pre = is_prerelease(v.id) }
    end
  end
  table.sort(out, function(a, b)
    if a.pre ~= b.pre then
      return not a.pre
    end
    return vcmp(a.id, b.id) > 0
  end)
  for i, v in ipairs(out) do
    v.hint = v.pre and "预发布，可能拉不到" or (i == 1 and "最新正式版" or "正式版")
  end
  return out
end

local function build_options(meta)
  local available, out = {}, {}
  for _, v in ipairs(values(meta.type)) do
    if type(v) == "table" and type(v.id) == "string" and v.action == "/starter.zip" then
      available[v.id] = true
    end
  end
  for _, build in ipairs({
    { id = "maven", type = "maven-project", hint = "pom.xml + mvnw" },
    { id = "gradle", type = "gradle-project-kotlin", hint = "build.gradle.kts + gradlew" },
  }) do
    if available[build.type] then
      out[#out + 1] = build
    end
  end
  return out
end

local GROUP_SHORT = {
  ["VMware Tanzu Spring Enterprise Extensions"] = "Tanzu Ent",
  ["VMware Tanzu Application Service"] = "Tanzu AppSvc",
  ["VMware Tanzu Spring SDK"] = "Tanzu SDK",
  ["Spring Cloud Circuit Breaker"] = "Cloud Breaker",
  ["Spring Cloud Discovery"] = "Cloud Discovery",
  ["Spring Cloud Config"] = "Cloud Config",
  ["Spring Cloud Messaging"] = "Cloud Messaging",
  ["Spring Cloud"] = "Cloud",
  ["Developer Tools"] = "Dev Tools",
  ["Template Engines"] = "Templates",
  ["Observability"] = "Observe",
}

local function dependency_options(meta)
  local out, seen = {}, {}
  for _, group in ipairs(values(meta.dependencies)) do
    for _, dep in ipairs(values(group)) do
      if type(dep) == "table" and type(dep.id) == "string" and type(dep.name) == "string" and not seen[dep.id] then
        seen[dep.id] = true
        out[#out + 1] = {
          id = dep.id,
          name = dep.name,
          group = GROUP_SHORT[group.name] or group.name or "Other",
          description = type(dep.description) == "string" and dep.description or "",
        }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.group == b.group and a.id < b.id or a.group < b.group
  end)
  return out
end

local function cut_last(text, width)
  return #text <= width and text or text:sub(1, width - 1) .. "…"
end

local function valid_segment(s)
  return type(s) == "string" and s ~= "." and s ~= ".." and s:match("^[A-Za-z0-9_.][A-Za-z0-9_.%-]*$") ~= nil
end

local JAVA_RESERVED = {}
for word in
  ([[abstract assert boolean break byte case catch char class const continue default do double else enum
extends final finally float for goto if implements import instanceof int interface long native new package private
protected public return short static strictfp super switch synchronized this throw throws transient try void volatile
while true false null _]]):gmatch("%S+")
do
  JAVA_RESERVED[word] = true
end

-- 接受 ASCII Java 标识符；每段独立检查，禁止空段、关键字和数字开头。
local function valid_package(s)
  if type(s) ~= "string" or s == "" then
    return false
  end
  for _, part in ipairs(vim.split(s, ".", { plain = true })) do
    if not part:match("^[A-Za-z_$][A-Za-z0-9_$]*$") or JAVA_RESERVED[part] then
      return false
    end
  end
  return true
end

local function sanitize_package(s)
  local out = {}
  for _, part in ipairs(vim.split(s, ".", { plain = true })) do
    part = part:gsub("[^A-Za-z0-9_$]", "_")
    if part == "" then
      part = "_pkg"
    elseif part:match("^%d") then
      part = "_" .. part
    end
    out[#out + 1] = JAVA_RESERVED[part] and (part .. "_") or part
  end
  return table.concat(out, ".")
end

local ui = require("core.ui")

local border_timer = nil
local border_step = 0
-- 关闭后的排队回调不得重新染色；临时 CursorLine 高亮必须原样还原。
local pulse_gen = 0

local TRANSIENT_HL = {
  { "SnacksPickerCursorLine", { bg = "NONE" } },
  { "SnacksPickerListCursorLine", { bg = "NONE" } },
}
local transient_saved = {}
local function apply_transient_hl()
  for _, d in ipairs(TRANSIENT_HL) do
    if transient_saved[d[1]] == nil then
      transient_saved[d[1]] = vim.api.nvim_get_hl(0, { name = d[1], link = true })
    end
    vim.api.nvim_set_hl(0, d[1], d[2])
  end
end
local function restore_transient_hl()
  for _, d in ipairs(TRANSIENT_HL) do
    local saved = transient_saved[d[1]]
    if saved then
      pcall(vim.api.nvim_set_hl, 0, d[1], saved)
    end
    transient_saved[d[1]] = nil
  end
end

local border_colors = ui.border_colors

local function stop_pulse()
  pulse_gen = pulse_gen + 1
  if border_timer then
    pcall(border_timer.stop, border_timer)
    pcall(border_timer.close, border_timer)
    border_timer = nil
  end
  pcall(vim.api.nvim_set_hl, 0, "WizBorder", { fg = border_colors()[1] })
  restore_transient_hl()
end
local function start_pulse()
  stop_pulse()
  apply_transient_hl()
  pulse_gen = pulse_gen + 1
  local my_gen = pulse_gen
  border_step = 0
  border_timer = vim.uv.new_timer()
  border_timer:start(0, 1200, function()
    border_step = border_step + 1
    local c = border_colors()[(border_step % 3) + 1]
    vim.schedule(function()
      if my_gen ~= pulse_gen then
        return
      end
      pcall(vim.api.nvim_set_hl, 0, "WizBorder", { fg = c })
    end)
  end)
end

local function card_w()
  return math.max(20, math.min(104, vim.o.columns - 2))
end
local FOOT_LINES = 3 -- 底部说明区行数（卡片高度恒定）
local CARD_BORDER = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
local FOOT_NS

local function card_layout(list_h, footer_on)
  footer_on = footer_on ~= false
  return {
    hidden = (not footer_on) and { "preview" } or nil,
    layout = {
      box = "vertical",
      backdrop = false,
      width = card_w(),
      height = list_h + (footer_on and FOOT_LINES or 0) + 3,
      border = CARD_BORDER,
      title = "{title}",
      title_pos = "center",
      { win = "input", height = 1, border = "bottom" },
      { win = "list", border = "none" },
      { win = "preview", height = FOOT_LINES, border = "top" },
    },
  }
end

-- Snacks 的 keys 整表替换：拷贝默认键，保留 Tab/Enter/Esc，并给 n/i 都补 Ctrl-S。
local function win_config()
  local dwin = require("snacks.picker.config.defaults").defaults.win
  local ks = vim.tbl_extend("force", vim.deepcopy(dwin.input.keys), {
    ["<Esc>"] = { "cancel", mode = { "n", "i" } },
    ["<c-s>"] = { "confirm", mode = { "n", "i" } },
  })
  return {
    input = {
      keys = ks,
      wo = { winblend = 0, number = false, signcolumn = "no", wrap = false },
    },
    list = {
      keys = vim.tbl_extend("force", vim.deepcopy(dwin.list.keys), {
        ["<c-s>"] = { "confirm", mode = { "n", "i" } },
      }),
      wo = { winblend = 0, number = false, relativenumber = false, signcolumn = "no", wrap = false },
    },
    preview = {
      minimal = true,
      wo = { winblend = 0, wrap = false },
    },
  }
end

local function footer_width()
  return card_w() - 2
end

local function flatten_chunks(chunks)
  local out = {}
  for _, chunk in ipairs(chunks) do
    local text = chunk[1] or ""
    for i = 0, vim.fn.strchars(text) - 1 do
      local s = vim.fn.strcharpart(text, i, 1)
      out[#out + 1] = { s = s, hl = chunk[2], w = vim.fn.strdisplaywidth(s) }
    end
  end
  return out
end

local function layout_footer(chunks, width, max_lines)
  local flat = flatten_chunks(chunks)
  local lines = { { text = "", segs = {} } }
  local cur, w = lines[1], 0
  local seg_s, seg_hl = 0, nil
  local function flush()
    if seg_hl and #cur.text > seg_s then
      cur.segs[#cur.segs + 1] = { s = seg_s, e = #cur.text, hl = seg_hl }
    end
  end
  for _, ch in ipairs(flat) do
    if w + ch.w > width then
      if #lines >= max_lines then
        break
      end
      flush()
      lines[#lines + 1] = { text = "", segs = {} }
      cur, w, seg_s, seg_hl = lines[#lines], 0, 0, nil
    end
    if seg_hl ~= ch.hl then
      flush()
      seg_s, seg_hl = #cur.text, ch.hl
    end
    cur.text = cur.text .. ch.s
    w = w + ch.w
  end
  flush()
  return lines
end

local function footer_preview(preview_of)
  return function(ctx)
    local it = ctx.item and ctx.item.item
    if not it then
      return false
    end
    pcall(function()
      vim.bo[ctx.buf].modifiable = true
    end)
    local ok, chunks = pcall(preview_of, it)
    if not ok then
      chunks = { { tostring(chunks), "WizHint" } }
    end
    local lines = layout_footer(chunks or {}, footer_width(), FOOT_LINES)
    local text = {}
    for _, l in ipairs(lines) do
      text[#text + 1] = l.text
    end
    while #text < FOOT_LINES do
      text[#text + 1] = ""
    end
    vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, text)
    pcall(vim.api.nvim_buf_clear_namespace, ctx.buf, FOOT_NS, 0, -1)
    for li, l in ipairs(lines) do
      for _, sg in ipairs(l.segs) do
        pcall(vim.api.nvim_buf_add_highlight, ctx.buf, FOOT_NS, sg.hl or "WizHint", li - 1, sg.s, sg.e)
      end
    end
    return true
  end
end

local function ask(prompt, default, valid)
  local text = answer(bridge(function(done)
    -- 默认值只放提示，避免用户键入后追加到预填文本；空回车与 Esc 必须区分。
    vim.ui.input({ prompt = prompt .. " [" .. default .. "]: " }, function(value)
      done(value == "" and default or value)
    end)
  end))
  if valid and not valid(text) then
    error(prompt .. "不合法：" .. text, 0)
  end
  return text
end

local function selected_ids(selected)
  if type(selected) ~= "table" or not vim.islist(selected) then
    error("Snacks 多选结构变化：selected 非数组，已中止创建", 0)
  end
  local ids = {}
  for _, item in ipairs(selected) do
    if type(item) ~= "table" or type(item.item) ~= "table" or type(item.item.id) ~= "string" then
      error("Snacks 多选条目缺少依赖 ID，已中止创建", 0)
    end
    ids[#ids + 1] = item.item.id
  end
  return ids
end

local active_picker
local function pick(items, title, opts)
  opts = opts or {}
  local multi, footer = opts.multiple, opts.multiple or opts.footer
  if #items == 0 and not multi then
    error(title .. "没有可选项（元数据异常）", 0)
  end
  local w_id = 8
  for _, item in ipairs(items) do
    w_id = math.max(w_id, #item.id)
  end
  local w_name = math.max(card_w() - 14 - w_id, 12)
  return answer(bridge(function(done)
    local completed = false
    local function finish(value, err, pk)
      if completed then
        return
      end
      completed = true -- 必须先置位，再 close：on_close 不得抢先当作取消。
      active_picker = nil
      stop_pulse()
      if pk then
        pcall(pk.close, pk)
      end
      vim.schedule(function()
        done(value, err)
      end)
    end
    local picker = Snacks.picker.pick({
      source = multi and "spring-wizard-deps" or "spring-wizard",
      title = title,
      layout = card_layout(multi and 14 or math.max(math.min(#items, 10), 2), footer == true),
      win = win_config(),
      show_empty = multi == true,
      formatters = multi and { selected = { show_always = true, unselected = true } } or nil,
      finder = function()
        local out = {}
        for idx, item in ipairs(items) do
          out[#out + 1] = {
            idx = idx,
            item = item,
            text = table.concat(
              { item.id, item.name or "", item.group or "", item.hint or "", item.description or "" },
              " "
            ),
          }
        end
        return out
      end,
      format = function(item, pk)
        local d = item.item
        local current = pk and pk.list and pk.list:current() == item
        local row = {
          { current and "▸ " or "  ", current and "WizMarker" or "WizDim" },
          { multi and (d.id .. string.rep(" ", w_id - #d.id)) or d.id, current and "WizSel" or "WizKey" },
        }
        if multi or not footer then
          row[#row + 1] = { "  " }
          row[#row + 1] = {
            multi and cut_last(d.name or "", w_name) or (d.hint or ""),
            multi and (current and "WizSel" or "WizHint") or "WizPeach",
          }
        end
        return row
      end,
      preview = footer and footer_preview(opts.preview or function(d)
        return {
          { d.name or "", "WizKey" },
          { "  ·  ", "WizDim" },
          { "[" .. (d.group or "") .. "]", "WizBadge" },
          { "  ·  ", "WizDim" },
          { d.description or "", "WizHint" },
        }
      end) or function()
        return false
      end,
      actions = {
        confirm = function(pk, item)
          if completed then
            return
          end
          if multi then
            local ok, result = pcall(selected_ids, pk.list and pk.list.selected)
            if not ok then
              finish(nil, result, pk)
              return
            end
            finish(result, nil, pk) -- 空数组是明确的零依赖确认，不是取消。
          else
            finish(item and item.item, nil, pk)
          end
        end,
      },
      on_close = function()
        finish(nil)
      end,
    })
    if not picker then
      finish(nil) -- 同源去重可能返回 nil；不得留下悬挂协程。
    elseif not completed then
      active_picker = picker
      start_pulse()
    end
  end))
end

local function project_target(parent, name)
  if not valid_segment(name) then
    error("项目目录名不合法：" .. tostring(name), 0)
  end
  parent = vim.uv.fs_realpath(vim.fn.fnamemodify(vim.fn.expand(parent), ":p"))
  local stat = parent and vim.uv.fs_stat(parent)
  if not stat or stat.type ~= "directory" then
    error("父目录不存在或不是目录", 0)
  end
  local target = vim.fs.joinpath(parent, name)
  if vim.uv.fs_lstat(target) then
    error("目标已存在（包括符号链接），请换个项目名：" .. target, 0)
  end
  return target, parent, stat
end

-- 仅接受普通文件/目录；路径、重复条目和解压总量在 unzip 写入前核验。
local function archive_entries(listing)
  local expected = tonumber(listing:match("number of entries: (%d+)"))
  local entries, seen, total = {}, {}, 0
  if not expected or expected == 0 or expected > 1000 then
    error("ZIP 条目数异常", 0)
  end
  for line in listing:gmatch("[^\r\n]+") do
    local mode, size, path = line:match("^(%S+)%s+%S+%s+%S+%s+(%d+)%s+%S+%s+%d+%s+%S+%s+%S+%s+%S+%s+(.+)$")
    if mode then
      local kind = mode:sub(1, 1)
      if #mode ~= 10 or (kind ~= "d" and kind ~= "-") or not path:match("^[A-Za-z0-9_.$/%-]+$") then
        error("ZIP 含不支持的文件类型或路径：" .. path, 0)
      end
      if (kind == "d") ~= (path:sub(-1) == "/") then
        error("ZIP 文件类型与路径不一致：" .. path, 0)
      end
      path = path:gsub("/$", "")
      for _, part in ipairs(vim.split(path, "/", { plain = true })) do
        if part == "" or part == "." or part == ".." then
          error("ZIP 路径越界：" .. path, 0)
        end
      end
      total = total + tonumber(size)
      if seen[path] or total > 32 * 1024 * 1024 then
        error("ZIP 含重复路径或解压量超过 32 MiB", 0)
      end
      seen[path] = kind
      entries[#entries + 1] = { path = path, kind = kind }
    elseif not line:match("^Archive:") and not line:match("^Zip file size:") and not line:match("^%d+ files?,") then
      error("无法校验 ZIP 条目：" .. line, 0)
    end
  end
  if #entries ~= expected then
    error("ZIP 条目清单不完整", 0)
  end
  for _, entry in ipairs(entries) do
    local parent = entry.path:match("^(.+)/[^/]+$")
    while parent do
      if seen[parent] == "-" then
        error("ZIP 文件与目录冲突：" .. parent, 0)
      end
      parent = parent:match("^(.+)/[^/]+$")
    end
  end
  return entries
end

local function generate_project(parent, name, params)
  local target, real_parent, parent_stat = project_target(parent, name)
  -- 同一文件系统的私有临时目录；下载/校验/解包全部成功后才出现目标目录。
  local stage, err = vim.uv.fs_mkdtemp(vim.fs.joinpath(real_parent, ".nvim-java-wizard-XXXXXX"))
  if not stage then
    error("无法创建临时目录：" .. tostring(err), 0)
  end
  local stage_stat = vim.uv.fs_lstat(stage)
  local zip, tree = stage .. "/starter.zip", stage .. "/project"
  local ok, result = pcall(function()
    local argv = curl_args(60)
    vim.list_extend(
      argv,
      { "--max-filesize", "10485760", "--output", zip, "--write-out", "HTTP %{http_code}", "--get" }
    )
    for _, key in ipairs(vim.tbl_keys(params)) do
      vim.list_extend(argv, { "--data-urlencode", key .. "=" .. params[key] })
    end
    argv[#argv + 1] = INITIALIZR .. "/starter.zip"
    run(argv, 65000, "下载模板")
    local entries = archive_entries(run({ "unzip", "-Z", "-l", zip }, 10000, "校验 ZIP"))
    assert(vim.uv.fs_mkdir(tree, 448))
    run({ "unzip", "-q", "-n", zip, "-d", tree }, 30000, "解包模板")
    for _, entry in ipairs(entries) do
      local stat = vim.uv.fs_lstat(tree .. "/" .. entry.path)
      if not stat or stat.type ~= (entry.kind == "d" and "directory" or "file") then
        error("解包后条目类型不符：" .. entry.path, 0)
      end
    end
    local current_parent = vim.uv.fs_stat(real_parent)
    if not current_parent or current_parent.dev ~= parent_stat.dev or current_parent.ino ~= parent_stat.ino then
      error("父目录已改变，已中止创建", 0)
    end
    project_target(real_parent, name)
    -- GNU mv 禁止覆盖和跨文件系统复制；避免检查后才出现同名目标的竞态。
    run({ "mv", "--no-copy", "--update=none-fail", "-T", "--", tree, target }, 10000, "放置项目")
    return target
  end)
  local current = vim.uv.fs_lstat(stage)
  if current and stage_stat and current.dev == stage_stat.dev and current.ino == stage_stat.ino then
    -- 只清本轮 mkdtemp 返回的精确目录，不使用通配、不删除任何已有项目。
    vim.uv.fs_unlink(zip)
    if vim.fn.delete(stage, "rf") ~= 0 then
      vim.notify("临时目录清理失败：" .. stage, vim.log.levels.WARN)
    end
  end
  if not ok then
    error(result, 0)
  end
  return result
end

local function find_main_class(dir, language)
  local ext = ({ java = "java", kotlin = "kt", groovy = "groovy" })[language]
  if ext then
    for _, suffix in ipairs({ "*Application.", "*." }) do
      local found = vim.fn.globpath(dir, "src/main/" .. language .. "/**/" .. suffix .. ext, true, true)
      if found[1] then
        return found[1]
      end
    end
  end
end

local function flow()
  local meta = load_meta()
  local build = pick(build_options(meta), "1. 构建工具")
  local langs = simple_options(meta.language)
  if #langs == 0 then
    langs = { { id = "java" } }
  end
  for _, lang in ipairs(langs) do
    lang.hint = lang.id == "java" and "推荐" or ""
  end
  local lang = pick(langs, "2. 语言")
  local jvers = simple_options(meta.javaVersion)
  table.sort(jvers, function(a, b)
    return vcmp(a.id, b.id) > 0
  end)
  for _, version in ipairs(jvers) do
    version.hint = ({ ["21"] = "LTS，推荐", ["17"] = "最低可用" })[version.id] or ""
  end
  local jv = pick(jvers, "3. Java 版本")
  local bv = pick(boot_options(meta), "4. Spring Boot 版本")
  local packs = simple_options(meta.packaging)
  if #packs == 0 then
    packs = { { id = "jar" } }
  end
  for _, pack in ipairs(packs) do
    pack.hint = pack.id == "jar" and "可执行 jar，内嵌 Tomcat" or "部署到外部容器"
  end
  local pkg = pick(packs, "5. 打包方式")
  local deps = pick(dependency_options(meta), "6. 选择依赖", { multiple = true })
  local group = ask("7. Group ID（组织反写域名）", "com.example", valid_segment)
  local artifact = ask("8. Artifact ID（小写，建议无连字符）", "demo", valid_segment)
  local name = ask("9. 项目名 / 目录名", artifact, valid_segment)
  local pkgname =
    ask("10. 包名（点分隔的 ASCII Java 标识符）", sanitize_package(group .. "." .. artifact), valid_package)
  local parent = ask("11. 创建到哪个目录下", vim.fn.getcwd())
  local target
  target, parent = project_target(parent, name)
  local summary =
    table.concat({ build.id, lang.id, "Java " .. jv.id, "Boot " .. bv.id, pkg.id, #deps .. " 个依赖" }, "   ")
  local go = pick(
    {
      { id = "go", hint = "创建到 " .. target },
      { id = "redo", hint = "回到第 1 步，重新走一遍向导" },
      { id = "no", hint = "取消，不留任何文件" },
    },
    "确认创建",
    {
      footer = true,
      preview = function(item)
        if item.id == "go" then
          return { { summary, "WizKey" }, { "   →   ", "WizDim" }, { target, "WizSel" } }
        end
        return { { item.hint, "WizHint" } }
      end,
    }
  )
  if go.id == "redo" then
    return "redo"
  elseif go.id == "no" then
    error(CANCEL, 0)
  end
  vim.notify("正在创建 " .. target .. " …", vim.log.levels.INFO)
  local dir = generate_project(parent, name, {
    type = build.type,
    language = lang.id,
    javaVersion = jv.id,
    bootVersion = bv.id,
    packaging = pkg.id,
    groupId = group,
    artifactId = artifact,
    name = name,
    packageName = pkgname,
    dependencies = table.concat(deps, ","),
  })
  vim.fn.chdir(dir)
  local main = find_main_class(dir, lang.id)
  if main then
    vim.cmd("edit " .. vim.fn.fnameescape(main))
  end
  vim.notify("已创建 " .. dir .. "；可用项目自带的 wrapper 构建", vim.log.levels.INFO)
end

-- 当前行指针由 format 画出；Snacks 纯移动不置 dirty，因此只为向导补重绘。
local function patch_list_rerender_on_move()
  local List = require("snacks.picker.core.list")
  if List.__wiz_patched then
    return
  end
  local render = List.render
  List.render = function(self, ...)
    local source = self.picker and self.picker.opts.source
    if (source == "spring-wizard" or source == "spring-wizard-deps") and self.__wiz_cursor ~= self.cursor then
      self.dirty = true
      self.__wiz_cursor = self.cursor
    end
    return render(self, ...)
  end
  List.__wiz_patched = true
end

function M.create()
  if M._running then
    vim.notify("向导已在运行中——先完成或 Esc 退出当前那个", vim.log.levels.WARN)
    return
  end
  M._running = true
  coroutine.wrap(function()
    local ok, err = pcall(function()
      for _, tool in ipairs({ "curl", "unzip", "mv" }) do
        if vim.fn.executable(tool) ~= 1 then
          error("缺少项目生成工具：" .. tool, 0)
        end
      end
      ui.apply()
      FOOT_NS = FOOT_NS or vim.api.nvim_create_namespace("wiz_footer")
      patch_list_rerender_on_move()
      while flow() == "redo" do
      end
    end)
    M._running = false
    stop_pulse()
    if active_picker then
      pcall(active_picker.close, active_picker)
      active_picker = nil
    end
    if not ok then
      vim.notify(
        err == CANCEL and "已取消，未改动任何文件" or ("向导失败：" .. tostring(err)),
        err == CANCEL and vim.log.levels.INFO or vim.log.levels.ERROR
      )
    end
  end)()
end

return M
