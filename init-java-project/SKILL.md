---
name: init-java-project
description: Initialize a new Java/Gradle library project matching the maybeitssquid project conventions — build.gradle, version catalog, GitHub Actions CI/publish/pages workflows, pandoc site assets, and dependabot config.
argument-hint: <ProjectName> <owner/repo> "<description>"
allowed-tools: Read, Write, Bash, Glob
---

# Initialize Java/Gradle Project

Set up a new project in the current working directory using the same conventions as
`achcharset`, `masking`, `retryhttp`, `rotatingsecrets`, and `atleastonce`.

The skill directory is `~/.claude/skills/init-java-project/`. All template and asset
files live there.

## Arguments

`$ARGUMENTS` should contain three values:
1. **ProjectName** — CamelCase project name used in `settings.gradle` and POM (e.g. `RetryHTTP`)
2. **owner/repo** — GitHub owner and repo slug (e.g. `bhanafee/RetryHTTP`)
3. **"description"** — Human-readable description for the POM and GitHub Pages title

If any argument is missing, ask the user before proceeding.

Derive the following from these inputs:
- **artifactId** — lowercase of ProjectName (e.g. `retryhttp`)
- **javaPackage** — `com.maybeitssquid.` + artifactId (e.g. `com.maybeitssquid.retryhttp`)
- **projectUrl** — `https://github.com/` + owner/repo
- **pageTitle** — the description argument (used verbatim in pandoc `--metadata title=`)
- **pagesUrl** — `https://` + owner + `.github.io/` + repo + `/` (e.g. `https://bhanafee.github.io/RetryHTTP/`)
- **year** — the current calendar year, used in the `LICENSE` copyright line (`date +%Y`)

## Step 1 — Validate the working directory

The working directory should be either empty or contain only `.git/`. If it contains
source files already, warn the user and ask whether to proceed.

## Step 2 — Copy static files

Read each skill file and write it to the target path. No placeholder substitution.
Create parent directories as needed.

| Skill file | Target path |
|---|---|
| `CLAUDE.md` | `CLAUDE.md` (points Claude Code at `@AGENTS.md`) |
| `CODE_OF_CONDUCT.md` | `CODE_OF_CONDUCT.md` |
| `gitignore` | `.gitignore` |
| `gitattributes` | `.gitattributes` |
| `gradle.properties` | `gradle.properties` |
| `gradle/libs.versions.toml` | `gradle/libs.versions.toml` |
| `github/dependabot.yml` | `.github/dependabot.yml` |
| `github/workflows/gradle.yml` | `.github/workflows/gradle.yml` |
| `github/workflows/gradle-publish.yml` | `.github/workflows/gradle-publish.yml` |
| `github/workflows/javadoc.yml` | `.github/workflows/javadoc.yml` |
| `pandoc/mermaid-init.html` | `.github/pandoc/mermaid-init.html` |
| `pandoc/mermaid.lua` | `.github/pandoc/mermaid.lua` |
| `pandoc/skylighting-paper-theme.css` | `.github/pandoc/skylighting-paper-theme.css` |
| `pandoc/strip-title.lua` | `.github/pandoc/strip-title.lua` |
| `pandoc/template.html5` | `.github/pandoc/template.html5` |
| `pandoc/theme.css` | `.github/pandoc/theme.css` |

## Step 3 — Write template files

Read each skill file, substitute all `{{placeholders}}`, and write to the target path.

| Skill file | Target path | Placeholders substituted |
|---|---|---|
| `LICENSE` | `LICENSE` | `{{year}}` |
| `settings.gradle` | `settings.gradle` | `{{ProjectName}}` |
| `build.gradle` | `build.gradle` | `{{ProjectName}}`, `{{artifactId}}`, `{{description}}`, `{{owner/repo}}`, `{{projectUrl}}` |
| `github/workflows/pages.yml` | `.github/workflows/pages.yml` | `{{pageTitle}}` |
| `AGENTS.md` | `AGENTS.md` | `{{description}}`, `{{artifactId}}`, `{{javaPackage}}` |

Keep the `// shared:begin` and `// shared:end` markers in `build.gradle` and `settings.gradle`. The `shared-build` job in `gradle.yml` checks them against `shared/` in this repo, so nothing else needs copying.

## Step 4 — Copy the Gradle wrapper

Copy the wrapper from a reference project. The reference project should be a sibling directory with an existing Gradle wrapper:

```bash
REFERENCE_PROJECT="${REFERENCE_PROJECT:-./../ASCIISafeCharsets}"
cp "$REFERENCE_PROJECT/gradlew" .
cp "$REFERENCE_PROJECT/gradlew.bat" .
mkdir -p gradle/wrapper
cp "$REFERENCE_PROJECT/gradle/wrapper/gradle-wrapper.jar" gradle/wrapper/
cp "$REFERENCE_PROJECT/gradle/wrapper/gradle-wrapper.properties" gradle/wrapper/
chmod +x gradlew
```

