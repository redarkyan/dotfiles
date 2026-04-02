-- Bazel-aware jdtls configuration.
-- Overrides the base spec from astrocommunity.pack.java (loaded first via community.lua).
--
-- On first attach to a Bazel Java file:
--   1. Writes stub Eclipse .project/.classpath to the package root so jdtls
--      starts in project mode immediately (both files are gitignored upstream).
--   2. Finds the java_library target in the nearest BUILD.bazel package.
--   3. Runs bazel-jdtls-classpath.sh to build the target and extract transitive JARs.
--   4. Overwrites .classpath with real JARs, restarts jdtls so it indexes them.
-- On subsequent attaches .classpath already has JARs — no rebuild, no restart.
-- Use :JdtlsRefreshClasspath to force regeneration after dependency changes.

local script   = vim.fn.expand "~/.config/nvim/scripts/bazel-jdtls-classpath.sh"
local log_file = vim.fn.expand "~/.cache/nvim/jdtls-bazel/build.log"
local _build_timers = {}

local function bazel_workspace(dir)
  return vim.fs.root(dir, "WORKSPACE") or vim.fs.root(dir, "WORKSPACE.bazel")
end

local function write_eclipse_project(root_dir, jars)
  local project_name = vim.fn.fnamemodify(root_dir, ":t")

  vim.fn.writefile({
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<projectDescription>",
    "  <name>" .. project_name .. "</name>",
    "  <buildSpec><buildCommand>",
    "    <name>org.eclipse.jdt.core.javabuilder</name>",
    "  </buildCommand></buildSpec>",
    "  <natures><nature>org.eclipse.jdt.core.javanature</nature></natures>",
    "</projectDescription>",
  }, root_dir .. "/.project")

  local cp = { '<?xml version="1.0" encoding="UTF-8"?>', "<classpath>" }
  local src_rels = {}
  for _, rel in ipairs { "src/main/java", "src/test/java", "java", "src" } do
    if vim.fn.isdirectory(root_dir .. "/" .. rel) == 1 then
      table.insert(src_rels, rel)
    end
  end
  if #src_rels == 0 then
    table.insert(src_rels, ".")
  end
  for _, rel in ipairs(src_rels) do
    table.insert(cp, '  <classpathentry kind="src" path="' .. rel .. '"/>')
  end
  table.insert(cp, '  <classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/>')
  for _, jar in ipairs(jars) do
    table.insert(cp, '  <classpathentry kind="lib" path="' .. jar .. '"/>')
  end
  table.insert(cp, '  <classpathentry kind="output" path=".nvim/.jdtls-bin"/>')
  table.insert(cp, "</classpath>")
  vim.fn.writefile(cp, root_dir .. "/.classpath")
end

local function find_bazel_target(package_dir, workspace_root, cb)
  local rel   = package_dir:sub(#workspace_root + 2)
  local query = "//" .. rel .. ":all"
  vim.system(
    { "bazel", "query", query, "--output=label_kind" },
    { cwd = workspace_root, text = true },
    function(result)
      if result.code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "[jdtls] bazel query failed for " .. query .. ":\n" .. (result.stderr or ""),
            vim.log.levels.WARN
          )
        end)
        cb(nil); return
      end
      local stdout = result.stdout or ""
      for line in stdout:gmatch "[^\n]+" do
        local kind, label = line:match "^(%S+)%s+rule%s+(%S+)$"
        if kind and not kind:match "^_" and kind:match "java_library$" then cb(label); return end
      end
      for line in stdout:gmatch "[^\n]+" do
        local kind, label = line:match "^(%S+)%s+rule%s+(%S+)$"
        if kind and not kind:match "^_" and kind:match "java" then cb(label); return end
      end
      vim.schedule(function()
        vim.notify(
          "[jdtls] no java target found in " .. query .. ".\nOutput:\n" .. stdout,
          vim.log.levels.WARN
        )
      end)
      cb(nil)
    end
  )
end

