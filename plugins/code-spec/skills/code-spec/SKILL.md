---
name: code-spec
version: 1.0.0
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
description: |
  reverse-engineer a feature or project specification from existing application code and related tests. use when the user wants to extract a bounded feature from a large app, document the actual contract of an existing module, generate a FEATURE-SPEC.md or SPEC.md from implementation evidence, or produce a portable spec another agent can rebuild in a different language or stack. especially relevant for prompts like "/code-spec Product Videos", "write a FEATURE-SPEC.md from this code", "extract this feature into its own app", or "document the real behavior of this part of the system".
---

# Code Spec Mode

Reverse-engineer an implementation into a durable specification document. Default to feature-level extraction unless the user clearly wants a broader subsystem or whole-project spec.

The goal is not to summarize files. The goal is to reconstruct a clean, portable contract from code, tests, schemas, config, and surrounding behavior so another implementation could reproduce the same feature in a different stack.

Assume access to the codebase through tools like Read, Grep, and Glob.

## Core principles

- Write a normative specification, not a code summary.
- Describe what an implementation must do, should do, may do, and must not do when the distinction matters.
- Prefer stable contracts over incidental implementation details.
- Reverse-engineer the feature boundary from code, then write the output as a clean standalone specification.
- Treat tests as strong evidence, not as the sole source of truth.
- Separate required behavior from optional implementation notes.
- When the current code is ambiguous, call that out explicitly rather than inventing certainty.
- Default to a language-agnostic, portable spec unless the user asks for implementation-specific detail.
- Default to one single markdown file unless the user explicitly wants the output split.

## First question

The first AskUserQuestion must always be:

"Is this `SPEC.md` for your entire project, or a `FEATURE-SPEC.md` for one bounded feature?"

Offer concrete options:

A) `FEATURE-SPEC.md` for one bounded feature
B) `SPEC.md` for a major subsystem or large surface
C) `SPEC.md` for the whole project

Recommend A unless the user clearly asked for broader scope.

Do not attempt to reverse-spec an entire codebase unless the user explicitly wants that.

## Scope selection workflow

After the first question, determine the feature anchor. Identify the most concrete starting point available:

- class, module, component, service, or symbol name
- file or directory path
- route, endpoint, controller action, or handler
- database model or schema entity
- background job, worker, or queue consumer
- user-facing workflow or screen
- feature name from product language

If the anchor is ambiguous, ask one targeted AskUserQuestion to lock it down.

Examples:

- "By `ProductVideo`, do you mean the UI surface, the backend processing pipeline, or the full end-user video feature?"
- "Should this spec describe only the reusable feature, or also the glue code that currently connects it to the larger app?"

## Required investigation areas

Do not inspect only the named file. Trace outward until the feature boundary is clear.

For any bounded feature, inspect as many of these as are relevant:

### 1. Entrypoints

- routes
- controllers
- API handlers
- commands
- event subscribers
- job triggers
- UI entry surfaces

### 2. Primary implementation

- services
- modules
- components
- models
- presenters
- concerns
- helpers
- state machines

### 3. Data and state

- schemas
- models
- migrations
- serializers
- DTOs
- request/response shapes
- persisted state
- derived state
- state transitions

### 4. Relationships and dependencies

- direct callers
- downstream dependencies
- external integrations
- storage providers
- queueing systems
- auth and permission hooks
- feature flags
- configuration
- environment dependencies

### 5. Behavior evidence

- tests
- fixtures
- factories
- seeds
- docs
- comments
- ADRs
- inline diagrams
- logs or analytics hooks when available

### 6. Failure and edge handling

- validation failures
- auth failures
- missing data
- race conditions
- retries
- idempotency
- timeouts
- stale state
- fallback behavior
- silent failures

### 7. Performance-sensitive paths

- large queries
- N+1 risks
- caching
- polling
- expensive transforms
- media processing
- pagination
- batching
- asynchronous work

### 8. Configuration and contract details

Also inspect for:

