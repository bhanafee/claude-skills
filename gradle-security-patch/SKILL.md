---
name: gradle-security-patch
description: Add a security patch for a transitive dependency in a Gradle project using the version catalog bundle pattern. Adds appropriate enforcement infrastructure and validates that patches work via OWASP dependencyCheckAnalyze.
argument-hint: <advisory-id> <group:artifact> <minimum-version> [project|plugin]
allowed-tools: Read, Edit, Glob, Grep, Bash
---

# Gradle Security Patch Skill

Patch a transitive dependency vulnerability by adding it to the version catalog and enforcing it through project constraints or dependency management overrides. All versions are managed in the version catalog (libs.versions.toml), never hardcoded in build.gradle.

## Arguments

`$ARGUMENTS` may contain up to four space-separated values:
1. Advisory ID (e.g. `GHSA-72hv-8253-57qq` or `CVE-2024-12345`)
2. Module in `group:artifact` form (e.g. `com.fasterxml.jackson.core:jackson-core`)
3. Minimum safe version (e.g. `2.21.1`)
4. Dependency type: `project` (default) or `plugin`

If any argument is missing, ask the user before proceeding.

## Step 1 — Locate the version catalog and check project structure

Find `gradle/libs.versions.toml` and `build.gradle`. Check:
- Does the project apply Spring Boot or import BOMs (search for `dependencyManagement` blocks)?
- Is it multi-module (check settings.gradle for `include` statements)?
- What does the project directly depend on (Spring Cloud starters, etc.)?

**Key insight**: Projects with complex BOM management (Spring Boot, Spring Cloud) need explicit dependency overrides in dependencyManagement, not just constraints.

## Step 2 — Add the patch to the version catalog

Add the library entry to `[libraries]` using `version { strictly }` constraints. Always include both `strictly` and `prefer` for consistency:

```toml
patch-cve-2026-54399 = { module = "org.apache.httpcomponents.core5:httpcore5", version = { strictly = "[5.4.3,)", prefer = "5.4.3" } }
```

Add the patch to the `security-patches` bundle in `[bundles]`.

The patch entry is the **only** place the version is declared. Do not add a matching `[versions]` key: BOM overrides (Step 3) read the version from the patch entry, so a second copy could only drift.

**Important for projects with settings.gradle parsing**: If the project uses `settings.gradle` or similar build scripts to parse and apply these patches programmatically (e.g., via regex matching), ensure the parsing logic is **robust to format variations**. Make the `prefer` clause optional in regex patterns, since Dependabot or manual edits might omit or reformat it. Brittle parsing can cause Dependabot PR validation to fail silently when constraints aren't applied to the buildscript classpath.

## Step 3 — Apply enforcement based on project structure

### For projects WITHOUT BOM imports (simple projects):

Ensure the `dependencies { constraints }` block exists in the subprojects (or root for single-module):

```groovy
dependencies {
    constraints {
        libs.bundles.security.patches.get().each {
            add('implementation', it)
        }
    }
}
```

This is sufficient and will be picked up by OWASP dependencyCheck.

### For projects WITH BOM imports (Spring Boot, Spring Cloud, etc.):

The module that imports the BOM needs explicit dependency management overrides, because BOMs take precedence over constraints. The overrides take their versions from the patch entries, so each version is declared once. If the build does not have it yet, add a `patchVersion` helper; in a multi-module build, set it as `ext.patchVersion` inside `subprojects` so every subproject can call it:

```groovy
// Spring Boot's BOM wins over the catalog's security-patch constraints for the modules it manages,
// so those modules also need a dependencyManagement override. The versions come from the patch
// entries in the catalog, so each patched version is declared only once.
def patchVersion = { String module ->
    def patch = libs.bundles.security.patches.get().find { it.module.toString() == module }
    if (patch == null) {
        throw new GradleException("No security-patches entry for ${module}")
    }
    patch.versionConstraint.preferredVersion
}
```

Then add the module to the override list in the `dependencyManagement` block:

```groovy
dependencyManagement {
    dependencies {
        [
            'org.apache.httpcomponents.core5:httpcore5',
            'org.apache.logging.log4j:log4j-api',
        ].each { module ->
            dependency "${module}:${patchVersion(module)}"
        }
    }
}
```

A BOM import that has to match a patch (for example the Jackson BOMs, imported after Spring Boot's to keep every Jackson module aligned) also takes its version from the patch: `mavenBom "com.fasterxml.jackson:jackson-bom:${patchVersion('com.fasterxml.jackson.core:jackson-databind')}"`.

**Critical**: Never hardcode version numbers in build.gradle, and never duplicate a patch version in `[versions]`. Only list a module in the overrides when its patched version is at or above what the BOM manages; otherwise the override would downgrade it, and the constraint alone is enough.

For multi-module projects with a BOM-importing submodule (e.g., `demo` module importing Spring Cloud), add the overrides to that submodule's build.gradle, not the root.

## Step 4 — Verify patches are enforced

Run `./gradlew build` to confirm the build succeeds with constraints/overrides in place.

## Step 5 — Validate with OWASP dependencyCheckAnalyze

Run the full OWASP scan to confirm the patched CVEs are resolved:

```bash
./gradlew dependencyCheckAnalyze 2>&1 | grep "CVE-XXXX"
```

Confirm that the CVE numbers you patched are **NOT** in the failure list. If they still appear, the patch is not being enforced—check:
- Are BOMs overriding your constraints? (likely if you only used constraints)
- Is the module listed in the `dependencyManagement` override list, and does `patchVersion` find its patch entry?
- For multi-module projects, are the overrides in the right submodule (the one that actually imports the BOM)?

## Step 6 — Report the outcome

Report to the user:
- Files changed (libs.versions.toml, build.gradle, and/or submodule build.gradle)
- Whether constraints, BOM overrides, or both were used
- Verify that **no version numbers appear in build.gradle** — all versions come from libs.versions.toml
- Confirmed resolved version from OWASP scan showing the patched CVE is gone
- CVEs/advisories addressed by this patch

**Example:**
- Modified `gradle/libs.versions.toml`: Added the `patch-cve-2026-54399` library entry and its bundle entry
- Modified `demo/build.gradle`: Added `org.apache.httpcomponents.core5:httpcore5` to the dependencyManagement override list
- OWASP scan confirms: CVE-2026-54399 no longer in failure list ✅
