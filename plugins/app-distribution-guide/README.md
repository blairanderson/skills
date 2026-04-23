# App Distribution Guide Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install app-distribution-guide@blairanderson-skills
```

This plugin adds one skill for building a multi-surface distribution layer on top of an existing app.

---

## `/app-distribution-guide`

Design and build a multi-surface access layer — MCP server with OAuth, Claude and ChatGPT connectors, REST API and SDK, dashboard, and open source strategy.

Walks through the full distribution stack in phases:

1. **Recall** — checks memory for previously saved progress and resumes from the last phase
2. **App Discovery** — reads the codebase to understand what the app does, its core resources and actions, and existing API surface
3. **Distribution Strategy** — defines which surfaces to support (AI assistants, developers, dashboard, open source) and confirms the pattern sequence
4. **Distribution Blueprint** — designs the implementation plan using 7 pattern archetypes: MCP Server, OAuth, Claude Connector, ChatGPT Connector, REST API + SDK, Dashboard, and Open Source
5. **Pattern Content** — drafts full specifications for each pattern (tool definitions, OAuth scopes, OpenAPI spec, SDK targets) before any code is written
6. **Implementation** — builds each pattern into the app following the confirmed blueprint, pattern by pattern

Trigger phrases: "make my app work with Claude", "add an MCP server", "expose my app", "add an API", "SDK for my app", or "how do I distribute this".
