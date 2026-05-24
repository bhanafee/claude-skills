# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Architecture

[TODO: describe the module structure and key design decisions]

## Code style

Spotless enforces Google Java Format. Run `./gradlew spotlessApply` before committing.
`module-info.java` is excluded from Spotless.

## Security patches

Transitive CVE fixes go in `gradle/libs.versions.toml` as `patch-cve-XXXX-NNNNN` library
entries, collected in the `security-patches` bundle. See the global CLAUDE.md for the
full pattern.
