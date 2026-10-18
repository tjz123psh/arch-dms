-- Java 源码解析：包名、主类、测试选择器共用 Treesitter。
local M = {}

local class_types = {
  class_declaration = true,
  interface_declaration = true,
  enum_declaration = true,
  record_declaration = true,
}

local function node_name(node, bufnr)
  local name = node:field("name")[1]
  return name and vim.treesitter.get_node_text(name, bufnr) or nil
end

local function parse(source)
  local ok, root = pcall(function()
    local parser = type(source) == "string" and vim.treesitter.get_string_parser(source, "java")
      or vim.treesitter.get_parser(source, "java")
    return assert(parser:parse()[1], "empty parse result"):root()
  end)
  if not ok then
    return nil, "Java 语法解析器不可用（:TSInstall java）：" .. tostring(root)
  end
  return root
end

local function package_of(root, source)
  for child in root:iter_children() do
    if child:type() == "package_declaration" then
      for part in child:iter_children() do
        if part:type() == "identifier" or part:type() == "scoped_identifier" then
          return (vim.treesitter.get_node_text(part, source):gsub("%s+", ""))
        end
      end
    end
  end
end

function M.package(source)
  local root, err = parse(source)
  if not root then
    return nil, err
  end
  return package_of(root, source)
end

-- 从真实方法节点找入口，不把注释、字符串或嵌套类入口归到文件名上。
function M.mains(source)
  local root, err = parse(source)
  if not root then
    return nil, err
  end
  local package_name = package_of(root, source) or ""
  local out = {}
  local function walk(node, names)
    if class_types[node:type()] then
      names = vim.list_extend(vim.deepcopy(names), { node_name(node, source) })
    elseif node:type() == "object_creation_expression" or node:type() == "constructor_declaration" then
      return
    elseif node:type() == "method_declaration" then
      local modifiers, return_type, params = "", node:field("type")[1], node:field("parameters")[1]
      for child in node:iter_children() do
        if child:type() == "modifiers" then
          modifiers = vim.treesitter.get_node_text(child, source)
        end
      end
      local parameter = params and params:named_child_count() == 1 and params:named_child(0)
      local argument_type, dimensions = "", ""
      if parameter then
        for child in parameter:iter_children() do
          if vim.tbl_contains({ "array_type", "type_identifier", "scoped_type_identifier" }, child:type()) then
            argument_type = vim.treesitter.get_node_text(child, source):gsub("%s+", ""):gsub("^java%.lang%.", "")
          elseif child:type() == "dimensions" then
            dimensions = vim.treesitter.get_node_text(child, source):gsub("%s+", "")
          end
        end
      end
      local spread = parameter and parameter:type() == "spread_parameter"
      local valid_args = (argument_type == "String[]" and dimensions == "" and not spread)
        or (argument_type == "String" and (dimensions == "[]" or spread))
      if
        #names > 0
        and not node:has_error()
        and node_name(node, source) == "main"
        and return_type
        and vim.treesitter.get_node_text(return_type, source) == "void"
        and modifiers:match("%f[%w]public%f[%W]")
        and modifiers:match("%f[%w]static%f[%W]")
        and valid_args
      then
        local simple = table.concat(names, "$")
        out[#out + 1] = {
          simple = simple,
          pkg = package_name,
          fqcn = package_name ~= "" and (package_name .. "." .. simple) or simple,
        }
      end
      return -- 不把方法体中的局部类当成可启动的顶层入口。
    end
    for child in node:iter_children() do
      walk(child, names)
    end
  end
  walk(root, {})
  return out
end

--- 返回 Maven 使用的 类名[#方法]；调用方负责 shellescape，Gradle 将 # 换成 .。
function M.selector(bufnr, include_method)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local root, err = parse(bufnr)
  if not root then
    return nil, err
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  -- 行首缩进不属于方法节点；让光标在缩进上时也能选中本行声明，空行不跨界。
  col = math.max(col, (line:find("%S") or 1) - 1)
  local node = root:named_descendant_for_range(row, col, row, col)
  local method
  if include_method then
    while node and not class_types[node:type()] do
      if node:type() == "method_declaration" then
        method = node
        break
      end
      if node:type() == "constructor_declaration" or node:type() == "class_body" then
        break
      end
      node = node:parent()
    end
    if not method then
      return nil, "光标不在 Java 方法内，未运行测试"
    end
    if method:has_error() then
      return nil, "当前方法存在语法错误，无法可靠定位测试"
    end
  end

  local names = {}
  while node do
    local kind = node:type()
    if class_types[kind] then
      local parent = node:parent()
      local owner = parent and parent:type() or ""
      if
        not vim.tbl_contains(
          { "program", "class_body", "interface_body", "enum_body_declarations", "annotation_type_body" },
          owner
        )
      then
        return nil, "不支持将方法或初始化块内的局部类作为测试目标"
      end
      local name = node_name(node, bufnr)
      if not name then
        return nil, "无法识别当前 Java 类名"
      end
      table.insert(names, 1, name)
    elseif kind == "object_creation_expression" or kind == "enum_constant" then
      return nil, "不支持将匿名类作为测试目标"
    elseif #names > 0 and (kind == "method_declaration" or kind == "constructor_declaration") then
      return nil, "不支持将方法内的局部类作为测试目标"
    end
    node = node:parent()
  end
  if #names == 0 then
    -- 类测试保留在 package/import 行也可运行当前文件主类的用法。
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t:r")
    for child in root:iter_children() do
      if class_types[child:type()] and node_name(child, bufnr) == filename then
        names = { filename }
        break
      end
    end
  end
  if #names == 0 then
    return nil, "未找到当前 Java 测试类"
  end
  local package_name = package_of(root, bufnr)
  local selector = table.concat(names, "$")
  if package_name then
    selector = package_name .. "." .. selector
  end
  if method then
    local name = node_name(method, bufnr)
    if not name then
      return nil, "无法识别当前 Java 测试方法名"
    end
    selector = selector .. "#" .. name
  end
  return selector
end

return M