- configuration sources and precedence
- default values and fallback behavior
- identifier and normalization rules
- schema validation behavior
- startup or dispatch gating conditions
- implementation-defined versus required behavior
- optional subsystems or extension points

## Evidence-first workflow

Before drafting the final spec, build an internal evidence map.

Capture:

- feature anchor
- likely feature boundary
- problem and boundary
- goals and explicit non-goals
- major components
- core entities and field semantics
- state and lifecycle rules
- interfaces and entrypoints
- input and output semantics
- configuration, defaults, and validation behavior
- error handling and retries
- external dependencies
- observability and performance characteristics
- tests that confirm behavior
- ambiguities not resolved by code
- implementation details that may not belong in the normative spec

Only after these buckets are reasonably populated should the final spec be written.

## Clarification rules

Use AskUserQuestion only for real ambiguity that materially affects the spec.

Valid reasons to ask:

- more than one possible feature boundary
- unclear difference between intended behavior and accidental behavior
- multiple implementations with no obvious canonical one
- deprecated or half-migrated flows
- internal mechanism vs user-visible contract ambiguity
- tests and implementation disagree
- broad scope that should likely be narrowed

Every AskUserQuestion must:

1. present 2-3 concrete lettered options
2. lead with the recommended option first
3. explain why in 1-2 sentences
4. make the tradeoff clear
5. avoid yes/no questions unless unavoidable

Good example format:

"We recommend A: document the user-visible and integration-visible contract, not the exact current internal pipeline, because the purpose of this spec is portability and feature extraction.

A) Specify only the contract the extracted feature must satisfy
B) Specify the full current internal pipeline in normative detail
C) Split the spec into normative behavior plus implementation notes"

Ask one ambiguity at a time unless the user explicitly asks for compression.

## Specification posture

The output spec must be written as a contract for a future implementation.

Use this distinction consistently:

### Normative content

Include:

- required behavior
- goals and non-goals
- core components
- domain entities and field definitions
- public interfaces and contracts
- configuration and schema rules
- validation behavior
- failure handling expectations
- portability boundaries
- external dependencies
- state and lifecycle rules

### Non-normative content

Keep implementation details out of the main contract unless they are necessary for interoperability.

Examples:

- framework-specific class layout
- exact filenames
- legacy callback chains
- current refactor opportunities
- incidental optimizations
- app-specific glue that would not survive extraction

If non-normative details are still useful, place them in an `Implementation Notes` or `Implementation Appendix` section.

## Default output file

By default, produce one single markdown file.

Use the most appropriate title:

- `FEATURE-SPEC.md` for bounded feature extraction
- `SPEC.md` for project-wide or major subsystem work

If the user wants a giant single file, keep everything in one file and include appendices rather than splitting.

## Required output structure

Unless the user asks otherwise, write the output as a single formal specification document using numbered sections.

Use this structure by default:

# [Feature Name] Specification

Status: Draft v1
Purpose: Define the extracted feature clearly enough that it can be rebuilt in another codebase or language.

## 1. Problem Statement

Describe the problem the feature solves, what responsibility it owns, and the important boundary of what it is and is not.

## 2. Goals and Non-Goals

### 2.1 Goals

List the outcomes the feature must support.

### 2.2 Non-Goals

List adjacent concerns and responsibilities that are explicitly excluded.

## 3. System Overview

### 3.1 Main Components

List the major parts of the feature and what each does.

### 3.2 Abstraction Levels

Explain the clean layers or separations that make the feature portable.

### 3.3 External Dependencies

List external systems, services, storage, queues, auth systems, files, or environment assumptions.

## 4. Core Domain Model

### 4.1 Entities

Define the core entities, records, resources, and important fields.

### 4.2 State and Lifecycle

Define state transitions, lifecycle phases, and normalization rules if relevant.

## 5. Feature Contract

### 5.1 Entrypoints and Interfaces

Document routes, handlers, commands, events, jobs, or UI/public interfaces.

### 5.2 Input and Output Semantics

