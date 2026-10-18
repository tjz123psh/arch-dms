return {
  -- Neovim 将 .xsl/.xslt 识别为 xslt；排除上游默认的未知 filetype xsl。
  lsp = { lemminx = { filetypes = { "xml", "xsd", "xslt", "svg" } } },
  tools = { "lemminx" },
}
