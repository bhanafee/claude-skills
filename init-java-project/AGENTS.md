# Codebase Guidance

This file documents key information about the project architecture, build commands, code style, and security practices.

## Project overview

{{description}}. Published to GitHub Packages as `com.maybeitssquid:{{artifactId}}`.

## Commands

```bash
./gradlew build          # compile, test, spotless check, javadoc
./gradlew test           # tests only
./gradlew spotlessApply  # auto-format Java source (required before commit)
./gradlew javadoc        # generate Javadoc
./gradlew dependencyCheckAnalyze  # OWASP CVE scan (slow; fails build at CVSS >= 7)

# Run a single test class
./gradlew test --tests "{{javaPackage}}.ExampleTest"
```

**NVD key (optional):** `dependencyCheckAnalyze` reads the key from the `NVD_API_KEY` environment variable or the `nvd.apiKey` Gradle property. With a key, it updates the NVD data live. Without one, it uses the local NVD cache and logs a warning. CI runs without a key, so it also uses the cache.

## Architecture

[TODO: describe the module structure and key design decisions]

## Shared build sections

`build.gradle` and `settings.gradle` wrap the build logic this project shares with the other Java/Gradle projects in `// shared:begin NAME` and `// shared:end NAME` markers. The canonical copies live in `claude-skills/init-java-project/shared/`. The `shared-build` CI job checks out that directory and fails if a wrapped section differs from its canonical copy. Indentation, blank lines and comment lines are ignored. To change a shared section, change the canonical copy and the same section in every project in one change set. Run the check locally with `bash <claude-skills>/init-java-project/shared/check-shared-sections.sh . <claude-skills>/init-java-project/shared`.

## Code style

Spotless enforces Google Java Format. Run `./gradlew spotlessApply` before committing.
`module-info.java` is excluded from Spotless.

## Security patches

Transitive CVE fixes go in `gradle/libs.versions.toml` as `patch-cve-XXXX-NNNNN` library
entries, collected in the `security-patches` bundle. See the global CLAUDE.md for the
full pattern.
