-- 跨语言的基础工具与注入语法；不承载某一种语言的业务逻辑。
return {
  tools = { "tree-sitter-cli" },
  treesitter = { parsers = { "diff", "query", "regex" } },
}
