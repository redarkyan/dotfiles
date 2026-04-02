-- Suppress deprecation warnings from third-party plugins using old Neovim LSP APIs
-- (e.g. client:supports_method() → vim.lsp.client.supports_method()).
-- Remove once upstream plugins are updated.
local _orig_deprecate = vim.deprecate
vim.deprecate = function(name, ...)
  if name and name:find("supports_method", 1, true) then return end
  return _orig_deprecate(name, ...)
end

return {}
