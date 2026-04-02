-- Java tooling: community pack, formatter, LSP tweaks, user commands, statusline component.

---@type LazySpec
return {
  -- Base pack (mason installs jdtls, treesitter grammar, etc.)
  { import = "astrocommunity.pack.java" },

  -- Disable jdtls built-in formatting; google-java-format handles it via none-ls.
  {
    "AstroNvim/astrolsp",
    opts = {
      formatting = {
        disabled = { "jdtls" },
      },
    },
  },

  -- google-java-format as the Java formatter through none-ls.
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local null_ls = require "null-ls"
      opts.sources = require("astrocore").list_insert_unique(opts.sources, {
        null_ls.builtins.formatting.google_java_format.with {
          extra_args = { "--skip-reflowing-long-strings" },
        },
      })
    end,
  },

  -- :JdtlsRefreshClasspath and :JdtlsBuildLog user commands.
  {
    "AstroNvim/astrocore",
    opts = {
      commands = {
        JdtlsRefreshClasspath = {
          function()
            local root = vim.fs.root(0, "BUILD.bazel")
            if not root then vim.notify("[jdtls] No BUILD.bazel found", vim.log.levels.WARN); return end
            vim.fn.delete(root .. "/.classpath")
            vim.fn.delete(root .. "/.project")
            for _, client in ipairs(vim.lsp.get_clients { name = "jdtls" }) do
              client.stop()
            end
            vim.notify("[jdtls] Classpath reset — restarting…", vim.log.levels.INFO)
            vim.defer_fn(function() vim.cmd "e" end, 500)
          end,
          desc = "Reset jdtls Eclipse project files and restart the server",
        },
        JdtlsBuildLog = {
          function()
            local log = vim.fn.expand "~/.cache/nvim/jdtls-bazel/build.log"
            vim.cmd("botright 15split " .. log)
            vim.cmd "setlocal autoread nobuflisted"
            vim.cmd "normal! G"
          end,
          desc = "Open jdtls Bazel build log",
        },
      },
    },
  },

  -- Bazel build progress indicator in the statusline (set by jdtls.lua, cleared when done).
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      table.insert(opts.statusline, #opts.statusline, {
        condition = function() return _G.jdtls_bazel_status ~= nil end,
        provider = function() return " " .. _G.jdtls_bazel_status .. " " end,
        hl = { fg = "orange", bold = true },
      })
      return opts
    end,
  },
}
