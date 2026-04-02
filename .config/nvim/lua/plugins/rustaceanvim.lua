-- Local patch: guard nil cargoArgs in debuggables (upstream fix pending).
-- patches/rustaceanvim-nil-cargoargs.patch is re-applied after every :Lazy update.

---@type LazySpec
return {
  "mrcjkb/rustaceanvim",
  build = "git apply --ignore-whitespace "
    .. vim.fn.stdpath "config"
    .. "/patches/rustaceanvim-nil-cargoargs.patch || true",
}