local function refresh_classpath(client, root_dir, opts)
  local workspace_root = bazel_workspace(root_dir)
  if not workspace_root then return end
  if root_dir == workspace_root then return end

  local classpath_file = root_dir .. "/.classpath"
  if vim.fn.filereadable(classpath_file) == 1 then
    local content = table.concat(vim.fn.readfile(classpath_file), "\n")
    if content:find('kind="lib"', 1, true) then return end
  end

  _G.jdtls_bazel_status = "⟳ querying…"
  vim.cmd "redrawstatus"

  find_bazel_target(root_dir, workspace_root, function(target)
    if not target then
      vim.schedule(function()
        _G.jdtls_bazel_status = nil
        vim.cmd "redrawstatus"
      end)
      return
    end

    local timer = vim.uv.new_timer()
    vim.schedule(function()
      _G.jdtls_bazel_status = "⟳ 0/?"
      vim.cmd "redrawstatus"
    end)
    timer:start(300, 300, vim.schedule_wrap(function()
      local f = io.open(log_file, "r")
      if not f then return end
      local content = f:read "*a"
      f:close()
      local built, total
      for b, t in content:gmatch "%[(%d+) / (%d+)%]" do built, total = b, t end
      if built then
        _G.jdtls_bazel_status = string.format("⟳ %s/%s", built, total)
        vim.cmd "redrawstatus"
      end
    end))

    vim.system({ script, workspace_root, target }, { text = true }, function(result)
      timer:stop()
      timer:close()
      local stdout, stderr, code = result.stdout, result.stderr, result.code
      vim.schedule(function()
        _G.jdtls_bazel_status = nil
        vim.cmd "redrawstatus"
        if code ~= 0 then
          vim.notify("[jdtls] Classpath build failed:\n" .. (stderr or ""), vim.log.levels.WARN)
          return
        end
        local jars = vim.fn.readfile(vim.trim(stdout))
        jars = vim.tbl_filter(function(j) return vim.fn.filereadable(j) == 1 end, jars)
        if #jars == 0 then return end

        write_eclipse_project(root_dir, jars)
        vim.notify(
          "[jdtls] Eclipse project files written (" .. #jars .. " JARs) — restarting…",
          vim.log.levels.INFO
        )
        opts.root_dir = root_dir
        client.stop()
        vim.defer_fn(function() require("jdtls").start_or_attach(opts) end, 1000)
      end)
    end)
  end)
end

---@type LazySpec
return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local java_home = vim.fn.expand "~/.sdkman/candidates/java/current"
      opts.cmd[1] = java_home .. "/bin/java"
      opts.settings.java.configuration.runtimes = {
        { name = "JavaSE-25", path = java_home, default = true },
      }
      opts.settings.java.format = { enabled = false }

      opts.handlers = opts.handlers or {}
      opts.handlers["window/showMessage"] = function(_, result, _)
        local msg = result.message
        if msg:find("non project file", 1, true) then return end
        if msg:match "^%d+%%" then return end   -- "0% Starting Java Language Server", etc.
        if msg:match "^Init" then return end     -- "Init..."
        if msg == "WARNING" then return end      -- bare WARNING emitted at startup
        local levels = { vim.log.levels.ERROR, vim.log.levels.WARN, vim.log.levels.INFO, vim.log.levels.DEBUG }
        vim.notify(msg, levels[result.type] or vim.log.levels.INFO)
      end

      -- Registered here (inside opts) so it fires before the community pack's
      -- start_or_attach autocmd (community pack registers its autocmd in config,
      -- which Lazy calls after opts). This ensures root_dir is correct per buffer
      -- before jdtls starts.
      vim.api.nvim_create_autocmd("Filetype", {
        pattern = "java",
        callback = function()
          local bazel_pkg = vim.fs.root(0, "BUILD.bazel")
          if bazel_pkg then
            if vim.fn.filereadable(bazel_pkg .. "/.classpath") == 0 then
              write_eclipse_project(bazel_pkg, {})
            end
            opts.root_dir = bazel_pkg
          else
            opts.root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew" })
          end
        end,
      })

      local base_on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr, ...)
        if base_on_attach then base_on_attach(client, bufnr, ...) end
        local root_dir = vim.fs.root(bufnr, "BUILD.bazel")
        if not root_dir or not bazel_workspace(root_dir) then return end

        if _build_timers[root_dir] then
          _build_timers[root_dir]:stop()
          _build_timers[root_dir]:close()
          _build_timers[root_dir] = nil
        end

        local timer = vim.uv.new_timer()
        _build_timers[root_dir] = timer
        timer:start(2000, 0, vim.schedule_wrap(function()
          timer:stop(); timer:close()
          _build_timers[root_dir] = nil
          if vim.api.nvim_get_current_buf() == bufnr then
            refresh_classpath(client, root_dir, opts)
          end
        end))
      end

      return opts
    end,
  },
}