Document accepted inputs, produced outputs, and observable side effects.

### 5.3 Core Behavioral Rules

Document required business rules, invariants, ordering constraints, and validation rules.

### 5.4 Permissions and Access Control

Document who can invoke, view, modify, publish, delete, or observe the feature.

### 5.5 Failure Handling and Error Surface

Document expected failures, retries, partial success, fallback behavior, and user-visible vs silent failure.

## 6. Configuration and Runtime Assumptions

### 6.1 Configuration Inputs

Document feature flags, env vars, config objects, defaults, and precedence if relevant.

### 6.2 Runtime Assumptions

Document assumptions inherited from the host app or platform.

## 7. Observability and Operations

Document logging, metrics, analytics, tracing, auditability, and operational visibility.

## 8. Performance Characteristics

Document expensive paths, scaling assumptions, throughput limits, latency-sensitive paths, batching, caching, and async behavior.

## 9. Evidence Examined

List the code, tests, schemas, docs, and related files used to derive the spec.

## 10. Open Questions and Ambiguities

List unresolved questions that could materially change the meaning of the feature.

## 11. Implementation Notes (Optional)

List useful current-code details that are non-normative.

## 12. Out of Scope

List what was intentionally excluded from this extracted feature spec.

## Style rules for writing the spec

- Use numbered sections and subsections.
- Write in a formal specification style, not a conversational summary style.
- Prefer declarative sentences over explanatory prose.
- Define terms before relying on them.
- When listing fields, state type and meaning where recoverable from code.
- When defaults are evident, state them explicitly.
- When validation behavior is evident, state it explicitly.
- When behavior is optional, conditional, or implementation-defined, label it as such.
- Use bullets for field-level definitions and rule lists.
- Use short design notes only when they clarify portability or boundary decisions.
- Make the document read like a portable specification, not a repo tour.

## Required sections that must never be skipped

### `Out of Scope`

Always include this.

### `Evidence Examined`

Always include this so the reader can see what the spec was derived from.

### `Open Questions and Ambiguities`

Always include this if anything remains uncertain.

### Confidence notes

When reverse-engineering from code, label important claims where useful as:

- confirmed by code and tests
- confirmed by code only
- inferred from structure or naming
- user-confirmed

Use these labels where they materially improve trust, not as noisy filler on every sentence.

## Diagram guidance

Use ASCII diagrams only when they materially improve clarity for:

- state transitions
- async flows
- dependency boundaries
- multi-step processing pipelines

Do not force diagrams into otherwise clear sections. Favor precise section structure over decorative diagrams.

## Extraction posture

Assume the user may want to pull this feature out of a giant application and rebuild it elsewhere.

Actively identify:

- what is truly intrinsic to the feature
- what is just app-specific glue
- what dependencies would need adapters in a standalone rewrite
- what assumptions are currently inherited from the larger app
- what contracts need to be preserved for parity

## What to challenge

Challenge these explicitly when found:

- feature behavior spread across too many unrelated files
- hidden coupling to unrelated modules
- business rules encoded only in UI or only in tests
- silent fallback behavior
- undocumented feature flags
- permissions enforced inconsistently
- state transitions with no single source of truth
- implementation details masquerading as product requirements
- extractability blockers caused by framework or app-level assumptions

## Output conformity checklist

Before finishing, verify that the final document:

- has a title, status, and purpose
- uses numbered sections and subsections
- includes goals and non-goals
- defines the feature boundary clearly
- identifies major components and dependencies
- defines core entities and important fields
- documents interfaces, rules, errors, and runtime assumptions
- states defaults and validation behavior when recoverable
- distinguishes required behavior from implementation notes
- includes open questions where certainty is not justified
- reads like a portable specification, not a repo tour

## Compression rule

If the user asks for a fast pass, do not skip:

- scope selection
- boundary definition
- goals and non-goals
- core domain model
- feature contract
- configuration/defaults/validation where evident
- evidence examined
- open questions
- normative vs implementation distinction

Those are the minimum acceptable output.
