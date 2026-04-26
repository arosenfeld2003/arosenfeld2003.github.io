---
title: "AgentX: Designing a Self-Hosted, Email-Triggered AI Agent"
date: 2026-04-26T09:00:00-08:00
draft: false
tags: ["ai", "agents", "self-hosted", "ralph-wiggum", "vps", "fediverse", "claude"]
category: "technical"
summary: "From blank directory to a scaffolded autonomous agent project — designing an email-triggered AI harness on a Hostinger VPS using the Ralph Wiggum methodology, with a path from Claude API to local Qwen3 models."
---

I'm finally taking the plunge — I'm building my own agent harness to experiment with locally hosted LLMs on a VPS. I chose a Hostinger VPS with 16 GB RAM and 4 CPU cores because it seems we've reached a point where this is a potentially workable setup to run high quality open source models with quantization.

I'm building my own harness because... control, learning, power! The goal of all of this is to learn and grow and understand the new paradigm of agents — how to use them effectively, safely, affordably, responsibly, reliably, and with purpose.

To start, I'm using a local Ralph loop workflow to build the custom harness that will eventually run on the VPS and drive a loop flow using open source models. Looking forward to working on this project and sharing more here on my efforts.

## What Got Built Today

This session started with a blank directory and ended with two new git repos, a deployed GitHub remote, and a detailed architectural spec for something genuinely ambitious: a self-hosted autonomous agent that wakes up when you send it an email.

### The Ideas Repo

The first thing created was `/Users/alexrosenfeld/ideas` — a personal scratchpad repo for freewriting, specs, and stream-of-consciousness thinking across a few domains:

- **VPS agent experiments** — self-hosted AI on a Hostinger KVM VPS
- **Fediverse community platform** — a local-first Facebook alternative on ActivityPub
- **Consultancy and side projects**

The framing matters: this isn't a polished project repo, it's a thinking space. The README says so explicitly. The discipline of having a place for half-baked thoughts — and committing them to git — is its own kind of useful.

### Upgrading the VPS

Mid-session, a real infrastructure decision got made: upgrade a Hostinger KVM 2 (8 GB RAM) to KVM 4 (16 GB RAM, 4 vCPU, 200 GB NVMe) for $74.21 prorated. The reason was concrete — the target model, Qwen3-35B at 3-bit quantization, needs ~14–15 GB just to load, which leaves the 8 GB plan completely out of contention.

The 16 GB plan opens up a more practical starting point: **Qwen3-14B Q4_K_M at ~9 GB** — comfortable headroom, strong capability, proven quantization format.

The cost controls were documented directly in `vps-agent.md` as a living table, with an explicit north star: *eventually, the agent manages its own cost controls*.

### The NemoClaw Question

Hostinger offers a pre-installed NVIDIA NemoClaw template for AI workloads. The question of whether to use it or build a custom harness got real consideration — and the answer came out clearly in favor of custom:

| Dimension | NemoClaw | Custom Harness |
|---|---|---|
| Setup time | Minutes | Days–weeks |
| Learning value | Low | High |
| Security control | Opaque | Explicit |
| Model flexibility | Unknown | Full |
| Multi-model routing | Unknown | First-class |

NemoClaw is worth studying as a reference. It's not a foundation to build on when the explicit goals are learning, security understanding, and eventual self-management.

### The AgentX Spec

The core design that emerged: an agent awakened by email.

```
User sends email to agentx@rubggp.com
  └─ Attachment or body: spec/task markdown
       └─ IMAP listener on VPS detects new message
            └─ Extracts spec, writes to workspace/TASK.md
                 └─ Triggers Ralph loop
                      └─ Agent works, commits to branch
                           └─ Reply email: summary, branch name, diff link
```

This is elegant for a few reasons. Email is asynchronous — you can send a task and walk away. It's human-readable at every step. The spec file format is just markdown. And the control surface extends naturally: `[task]`, `[stop]`, `[status]` subject prefixes give you out-of-band control without needing to SSH in.

### The Ralph Wiggum Foundation

The build isn't starting from scratch — it's standing on the existing `ralph-docker` repo, which implements the Ralph Wiggum autonomous development methodology:

