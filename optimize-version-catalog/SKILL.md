Examine the gradle/libs.versions.toml, build.gradle, and gradle.properties in this project.

## Baseline dependency snapshot

Run `./gradlew dependencies --configuration compileClasspath` and again for
`testCompileClasspath` to capture the resolved tree before making any changes.
Note: `--configuration` only accepts one value at a time; run configurations
separately. Save the output to diff against after changes.

Run `./gradlew buildEnvironment` to capture the plugin/buildscript classpath.
Cross-reference each security patch module against both outputs:

- If the module appears in the project dependency tree and is being upgraded by
  the constraint, the patch is load-bearing — keep it.
- If the module appears ONLY in the plugin classpath (buildEnvironment), emit a
  warning: "⚠ patch-cve-XXXX only affects the plugin classpath. Project-level
  implementation constraints do not reach buildscript dependencies."
- If the module appears as a top-level direct dependency in buildEnvironment at
  or above the floor version (e.g. `+--- org.bouncycastle:bcprov-jdk18on:1.84`),
  the plugin itself is already pinning that version. Note this: the constraint
  is doubly redundant for the current build, but kept as defense-in-depth.
- If the module appears only as a transitive dependency in buildEnvironment (not
  at the top level), the project-level constraint still cannot reach it. Note
  the resolved version and whether it already satisfies the floor. The
  constraint is ineffective regardless of resolved version — the warning and
  `buildscript { resolutionStrategy }` suggestion still apply.
- For patches that are plugin-classpath-only, suggest adding a
  `buildscript { configurations.classpath.resolutionStrategy { ... } }` block
  as the correct mechanism to enforce floor versions there.

## Catalog structure

Reorder the version catalog sections into the canonical order: versions, then
libraries, then bundles, then plugins. Group version entries by usage: java
toolchain, plugin versions, testing, logging, security patches, and any other
useful groupings. Add a comment to each grouping.

## Remove unnecessary entries

Remove constraints that no longer affect the build. Dependabot sometimes adds
multiple entries for the same module (one per CVE) or forces a version that is
already superseded by a newer override. Only the highest floor is needed.

Use open-range version constraints for security patches so they enforce a
minimum floor without preventing upgrades:
  `version = { strictly = "[1.84,)", prefer = "1.84" }`
The `strictly` range `[X.Y,)` allows any version at or above the floor.
`prefer` selects the floor when no other constraint forces a higher version;
it does not downgrade — conflict resolution always picks the highest satisfying
version.

## Detect unused catalog entries

Compare every catalog key against `libs.*` references in all build.gradle files.
Use a script (Python or similar) rather than manual grep, since keys use hyphens
in TOML but dots in Gradle references. Check:

- versions: direct use as `libs.versions.<key>.get()` OR indirect use via
  `version.ref = "<key>"` in a library entry
- libraries: direct use as `libs.<key>` in any build.gradle OR membership in a
  used bundle
- bundles: use as `libs.bundles.<key>` in any build.gradle
- plugins: use as `libs.plugins.<key>` in any build.gradle

Remove any entry not reachable by the above. For multi-module projects, search every
`build.gradle` file in the tree — subproject files are valid consumers of catalog
entries and must not be treated as unused just because the root `build.gradle` does
not reference them.

## Add useful bundles

Scan all build.gradle files for groups of catalog libraries declared under the
same configuration that are always added together. A bundle is worth creating
when 3 or more libraries consistently appear as a unit — it reduces declaration
noise and makes intent clearer.

**Identifying candidates**

For each Gradle configuration (`implementation`, `testImplementation`,
`runtimeOnly`, etc.), collect the catalog library references declared under it.
Look for clusters that represent a coherent functional role. Common patterns:

- **Test suite** — JUnit Jupiter + Mockito + AssertJ + Spring Boot test starter
  always land in `testImplementation` together; a `testing` or `test-suite`
  bundle replaces four lines with one.
- **Spring starters** — two or more Spring Boot / Spring Cloud starters that
  always ship together (e.g., web + validation, data-jpa + flyway, vault-config
  + circuitbreaker).