Set `REFERENCE_PROJECT` to the path of an existing Java/Gradle project if the default sibling directory does not exist.

`gradlew.bat` is copied as raw CRLF bytes and must be committed that way. `.gitattributes`
(Step 2) marks `*.bat -text`, so git stores it byte-for-byte. Do not change that to
`text eol=crlf`: Gradle generates `gradlew.bat` with CRLF and Dependabot's gradle-wrapper
updates commit it as-is, bypassing `.gitattributes`, so a normalizing rule makes every
wrapper bump leave `gradlew.bat` permanently "modified". The `line-endings` job in
`gradle.yml` fails CI if `gradlew` is not stored LF, if `gradlew.bat` is not stored CRLF,
or if any file stops matching `.gitattributes`.

## Step 5 — Create source directories

Create the Java package tree. Replace `.` with `/` in `{{javaPackage}}` to get
`{{packagePath}}` (e.g. `com/maybeitssquid/retryhttp`):

```bash
mkdir -p src/main/java/{{packagePath}}
mkdir -p src/test/java/{{packagePath}}
```

## Step 6 — Verify the build

```bash
./gradlew build
```

If the build fails, diagnose before reporting back. Common causes:
- `[libraries]` section must appear before `[bundles]` in the TOML file
- Catalog accessor is `libs.bundles.security.patches` (hyphens become dots)
- Spotless failure on generated files — run `./gradlew spotlessApply` first
- Version catalog namespace collision: if a plain key `foo` and a hyphenated key
  `foo-bar` coexist, Gradle promotes `foo` to a sub-accessor and `.get()` fails.
  The template avoids this by using `java` and `release` as separate top-level keys.

## Step 7 — Add the Technologies table and Links section to README

If `README.md` does not yet exist, create it with the `# ProjectName` title and description.

Every project README ends with a `## Technologies` table followed by a `## Links` section.
Add both at the end of `README.md`, substituting `{{pagesUrl}}` and `{{projectUrl}}`.
Remind the user to extend the Technologies table with any project-specific frameworks or
libraries.

```markdown
## Technologies

| Component | Version |
|-----------|---------|
| Java | 25 (toolchain; runs on 17+) |
| Gradle | 9.5.1 |
| JUnit | 6.1.0 |
| JaCoCo | 0.8.14 |

## Links

- [GitHub repository]({{projectUrl}})
- [Javadoc]({{pagesUrl}}javadoc/)
- [Test Results]({{pagesUrl}}tests/)
- [Coverage Report]({{pagesUrl}}coverage/)
- [Code of Conduct]({{pagesUrl}}CODE_OF_CONDUCT.html)
- [Claude Code Guidance]({{pagesUrl}}CLAUDE.html)
- [Agents guidance]({{pagesUrl}}AGENTS.html)

[![Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
```

## Step 8 — Report

Tell the user:
- Which files were created
- The artifact coordinates: `com.maybeitssquid:{{artifactId}}`
- That the `Architecture` section of `AGENTS.md` needs filling in
- That `LICENSE` (Apache 2.0) and `CODE_OF_CONDUCT.md` (Contributor Covenant 2.0) were
  created, and that `README.md` must exist before the GitHub Pages workflow will succeed
- That the `CODE_OF_CONDUCT.md` enforcement contact is `conduct@maybeitssquid.com`; change it if the project should use a project-specific address
- That the Technologies table at the bottom of `README.md` should be extended with any
  project-specific dependencies once they are added
- That the license is consistent across the project: the `LICENSE` file, the POM metadata
  in `build.gradle`, and the README license badge (in the Links section) all declare Apache License 2.0
- That `build.gradle` rejects prerelease versions when resolving the catalog's dynamic ranges.
  Without it, a range such as `slf4j = "2.+"` resolves to a prerelease (`2.1.0-alpha1`) and ships
  in the published POM. The filter matches known prerelease qualifiers (`alpha`, `beta`, `rc`,
  `cr`, `snapshot`, `preview`, `dev`, `milestone`, `M<n>`). Do not replace it with an allowlist of
  "stable-looking" versions: real stable releases carry odd suffixes — `0.0.20131108.vaadin1`,
  pulled in transitively by `spring-boot-starter-test`, and `2.3.1-b170201.1204` — and an
  allowlist rejects them, failing the build with "Could not find" rather than selecting a
  different version. Two limits worth stating: the rule covers project configurations only, so
  dynamic **plugin** versions (`spotless`, `owasp-dependencycheck`) are not filtered and should be
  pinned explicitly if that matters; and it excludes prereleases without pinning anything, so
  builds still are not reproducible. Dependency locking is the separate lever for that.
