# Playwright MCP for MCode

Wiring [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
into MiniMax Code so the agent gets real browser automation (CDP) as first-class
MCP tools: navigate, click, type, screenshot, evaluate JS — on arm64 Linux.

## Where MCP servers are configured

The MCode local runtime reads MCP server definitions from (first found wins):

- **Global**: `~/.minimax/mcp.json`
- **Project**: `.mcp.json` in the workspace root

Schema (from `packages/local-runtime-v2/src/service/mcp/` in the MCode source):
a top-level `mcpServers` object; each entry supports `command`/`args`/`env`
(stdio) or `url` (`http`/`sse`/`streamable-http`), plus `type`, `enabled`,
`timeout`, `description`. Server names: 1–80 chars of `[A-Za-z0-9_.-]`.

## Add Playwright MCP (stdio transport)

```bash
mkdir -p ~/.minimax
cat > ~/.minimax/mcp.json <<'EOF'
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "enabled": true
    }
  }
}
EOF
```

Project-only variant: the same JSON as `.mcp.json` in the repo root (never
commit one with credentials; the runtime rejects unsafe project configs).

Then restart the MCode session; the runtime validates the file on load. Verify
the server registered (it appears in the session's tool surface; errors like
`MCP_CONFIG_INVALID` / `MCP_SERVER_NOT_FOUND` come from the settings validator
and point at name/schema problems).

## arm64 prerequisite

Playwright MCP drives Playwright's browsers. On arm64 Linux:

```bash
npx playwright install chromium          # real arm64 Chromium + headless shell
```

Google's Chrome for Testing has no arm64 Linux build; the Playwright arm64
build is the supported path (see `../jev-ultrafast/README.md` for the snap
Chromium alternative when a headed desktop browser is required).

## Security notes

- Keep `enabled` explicit; disable the entry when not in use.
- Prefer `--allowed-hosts` (supported by the Playwright MCP CLI) to pin the
  server to expected origins in shared setups.
- Project `.mcp.json` files from untrusted repos should be reviewed before
  enabling — they can define arbitrary stdio commands.
