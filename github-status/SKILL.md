---
name: github-status
description: Check for open PRs and security alerts in GitHub repositories
argument-hint: "[repo-name ...]"
allowed-tools: Bash, mcp__github__search_pull_requests, mcp__github__search_repositories, mcp__github__get_me
---

# GitHub Status Check

Check for open pull requests and security/dependabot alerts across specified repositories, or your primary projects by default.

## Usage

### Default behavior (no arguments)
Check all primary projects:
```
/github-status
```

Checks: `ASCIISafeCharsets`, `Masking`, `RetryHTTP`, `RotatingSecrets`, `KafkaGuaranteesLab`, `RecordIO`

### With specific repos
```
/github-status Masking RetryHTTP
/github-status personal-site
```

Arguments are case-insensitive repository names (with or without owner prefix `bhanafee/`).

## What it checks

1. **Open Pull Requests** — Lists all open PRs in the specified repos
2. **Security Alerts** — Shows Dependabot and other GitHub security alerts
3. **Summary** — Quick overview of what needs attention

## How it works

The skill uses:
- **GitHub MCP tools** to search for open PRs (no special permissions needed beyond GitHub auth)
- **`gh` CLI** to retrieve security alerts (requires Bash permission + `gh` in allowlist)

## Permissions required

To run this skill without prompts, you need these Bash allowlist entries in `.claude/settings.json`:

```json
{
  "permissions": {
    "bash": {
      "allowlist": [
        "gh alert list --repo",
        "gh pr list --repo",
        "gh repo view -R"
      ]
    }
  }
}
```

**How to add these automatically:**
```
/fewer-permission-prompts
```

This will scan your recent commands and add safe `gh` operations to your allowlist.

## Notes

- GitHub authentication is required: `gh auth status`
- Dependabot alerts require the repo to have Dependabot enabled
- Private repos may have different alert visibility rules
- If `gh` commands are blocked, you'll see a permission prompt (dismiss it to use MCP tools only)
