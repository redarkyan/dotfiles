--Set completeopt to have a better completion experience
-- :help completeopt
-- menuone: popup even when there's only one match
-- noinsert: Do not insert text until a selection is made
-- noselect: Do not select, force to select one from the menu
-- shortness: avoid showing extra messages when using completion
-- updatetime: set updatetime for CursorHold
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }
vim.opt.shortmess = vim.opt.shortmess + { c = true }
vim.api.nvim_set_option("updatetime", 300)

-- Fixed column for diagnostics to appear
-- Show autodiagnostic popup on cursor hover_range
-- Goto previous / next diagnostic warning / error
-- Show inlay_hints more frequently
vim.cmd [[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]]

-- Handle workspace/diagnostic/refresh from servers using pull diagnostics (LSP 3.17+).
-- Nvim 0.11 enables pull diagnostics automatically but has no built-in handler for this
-- server-to-client request, so without it rust-analyzer's refresh signals are silently dropped.
vim.lsp.handlers["workspace/diagnostic/refresh"] = function(err, _, ctx)
  if err then return vim.NIL end
  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
    vim.lsp.util._refresh("textDocument/diagnostic", { bufnr = bufnr, client_id = ctx.client_id })
  end
  return vim.NIL
end

-- setup bazel/starlark lsp
if vim.fn.executable "bzl" == 1 then
  vim.lsp.start {
    name = "Bazel/Starlark Language Server",
    cmd = { "bzl", "lsp", "serve" },
  }
end