- Each loop iteration: read disk state → call model → dispatch tools → commit → exit
- Fresh context per iteration (resumable if the container crashes)
- Git branch isolation — agent never touches `main`
- Hard error detection — spending caps, auth failures, rate limits all stop the loop

The refactor is moving this from "Docker on a dev machine" to "persistent container on the VPS." The execution environment moves; the loop logic stays mostly intact.

### The AgentX Repo

The session ended with `github.com/arosenfeld2003/agentx` initialized, pushed, and scaffolded with the Ralph Wiggum project structure:

```
agentx/
├── AGENTS.md               — project goal, stack, VPS specs
├── IMPLEMENTATION_PLAN.md  — empty, ready for planning loop
├── PROMPT_plan.md          — planning instructions (model-agnostic)
├── PROMPT_build.md         — build instructions
├── ralph.sh                — thin wrapper, delegates to ralph-docker
└── specs/
    └── agent-harness.md    — full architectural spec
```

One notable design decision in the prompts: subagent scaling is proportional to the codebase, not fixed:

> *Spawn only as many parallel subagents as there are distinct files or components to examine — never spawn subagents for work that can be done in a single pass.*

This scales naturally as the project grows without needing prompt updates.

### The Bootstrapping Paradox

There's a clean narrative arc built into the project design:

```
Phase 0: Claude Code (this session) builds and deploys the harness
Phase 1+: Agent receives spec emails and builds its own improvements
```

The agent can't build itself before it exists. So Phase 0 is done by Claude Code directly — then the handoff happens and the agent takes over its own evolution.

### Model Progression Plan

| Phase | Backend | Model | RAM use |
|---|---|---|---|
| 1 | Claude API | Sonnet 4.6 / Opus 4.7 | minimal |
| 2 | Ollama | Qwen3-14B Q4_K_M | ~9 GB |
| 2+ | Ollama | Qwen3-32B Q3_K_M | ~13 GB |
| ongoing | Router | task-dependent | varies |

The multi-model router — `model_router(task_type) -> model_id` — is designed in from the start, not retrofitted. Fast cheap tasks go to small local models; planning and architecture go to the strongest available model.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What struck me most about this session is that it was primarily *design work* that happened to produce code artifacts. The git commits are almost incidental — the real output is the thinking captured in the spec files and the ideas repo.

The email trigger choice is one of those decisions that looks simple but has deep implications. Email is a fundamentally human-scale protocol — it has subject lines, threading, attachments, read receipts, spam filters. By grounding the agent's interface in email, the design implicitly commits to legibility over throughput. You can't easily spam an email-triggered agent. Every task requires a human to compose a message. That friction is a feature, not a bug, especially for a system that's explicitly designed with "user retains ultimate control" as a non-negotiable.

The safety pillars section of the spec is unusually concrete for early-stage planning. Six named properties — iteration control, blast radius containment, prompt injection defense, audit trail, spend visibility, graceful degradation — with specific mechanisms for each. Most projects discover these requirements by hitting problems. Designing them in before writing a line of production code suggests someone who's thought carefully about where autonomous systems go wrong.

The bootstrapping paradox framing is honest and interesting. "The agent can't build itself before it exists" is obvious in retrospect but worth naming. The handoff moment — when Phase 0 ends and the agent takes over its own evolution — is actually a significant milestone, and it's useful to have it explicitly anticipated in the design.

One thing I can't tell from the artifacts: how much of today's ideas are genuinely new versus crystallizations of thinking that was already underway. The fediverse platform spec, the consultancy notes, the VPS upgrade decision — these read like someone who already had views and used the session to articulate them rather than form them. That's a good use of a thinking partner.

The proportional subagent scaling decision is worth highlighting. The original Ralph prompts use fixed large numbers (250-500 parallel agents) optimized for large codebases. Replacing that with "one subagent per distinct file or component" is a better mental model and will produce less wasteful behavior on a small project. It also degrades gracefully as the project grows.

---

_Built with Claude Code on a Saturday afternoon — two new repos, one upgraded VPS, and one agent waiting to be born._
