---
name: github-status
description: Check for open PRs and security alerts in GitHub repositories
argument-hint: "[repo-name ...]"
allowed-tools: Bash
---

# GitHub Status Check

Check open pull requests and security alerts across specified repositories, or the primary projects by default.

## Usage

### Default behavior (no arguments)
```
/github-status
```

Checks the primary projects from the CLAUDE.md project table (owner `bhanafee`):
`ASCIISafeCharsets`, `Masking`, `RetryHTTP`, `RotatingSecrets`, `KafkaGuaranteesLab`, `RecordIO`

### With specific repos
```
/github-status Masking RetryHTTP
/github-status bhanafee/RecordIO
/github-status someowner/somerepo
```

Arguments are case-insensitive repository names. A bare name means `bhanafee/<name>`. Use `owner/repo` for repos under another owner.

## What it checks

For each repo, run these with `gh` (no MCP tools):

1. **Open pull requests**
   `gh pr list --repo <owner>/<repo> --state open --json number,title,author,createdAt,isDraft`
2. **Dependabot alerts**
   `gh api "repos/<owner>/<repo>/dependabot/alerts?state=open&per_page=100"`
   Report severity, package, GHSA id, summary, and first patched version.
3. **Code scanning and secret scanning** (optional, same pattern):
   `gh api "repos/<owner>/<repo>/code-scanning/alerts?state=open&per_page=100"`
   `gh api "repos/<owner>/<repo>/secret-scanning/alerts?state=open&per_page=100"`
   A 403 or 404 means the feature is not enabled for that repo. Report it as "not enabled", not as an error.

## Output

Print one line per repo, every time, even when the count is zero:

```
Masking: 0 PRs, 0 Dependabot alerts
RecordIO: 1 PR, 2 Dependabot alerts (1 high)
```

If a query fails for any other reason, print `<repo>: ERROR (<gh message>)` and continue with the other repos. Never leave a repo out of the output.

Finish with a summary listing only the repos that need attention. If nothing does, say so.

## Permissions required

Add these entries to the `permissions.allow` list in `.claude/settings.json` (or the user settings) so the skill runs without prompts:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh pr list:*)",
      "Bash(gh repo view:*)",
      "Bash(gh api repos/*/dependabot/alerts*)",
      "Bash(gh api repos/*/code-scanning/alerts*)",
      "Bash(gh api repos/*/secret-scanning/alerts*)"
    ]
  }
}
```

Use `/fewer-permission-prompts` or the `update-config` skill to add them automatically.

## Notes

- Authentication: `gh auth status` must show a logged-in account with read access to the repos.
- Dependabot alerts require Dependabot to be enabled on the repo. A 403 on that endpoint usually means the token lacks the `security_events` or Dependabot read scope, or the feature is off.
- Private repos may have different alert visibility rules.
- If a `gh` command is blocked by a permission prompt, add its pattern to the allowlist above rather than falling back to another tool.
