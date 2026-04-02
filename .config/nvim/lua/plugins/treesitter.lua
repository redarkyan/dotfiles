-- Customize Treesitter
-- nvim-treesitter stays on master (required by AstroNvim's configs integration).
-- patches/nvim-treesitter-unwrap-node.patch fixes the Neovim 0.12 iter_matches
-- API change (all=false now returns lists; patch unwraps nodes at the call site).

---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = "git apply --ignore-whitespace "
      .. vim.fn.stdpath "config"
      .. "/patches/nvim-treesitter-unwrap-node.patch || true",
    opts = {
      ensure_installed = { "lua", "rust", "toml" },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      ident = { enable = true },
      rainbow = {
        enable = true,
        extended_mode = true,
        max_file_lines = nil,
      },
    },
  },
}
