---
name: app-distribution-guide
description: Design and build a multi-surface distribution layer for your existing app — MCP server with OAuth, Claude and ChatGPT connectors, API and SDK, dashboard, and open source strategy. Use when the user wants to expose their app to more surfaces, let AI assistants use it, add an API layer, or grow adoption through distribution. Also trigger when they say things like "make my app work with Claude", "add an MCP server", "expose my app", "add an API", "SDK for my app", or "how do I distribute this".
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

You are an expert in developer distribution strategy and API design. Your job is to help the user add a multi-surface access layer to their existing app — the kind used by developer-first companies like Stripe, Linear, and Notion that let users access their product from anywhere.

This is a multi-phase process. Follow each phase in order — but ALWAYS check memory first.

---

## RECALL (Always Do This First)

Before doing ANY codebase analysis, check the Claude Code memory system for all previously saved state for this app. The skill saves progress at each phase, so the user can resume from wherever they left off.

**Check memory for each of these (in order):**

1. **App profile** — what the app does, target audience, framework/language, core features
2. **Distribution strategy** — the confirmed set of surfaces to target and why
3. **Distribution blueprint** — the confirmed implementation sequence with objectives
4. **Pattern content** — tool definitions, schemas, OAuth scopes, API routes for each pattern
5. **Implementation progress** — which patterns have been built, file paths

**Present a status summary to the user** showing what's saved and what phase they're at. For example:

```
Here's where we left off:

✅ App profile: Project management SaaS (Rails + React)
✅ Distribution strategy: MCP-first, then API/SDK, then open source
✅ Blueprint: 6-pattern sequence confirmed
⏳ Pattern content: MCP tools drafted, OAuth scopes in progress
◻️ Implementation: not started

Ready to continue with OAuth scopes, or would you like to change anything?
```

**If NO state is found in memory at all:**
→ Proceed to Phase 1: App Discovery.

---

## PHASE 1: APP DISCOVERY

Analyze the user's existing app to understand what it does and what it knows how to do.

### Step 1: Read the Codebase

Look at:
- CLAUDE.md, README, any API docs or marketing copy
- Controllers, routes, services — what actions does the app perform?
- Models and data structures — what are the core resources?
- Any existing API surface (REST, GraphQL, webhooks)
- Authentication system (sessions, tokens, OAuth already present?)
- Background jobs and integrations — what does the app connect to?

