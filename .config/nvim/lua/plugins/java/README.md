# Java / jdtls configuration

Bazel-aware Java LSP setup built on [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) and [astrocommunity.pack.java](https://github.com/AstroNvim/astrocommunity).

## Files

| File | Purpose |
|---|---|
| `jdtls.lua` | jdtls server config, Bazel root detection, automatic classpath generation |
| `config.lua` | Community pack import, `google-java-format`, LSP tweaks, user commands, statusline component |
| `../../scripts/bazel-jdtls-classpath.sh` | Shell script called by `jdtls.lua` to build a Bazel target and extract transitive JARs |

## Requirements

- **Java** managed by [SDKMAN](https://sdkman.io/) — the active candidate at `~/.sdkman/candidates/java/current` is used both to launch jdtls and as the `JavaSE-25` runtime.
- **jdtls** installed by Mason (`:MasonInstall jdtls`).
- **google-java-format** installed by Mason (`:MasonInstall google-java-format`).
- **Bazel** in `$PATH` — required only for Bazel projects; Maven/Gradle projects work without it.

## How it works

### Non-Bazel projects (Maven, Gradle, plain Git)

jdtls starts normally with the nearest `mvnw`, `gradlew`, or `.git` directory as the project root. No extra setup needed.

### Bazel projects

On first open of a Java file inside a Bazel package (`BUILD.bazel` present):

1. A stub `.project` / `.classpath` is written to the package root so jdtls starts in project mode immediately.
2. After a 2-second debounce (to let jdtls initialise), the nearest `java_library` target in that package is located via `bazel query`.
3. `scripts/bazel-jdtls-classpath.sh` builds that target and uses `bazel cquery` to collect all transitive compile JARs.
4. `.classpath` is overwritten with the real JARs and jdtls restarts to index them.

On subsequent opens the `.classpath` already contains JARs, so no rebuild or restart occurs.

Build progress is shown in the statusline as `⟳ built/total` while the Bazel build runs.

The generated `.project` and `.classpath` files live inside the Bazel package directory. Add them to `.gitignore` (or `.git/info/exclude`) if your repo does not already ignore them:

```
.project
.classpath
.nvim/
```

## Commands

| Command | Description |
|---|---|
| `:JdtlsRefreshClasspath` | Delete `.project` / `.classpath`, stop jdtls, and reopen the buffer to trigger a full classpath rebuild. Use this after adding or changing Bazel dependencies. |
| `:JdtlsBuildLog` | Open the Bazel build log (`~/.cache/nvim/jdtls-bazel/build.log`) in a bottom split with auto-reload. Useful for diagnosing classpath build failures. |

## Formatting

Formatting is handled by **google-java-format** via `none-ls` — jdtls's built-in formatter is disabled. Format with the standard AstroNvim binding (`<Leader>lf`) or on save if `format_on_save` is enabled.

Pass `--skip-reflowing-long-strings` by default to avoid unwanted rewrapping of string literals.

## Customisation

**Change the Java version** — edit the `JavaSE-25` entry in `jdtls.lua`:

```lua
opts.settings.java.configuration.runtimes = {
  { name = "JavaSE-21", path = java_home, default = true },
}
```

**Target selection** — the script picks the first `java_library` rule in `//pkg:all`, falling back to any java rule. If your package uses a different rule type, adjust the pattern in `find_bazel_target` inside `jdtls.lua`.

**Classpath cache** — cached classpath files are stored in `~/.cache/nvim/jdtls-bazel/` keyed by workspace + target. Delete this directory to force a cold rebuild on next open.
