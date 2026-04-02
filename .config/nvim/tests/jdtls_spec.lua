-- Headless tests for jdtls.lua logic.
-- Run with: nvim --headless -l tests/jdtls_spec.lua

local pass, fail = 0, 0
local function ok(name, cond, msg)
  if cond then
    pass = pass + 1
    print("  PASS  " .. name)
  else
    fail = fail + 1
    print("  FAIL  " .. name .. (msg and ("  →  " .. msg) or ""))
  end
end

local function tmpdir()
  local p = vim.fn.tempname()
  vim.fn.mkdir(p, "p")
  return p
end

local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function touch_java(dir, rel)
  local full = dir .. "/" .. rel
  vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
  vim.fn.writefile({ "class X{}" }, full)
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

local function classpath_has_lib(root_dir)
  local f = root_dir .. "/.classpath"
  if vim.fn.filereadable(f) == 0 then return false end
  return table.concat(vim.fn.readfile(f), "\n"):find('kind="lib"', 1, true) ~= nil
end

print("\n── write_eclipse_project ──")

do
  local root = tmpdir()
  write_eclipse_project(root, {})
  ok("stub: .project at package root",   vim.fn.filereadable(root .. "/.project") == 1)
  ok("stub: .classpath at package root", vim.fn.filereadable(root .. "/.classpath") == 1)
  ok("stub: no lib entries",             not classpath_has_lib(root))
end

do
  local root = tmpdir()
  write_eclipse_project(root, { "/some/dep.jar" })
  ok("real: guard skips build", classpath_has_lib(root))
end

do
  local root = tmpdir()
  vim.fn.mkdir(root .. "/src/main/java", "p")
  vim.fn.mkdir(root .. "/src/test/java", "p")
  write_eclipse_project(root, {})
  local cp = read(root .. "/.classpath")
  ok("maven: src/main/java entry",    cp:find('"src/main/java"', 1, true) ~= nil)
  ok("maven: src/test/java entry",    cp:find('"src/test/java"', 1, true) ~= nil)
  ok("maven: paths are relative",     cp:find('path="/', 1, true) == nil,
     "no absolute paths in kind=src entries")
  ok("maven: no .. relative paths",   cp:find('path="%.%.', 1, false) == nil)
end

do
  local root = tmpdir()
  touch_java(root, "com/example/Foo.java")
  write_eclipse_project(root, {})
  local cp = read(root .. "/.classpath")
  ok("flat: falls back to \".\"",     cp:find('kind="src" path="."', 1, true) ~= nil)
  ok("flat: paths are relative",      cp:find('path="/', 1, true) == nil)
end

do
  local root = tmpdir()
  write_eclipse_project(root, {})
  local cp = read(root .. "/.classpath")
  ok("empty: falls back to \".\"",    cp:find('kind="src" path="."', 1, true) ~= nil)
  ok("empty: JRE_CONTAINER present",  cp:find("JRE_CONTAINER", 1, true) ~= nil)
end

do
  local root = tmpdir() .. "/my-service"
  vim.fn.mkdir(root, "p")
  write_eclipse_project(root, {})
  ok(".project: name = dir name",
     read(root .. "/.project"):find("<name>my-service</name>", 1, true) ~= nil)
end

do
  local root = tmpdir()
  write_eclipse_project(root, {})
  local cp = read(root .. "/.classpath")
  ok("output: project-relative .nvim/.jdtls-bin",
     cp:find('kind="output" path=".nvim/.jdtls-bin"', 1, true) ~= nil)
end

print(string.format("\n%d passed, %d failed", pass, fail))
vim.cmd(fail > 0 and "cq" or "q")