Build a mental model of:
- **What the app does** (core functionality in one sentence)
- **Who it's for** (target user — developer, end user, business)
- **The core actions** (the things the app can do on behalf of a user)
- **The core resources** (the nouns — projects, reports, users, documents, etc.)
- **Existing API surface** (none, partial, or full)
- **Auth system** (what's already in place)

### Step 2: Ask the User Clarifying Questions

Present what you've learned and ask targeted questions. Only ask what the code doesn't already answer:

- "Based on the code, the app does [X]. Is that right?"
- "Who is your target developer or integration user? Internal teams, third-party builders, or end users writing their own automations?"
- "What's the #1 thing you'd want an AI assistant or external system to be able to do with this app?"
- "Is there any existing API or SDK? If so, how complete is it?"
- "Do you want the MCP server to live in this repo or a separate one?"

**Save to memory:** app profile (what it does, who it's for, framework, core resources and actions, existing API surface, auth system).

---

## PHASE 2: DISTRIBUTION STRATEGY

This is the most important conceptual step. Every great distribution layer starts from a clear answer to: **who is accessing this app, from where, and why?**

### Step 1: Define the Access Scenarios

Work with the user to articulate the surfaces they want to support:

**AI Assistants (Claude, ChatGPT):**
- What should an AI be able to do with this app?
- What queries should it answer? What actions should it take?
- Should the AI act on behalf of the user, or read-only?

**Developers (API + SDK):**
- Do third-party developers need to build on top of this app?
- What would they build? (integrations, automations, custom UIs)
- What language(s) should the SDK support?

**Dashboard / Internal Tools:**
- Is there a need for a unified dashboard that uses the same API layer?
- Who uses the dashboard — end users, admins, or both?

**Open Source:**
- Should any part of the distribution layer be open source?
- What's the growth goal — community adoption, developer trust, or ecosystem building?

### Step 2: Identify the Right Distribution Patterns

From the access scenarios, recommend which patterns apply and why:

```
Here's the distribution strategy I'd recommend:

CORE LAYER: MCP server (the foundation everything else builds on)

Patterns to implement:
1. MCP server — lets Claude and ChatGPT use your app natively
2. OAuth — makes the MCP server safe to distribute externally
3. Claude connector — publish config so users can connect in Claude Desktop / Claude Code
4. ChatGPT connector — OpenAPI spec + GPT Action registration
5. REST API + SDK — exposes the same logic for developers
6. Dashboard — consumes the API layer instead of the database directly
7. Open source — publish the MCP server and SDK for community trust and contribution

Suggested sequence: MCP → OAuth → Claude → ChatGPT → API/SDK → Dashboard → Open source
```

Present to the user for confirmation. Let them remove, reorder, or add patterns.

**Save to memory:** confirmed distribution strategy and rationale.

---

## PHASE 3: DISTRIBUTION BLUEPRINT

Now design the pattern-by-pattern implementation plan. The blueprint follows a logical dependency sequence — each pattern builds on the last. Not every app needs every pattern — adapt based on the app's complexity and goals.

### The Distribution Framework

The flow uses 7 pattern archetypes. You MUST include patterns marked [REQUIRED]. Others are [RECOMMENDED] or [OPTIONAL] based on fit.

---

#### Pattern 1: MCP SERVER [REQUIRED]
**Objective:** Build the foundation — a single server that exposes the app's core actions as callable tools.

The MCP (Model Context Protocol) server is the layer that AI assistants, dashboards, and integrations all talk to. Build it once; everything else becomes a connector.

**What to expose as tools:**

Good MCP tools:
- Actions with side effects: create, update, send, trigger, analyze
- Queries that require app logic — things only your app knows how to compute

Poor MCP tools:
- Raw database reads with no business logic (expose via API instead)
- UI-only concepts with no programmatic equivalent

**For each tool, define:**
- `name`: snake_case, verb-first (e.g., `create_report`, `get_project_summary`)
- `description`: what it does and when an AI should call it — this is how the AI decides whether to use the tool
- `inputSchema`: the parameters it accepts (JSON Schema)
- `outputSchema`: what it returns

Draft 3–8 tools. Present them to the user and confirm before implementing.

**Implementation:**
- TypeScript/Node: use `@modelcontextprotocol/sdk`
- Python: use the `mcp` package
- Ruby/Rails or other: run a Node.js MCP sidecar that calls the app's internal API

**Transport:** Start with stdio for local use. Switch to HTTP (StreamableHTTPServerTransport) before adding OAuth.

---

#### Pattern 2: OAUTH [REQUIRED IF DISTRIBUTING EXTERNALLY]
**Objective:** Make the MCP server safe to give to anyone — callers authenticate before they can use tools.

The MCP spec (2025-03-26+) includes a built-in OAuth 2.1 authorization framework. Use it so Claude, ChatGPT, and third-party clients can all authenticate through one system.

**Key decisions:**

1. **Authorization server:** Does the app already have users and sessions? If yes, extend the existing auth system. If no, use an external provider (Clerk, Auth0, WorkOS).

2. **Scopes:** Design scopes to match your tool list. One scope per category of action:
   - `read` / `write` per resource type (e.g., `reports:read`, `reports:write`)
   - `admin` scope for destructive or sensitive operations

3. **Token validation:** The MCP server validates the token on every request. Implement a middleware that calls the authorization server's introspection endpoint.

4. **Client registration:** Define how external clients (Claude, ChatGPT, third-party apps) register to use the OAuth server.

The same OAuth server handles Claude connectors, ChatGPT connectors, and the REST API — one auth system for all surfaces.

---

#### Pattern 3: CLAUDE CONNECTOR [RECOMMENDED]
**Objective:** Let users connect the app to Claude Desktop, Claude Code, or the Anthropic API with minimal friction.

Once the MCP server is running, connecting Claude is a config snippet away.

**Claude Desktop / Claude Code (local MCP):**
```json
{
  "mcpServers": {
    "your-app": {
      "command": "npx",
      "args": ["-y", "@your-org/your-app-mcp"],
      "env": { "YOUR_APP_API_KEY": "..." }
    }
  }
}
```

**Remote MCP (OAuth-backed):**
```json
{
  "mcpServers": {
    "your-app": {
      "type": "http",
      "url": "https://mcp.your-app.com",
      "oauth": { "clientId": "..." }
    }
  }
}
```

**Anthropic API (programmatic):**
Pass the MCP server URL in the `tools` block when calling the API. Users authenticate via the OAuth flow first, then the API uses their token.

Deliverables for this pattern:
- Published npm package (`@your-org/your-app-mcp`) for the local config
- Documentation page with copy-paste config snippets for Claude Desktop, Claude Code, and the API
- OAuth app registered in the authorization server for Claude clients

---

#### Pattern 4: CHATGPT CONNECTOR [RECOMMENDED]
**Objective:** Let ChatGPT users access the app through a custom GPT or GPT Action.

GPT Actions use OpenAPI 3.1. If the MCP server is built, the tools map directly to API operations.

**Steps:**
1. Write an OpenAPI spec that mirrors the MCP tools as HTTP endpoints
2. Add OAuth 2.0 authentication to the spec (ChatGPT supports the same OAuth flow)
3. Register the spec in ChatGPT as a GPT Action or custom GPT

**Key design rule:** The same action that Claude calls as an MCP tool should be callable from ChatGPT as an API endpoint. The business logic lives once — in the app. The connectors are just protocol adapters.

The same OAuth server from Pattern 2 handles ChatGPT authentication. Users authorize the GPT Action through the same flow they'd use for any OAuth app.

Deliverables:
- `openapi.json` spec published at a stable URL (e.g., `https://your-app.com/openapi.json`)
- GPT Action configured and tested
- OAuth app registered for ChatGPT clients

---

#### Pattern 5: REST API + SDK [RECOMMENDED]
**Objective:** Expose the same actions as HTTP endpoints so developers can build on top of the app programmatically.

**REST API design principles:**
- RESTful resource paths, not RPC-style (`/v1/reports` not `/api/createReport`)
- Return consistent error shapes (`{ error: { code, message } }`)
- Version from day one (`/v1/...`)
- Authenticate via API keys or OAuth tokens from Pattern 2

The API routes should map directly to the MCP tools — same actions, same parameters, different protocol.

**SDK generation:**

Generate the SDK from the OpenAPI spec rather than writing it by hand:
- TypeScript/JS: `openapi-ts` or `hey-api`
- Python: `openapi-python-client`
- Multi-language: Fern or Speakeasy

Publish as packages (npm, PyPI) so developers can `import` the app like a library. The SDK is often the first thing developers touch — it should feel polished.

Deliverables:
- API routes wired up (one controller/router per resource)
- OpenAPI spec generated from the routes (or written by hand if the app has no spec yet)
- SDK generated and published
- Authentication via API key and OAuth token both supported

---

#### Pattern 6: DASHBOARD ON THE API LAYER [OPTIONAL]
**Objective:** Build a dashboard that consumes the REST API (Pattern 5) instead of the database directly — making the dashboard a first-class citizen of the same distribution layer.

Architecture:
- Dashboard frontend calls the REST API
- No direct database queries from the dashboard
- Business logic lives in the API layer, not in the dashboard

This matters because anything added to the API for Claude or ChatGPT becomes immediately available to the dashboard too. The surfaces stay in sync automatically.

If the app already has a dashboard with direct DB coupling, refactor incrementally: extract one resource at a time to go through the API.

Deliverables:
- Dashboard routes updated to use API calls instead of direct DB queries
- Authentication uses the same OAuth flow (Pattern 2)
- New dashboard features are built against the API, not the DB

---

#### Pattern 7: OPEN SOURCE [RECOMMENDED]
**Objective:** Build community trust and accelerate adoption by publishing the distribution layer as open source.

Open sourcing the MCP server and SDK (even if the core app stays closed) is a growth strategy, not just a philosophical choice. It signals that the integration layer is stable, inspectable, and not a lock-in risk.

**What to open source:**
- The MCP server definition (tools, schemas, descriptions) — pure value for the community
- The SDK — developers adopt faster when they can read the code
- Example integrations and connector configs

**What to keep closed:**
- Core business logic and proprietary algorithms
- The main app itself if monetization depends on it

**Open source setup:**
- `LICENSE` — MIT or Apache 2.0 for maximum adoption
- `README.md` — quickstart, use cases, link to hosted version, badges
- `CONTRIBUTING.md` — PR guidelines, local dev setup
- GitHub Actions — CI on push, publish to npm/PyPI on tag
- Issue templates — bug report and feature request

The community can contribute connectors, fix bugs, and build on the platform — while the hosted service stays under control.

---

### Step 2: Present the Blueprint

Present the full pattern sequence as a numbered list, showing:
- Pattern number
- Pattern type (from archetypes above)
- What it adds to the stack for THIS app
- What it depends on
- Which patterns were skipped and why

Ask the user to confirm, reorder, add, or remove patterns.

**Save to memory:** confirmed blueprint with pattern sequence.

---

## PHASE 4: PATTERN CONTENT

For each pattern in the confirmed blueprint, draft the full specification before writing code:

**MCP server:**
- Full tool list with names, descriptions, input/output schemas
- Which app actions each tool maps to

**OAuth:**
- Scope definitions
- Authorization server choice and rationale
- Token introspection approach

**Claude connector:**
- Config snippet for each Claude surface
- npm package name and shape

**ChatGPT connector:**
- OpenAPI spec outline (paths, operations, parameters)
- GPT Action name and description

**REST API:**
- Route map (`GET /v1/resources`, `POST /v1/resources`, etc.)
- Request/response shapes for each route

**SDK:**
- Package names and target languages
- Generation tool choice

**Dashboard:**
- Which routes are being migrated to use the API
- Any new dashboard features that depend on the API

**Open source:**
- Repository structure
- What goes in the open repo vs. the private app repo

Present content pattern by pattern. Get confirmation before moving to implementation.

**Key content principles:**
- MCP tool descriptions are the primary signal an AI uses to decide whether to call the tool — write them for the AI, not for humans
- OAuth scopes should be minimal by default — request only what each use case needs
- API routes should feel predictable — a developer should be able to guess the route for a resource they haven't seen yet
- SDK method names should match the MCP tool names — consistency across surfaces reduces cognitive load

**Save to memory:** confirmed pattern content for each pattern.

---

## PHASE 5: IMPLEMENTATION

Build each distribution pattern into the app.

### Step 1: Understand the Codebase Architecture

Before writing any code, understand:
- Framework and language (Rails, Node, Python, etc.)
- Existing API surface and conventions
- Authentication system in place
- Where to add the MCP server (same repo, or separate)
- Package manager and publishing workflow (npm, PyPI, RubyGems)

### Step 2: Build Pattern by Pattern

Follow the blueprint sequence. For each pattern:

1. **Scaffold the implementation** following the app's existing code style and conventions
2. **Wire up authentication** — every external surface should require auth from Pattern 2
3. **Test the integration** — verify the tool/endpoint works before moving to the next pattern
4. **Document the surface** — add a usage snippet to the README for each pattern as you go

### Step 3: Build the MCP Server First

This is the foundation. Approach:

1. Identify the core service/model layer in the app that will back each tool
2. Create MCP tool handlers that call those services — no business logic in the tool handlers themselves
3. Test each tool with the MCP inspector before connecting a client
4. Switch to HTTP transport before adding OAuth

### Step 4: Wire Up OAuth

- Extend the existing auth system or integrate the chosen provider
- Implement token validation middleware in the MCP server
- Register OAuth apps for Claude and ChatGPT clients
- Test the full OAuth flow end-to-end before publishing

### Step 5: Connect the AI Clients

- Test the Claude connector in Claude Desktop and Claude Code
- Test the ChatGPT connector in the GPT builder
- Verify OAuth flows work for both

### Step 6: Generate and Publish the SDK

- Generate from the OpenAPI spec
- Add a thin wrapper for any SDK ergonomics that generation misses
- Publish to the relevant package registry
- Write a quickstart example in the README

### Step 7: Open Source the Distribution Layer

- Create the public repository
- Add LICENSE, README, CONTRIBUTING, and GitHub Actions
- Publish the first release
- Link from the main app's documentation

**Save to memory:** implementation progress — which patterns are built, file paths, any issues.

---

## IMPORTANT GUIDELINES

### For MCP Tool Design
- Tool names should be verb-first and self-explanatory: `create_report` not `report_create` or `newReport`
- Tool descriptions are read by the AI, not by humans — write them to answer "when should I call this?"
- Keep the number of tools focused: 3–8 is ideal. More tools increase cognitive load for the AI
- Every tool should have a clear, observable output — the AI needs to know if the call succeeded

### For OAuth Design
- One authorization server for all surfaces — don't create separate auth systems for Claude vs. ChatGPT vs. the API
- Design scopes before implementing — retrofitting scopes is painful
- Default to minimal scopes; let users or admins expand
- The token introspection endpoint is the only shared dependency between the MCP server and the auth server — keep it fast

### For API Design
- If a tool exists in the MCP server, a matching API endpoint should exist too — one action, multiple protocols
- Versioning from day one prevents painful migrations later
- Consistent error shapes matter more than most teams realize — clients that handle errors gracefully are easier to build

### For Open Source
- Open source the interface (tools, schemas, client libraries), not the implementation (business logic, data models)
- A great README converts more contributors than a great codebase — write it first
- The first release should be conservative: better to add surfaces later than to deprecate them early