- **Observability** — Micrometer core + actuator + tracing bridge.
- **Database layer** — JPA starter + a migration tool (Flyway or Liquibase).
  Note: driver and connection-pool entries are often `runtimeOnly` while the
  starter is `implementation`; do not mix scopes in the same bundle (see below).
- **Security** — Spring Security + OAuth2 resource server.

**Rules for well-formed bundles**

1. All members must share the same Gradle configuration scope. A bundle used
   as `implementation libs.bundles.foo` puts every member on the compile
   classpath. If one member should be `runtimeOnly`, keep it outside the bundle.
2. Do not bundle a BOM import (`platform(...)` / `enforcedPlatform(...)`). BOMs
   belong in `dependencyManagement` or as a `platform` dependency, not in a
   library bundle.
3. Do not create a single-entry bundle; it adds indirection with no benefit.
4. Name bundles by functional role (`test-suite`, `spring-data`, `observability`),
   not by technical origin (`spring-boot-stuff`). The name should answer
   "what does this enable?" not "where does it come from?".

**Implementation**

For each bundle you create:
1. Add the entry to `[bundles]` in the catalog.
2. Replace the individual `libs.<key>` lines in build.gradle with
   `libs.bundles.<name>`.
3. Confirm in the unused-entry check (run the detection script again) that all
   bundled library keys are still reachable via bundle membership.

## Parameterize build.gradle

Ensure the Java toolchain version comes from the catalog:
  `JavaLanguageVersion.of(libs.versions.java.get())`

In multi-module projects (those using `subprojects {}` or `allprojects {}`), Gradle
may require the `.asProvider()` form to avoid a naming collision:
  `JavaLanguageVersion.of(libs.versions.java.asProvider().get())`
Accept whichever form is already in the file — do not replace `asProvider().get()`
with `.get()` in a multi-module context.

Update any hardcoded Java version strings in javadoc link URLs to use the same
catalog value:
  `"https://docs.oracle.com/en/java/javase/${libs.versions.java.get()}/docs/api/"`
(or the `asProvider()` variant, matching whichever form is used in the same file).

After parameterizing, verify the interpolated URL is reachable (HTTP 200).

## Verify CI toolchain alignment

After the catalog has a `java` version entry, check that every other place in
the repo that pins a Java version agrees with it. Drift here is silent: the
build compiles under one JDK while CI or local tooling uses another.

Read the catalog's `java` version, then scan:

- `.java-version` — used by jEnv and asdf java plugin
- `.tool-versions` — used by asdf/mise; look for a line starting with `java`
- `.sdkmanrc` — used by SDKMAN; look for a line starting with `java=`
- `.github/workflows/*.yml` — look for `java-version:` fields under any
  `actions/setup-java` step
- `Dockerfile` and `.devcontainer/devcontainer.json` — look for `FROM
  eclipse-temurin:NN`, `FROM amazoncorretto:NN`, `FROM openjdk:NN`, or
  `"javaVersion"` fields

For workflow files, distinguish between two legitimate patterns:
- A **matrix strategy** (`matrix.java-version: [17, 21, 25]`) is intentional
  compatibility testing across versions — not a mismatch. Report the full matrix
  range but do not flag it as a warning.
- A **hardcoded version** (`java-version: '21'`) in a publish, release, or pages
  workflow should match the catalog's `java` version.

For each file found, extract the declared version and compare its major version
to the catalog value. Report a table:

```
File                                    Declared      Match?
.github/workflows/gradle.yml (matrix)   [17, 21, 25]  ✓ (compatibility matrix)
.github/workflows/gradle-publish.yml    21            ✓
.java-version                           17            ✗  <-- mismatch
```

Flag hardcoded mismatches as warnings and suggest updating to match the catalog.
If no CI or tooling files exist, note that and suggest adding a `.java-version`
file so local tooling stays in sync.

## After changes

Re-run `./gradlew dependencies` for each configuration checked in the baseline
and confirm the resolved versions are identical. Then run `./gradlew build` or
`./gradlew test` to confirm nothing is broken.

## Suggest optimizations

Report any remaining optimization opportunities for version catalog management,
including whether patches should be moved to the buildscript classpath.

## Suggest improvements to this skill
