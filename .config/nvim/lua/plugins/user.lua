-- You can also add or configure plugins by creating files in this `plugins/` folder
-- Here are some examples:

---@type LazySpec
return {
  -- {
  --   "yetone/avante.nvim",
  --   opts = {
  --     provider = "claude",
  --     auto_suggestions_provider = "claude",
  --     behaviour = {
  --       auto_suggestions = true,
  --     },
  --     providers = {
  --       claude = {
  --         model = "claude-sonnet-4-6",
  --         extra_request_body = {
  --           temperature = 0.75,
  --           max_tokens = 8096,
  --         },
  --       },
  --     },
  --   },
  -- },

  -- astrocommunity.recipes.ai overrides blink Tab to only snippet_forward/ai_accept,
  -- dropping select_next. Restore the full binding here.
  {
    "Saghen/blink.cmp",
    optional = true,
    opts = {
      keymap = {
        ["<Tab>"] = {
          "select_next",
          "snippet_forward",
          function(cmp)
            if vim.g.ai_accept then return vim.g.ai_accept() end
          end,
          "fallback",
        },
        ["<S-Tab>"] = {
          "select_prev",
          "snippet_backward",
          "fallback",
        },
      },
    },
  },

  { "j-hui/fidget.nvim", opts = {} },

  -- Auto-load .vscode/launch.json when nvim-dap is available.
  -- Needed for Bazel-generated LLDB debug configs (bazel run @rules_rust//tools/vscode:gen_launch_json).
  {
    "mfussenegger/nvim-dap",
    optional = true,
    config = function()
      local dap_vscode = require "dap.ext.vscode"
      local launchjs = vim.fn.getcwd() .. "/.vscode/launch.json"
      if vim.fn.filereadable(launchjs) == 1 then dap_vscode.load_launchjs(launchjs, { codelldb = { "rust", "c", "cpp" } }) end
    end,
  },

  -- == Examples of Adding Plugins ==

  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },
  {
    "mrheinen/bazelbub.nvim",
    version = "v0.2",
  },
  -- == Examples of Overriding Plugins ==

  -- customize alpha options

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- v2.7.0 tag crashes on Neovim 0.12 (iter_matches API change). master has the fix.
  { "stevearc/aerial.nvim", version = false, branch = "master" },


  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },
  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    ---@type solarized.config
    opts = {},
    config = function(_, opts)
      vim.o.termguicolors = true
      vim.o.background = "light"
      require("solarized").setup(opts)
      vim.cmd.colorscheme "solarized"
    end,
  },
  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
}
