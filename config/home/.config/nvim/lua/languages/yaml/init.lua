return {
  lsp = { yamlls = {} },
  tools = { "yaml-language-server" },
  treesitter = {
    parsers = { "yaml" },
    filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
  },
  filetypes = {
    filename = {
      [".gitlab-ci.yml"] = "yaml.gitlab",
      [".gitlab-ci.yaml"] = "yaml.gitlab",
      ["docker-compose.yml"] = "yaml.docker-compose",
      ["docker-compose.yaml"] = "yaml.docker-compose",
    },
    pattern = {
      [".*/docker%-compose%..*%.yml"] = "yaml.docker-compose",
      [".*/docker%-compose%..*%.yaml"] = "yaml.docker-compose",
      [".*/compose%.yml"] = "yaml.docker-compose",
      [".*/compose%.yaml"] = "yaml.docker-compose",
      [".*/templates/.*%.yml"] = "yaml.helm-values",
      [".*/templates/.*%.yaml"] = "yaml.helm-values",
    },
  },
}
