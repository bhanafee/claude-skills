---
name: gradle-security-patch
description: Add a security patch for a transitive dependency in a Gradle project using the version catalog bundle pattern. Use when a CVE or security advisory (e.g. GHSA-xxxx) requires pinning a minimum version of an indirect dependency, whether introduced by a project dependency or a plugin.
argument-hint: <advisory-id> <group:artifact> <minimum-version> [project|plugin]
allowed-tools: Read, Edit, Glob, Grep, Bash
---

# Gradle Security Patch Skill

Patch a transitive dependency vulnerability by adding it to the version catalog `security-patches` bundle and enforcing it in `build.gradle`.

## Arguments

`$ARGUMENTS` may contain up to four space-separated values:
1. Advisory ID (e.g. `GHSA-72hv-8253-57qq` or `CVE-2024-12345`)
2. Module in `group:artifact` form (e.g. `com.fasterxml.jackson.core:jackson-core`)
3. Minimum safe version (e.g. `2.21.1`)
4. Dependency type: `project` (default) or `plugin`

If any argument is missing, ask the user before proceeding.

## Step 1 — Locate the version catalog

Find `gradle/libs.versions.toml` relative to the project root. If it does not exist, stop and tell the user.

## Step 2 — Add the library entry to the catalog

The library alias must be all-lowercase. Derive it from the advisory ID:
- Prefix with `patch-`
- Lowercase the entire advisory ID
- Example: `GHSA-72hv-8253-57qq` → `patch-ghsa-72hv-8253-57qq`

Add the library under `[libraries]` (create the section if absent) using a rich version constraint that enforces the minimum but allows higher versions:

```toml
patch-ghsa-72hv-8253-57qq = { module = "com.fasterxml.jackson.core:jackson-core", version = { strictly = "[2.21.1,)", prefer = "2.21.1" } }
```

Replace the alias, module, and version with the actual values.

## Step 3 — Add the library to the security-patches bundle

Locate the `[bundles]` section (create it if absent, always place it before `[plugins]`).

If a `security-patches` bundle already exists, append the new alias to its list.
If it does not exist, create it:

```toml
security-patches = ["patch-ghsa-72hv-8253-57qq"]
```

## Step 4 — Update build.gradle and settings.gradle

Read `build.gradle`. The bundle accessor for `security-patches` is `libs.bundles.security.patches` (hyphens create nested accessors in Gradle's type-safe API).

### For project transitive dependencies (`project` type)

Ensure a `dependencies { constraints { ... } }` block exists that iterates the bundle and adds each entry as an `implementation` constraint. This propagates to `compileClasspath` and `runtimeClasspath` — the configurations Gradle and security scanners analyse.

If the block is already present, verify the bundle reference is included; do not duplicate it.

If it is absent, add it after the `repositories { }` block:

```groovy
dependencies {
    constraints {
        libs.bundles.security.patches.get().each {
            add('implementation', it)
        }
    }
}
```

### For plugin transitive dependencies (`plugin` type)

The version catalog (`libs`) is **not** available inside `buildscript {}` blocks, and the classpath is locked before project scope runs. Therefore enforcement requires two things:

1. **Catalog entry** — follow Steps 2 and 3 above so the patch is documented and enforced for any project configurations that may also resolve the dependency.

2. **`settings.gradle` hook** — `gradle.beforeProject` fires before the root project's buildscript classpath is resolved, and at that point `libs` is not yet available. Instead, read `patch-*` entries directly from `libs.versions.toml` and add them to the buildscript classpath programmatically.

Read `settings.gradle`. If a `gradle.beforeProject` block with TOML parsing is already present, no change is needed — new catalog entries are picked up automatically.

If it is absent, add it after the `rootProject.name` line:

```groovy
gradle.beforeProject { proj ->
    if (proj == proj.rootProject) {
        def tomlFile = new File(proj.rootDir, 'gradle/libs.versions.toml')
        tomlFile.eachLine { line ->
            def matcher = line =~ /^patch-[a-z0-9-]+ = \{ module = "([^"]+)", version = \{ strictly = "[^"]+", prefer = "([^"]+)"/
            if (matcher) {
                proj.buildscript.dependencies.add('classpath', "${matcher[0][1]}:${matcher[0][2]}")
            }
        }
    }
}
```

This reads every `patch-*` library from the TOML and adds it to the buildscript classpath before resolution. Gradle's conflict resolution selects the highest version, so adding a new catalog entry is sufficient — no further changes to `build.gradle` or `settings.gradle` are needed for subsequent patches.

Also ensure `build.gradle` has the project-level `dependencies { constraints { ... } }` block (see above), so the patch is applied to both the plugin classpath and project configurations.

If a `buildscript {}` block exists in `build.gradle` with explicit `classpath` entries for security patches, remove those entries — they are now redundant. Keep the `buildscript { repositories { mavenCentral() } }` block if present.

## Step 5 — Build and test

Run `./gradlew build` and confirm it succeeds. If it fails with a catalog accessor error, check:
- The library alias is fully lowercase
- The bundle name and accessor match (`security-patches` → `libs.bundles.security.patches`)
- The `[libraries]` section appears before `[bundles]` in the TOML file

Report the outcome to the user, including which files were changed and what the resolved constraint enforces.
