---
title: "Making Ralph Docker Plug-and-Play"
date: 2026-02-12T09:00:00-08:00
draft: false
tags: ["ralph-docker", "claude-code", "autonomous-agents", "developer-experience", "observability"]
category: "technical"
summary: "Ralph-docker now has a built-in setup command that interviews you and generates all project files via Claude — no external skill required. Plus, a rewrite of the README to put observability front and center."
---

I'm excited about this "agent harness." I plan to share ralph-docker as an open-source repository for people curious about exploring this new paradigm of building software using an agent in a loop. Safety and observability are clearly going to be extremely important aspects of this workflow — which is also why I'm excited about using [Entire](https://github.com/entireio/cli). In fact, I'm currently testing ralph-docker with an exploration of an Entire pain point, with plans to create a PR and contribute back to the project. This was a fun session and I'm feeling inspired to continue down this path.

## Technical Details

### The problem: hidden prerequisites

[Ralph-docker](https://github.com/arosenfeld2003/ralph-docker) is a containerized autonomous development loop — you point it at a git repo and it runs Claude Code in a loop, planning, implementing, testing, and committing. But until today, getting started required a hidden prerequisite: running the `/ralph` Claude Code skill *outside* the container to generate the project files (`AGENTS.md`, `PROMPT_plan.md`, `PROMPT_build.md`, `specs/`, `IMPLEMENTATION_PLAN.md`, `ralph.sh`). The README listed these files as "REQUIRED" but didn't make it obvious how to create them.

The goal was to bring the setup experience into ralph-docker itself, so the developer flow becomes:

```
1. Authenticate
2. docker compose run --rm ralph setup
3. ./ralph.sh
```

### The setup command

The new `setup` command ([PR #5](https://github.com/arosenfeld2003/ralph-docker/pull/5)) adds a `scripts/setup-workspace.sh` that runs a shell-driven interview using `read -p` prompts, then passes the collected answers to Claude in headless mode to generate all project files.

The interview is deliberately minimal — only the project goal is required:

```bash
# 1. Project goal (required)
PROJECT_GOAL=""
while [ -z "$PROJECT_GOAL" ]; do
    read -p "In one sentence, what is the goal of this project? " -r PROJECT_GOAL
    if [ -z "$PROJECT_GOAL" ]; then
        log_warn "Project goal is required."
    fi
done

# 2. Tech stack (optional)
read -p "What tech stack? (press Enter to auto-detect from codebase) " -r TECH_STACK

# 3. Build command (optional)
read -p "Build command? (press Enter to auto-detect) " -r BUILD_CMD

# 4. Test command (optional)
read -p "Test command? (press Enter to auto-detect) " -r TEST_CMD
```

The rationale: Claude can auto-detect tech stacks, build commands, and test commands from the codebase (look for `package.json`, `go.mod`, `Cargo.toml`, etc.), but it can't reliably infer *intent*. The project goal is the one thing only the human knows.

### Prompt assembly

The clever part is how the interview answers get wired into Claude. The script reads the existing `skills/ralph.md` template (the same template used by the interactive `/ralph` skill) and prepends a context block that overrides the interactive parts:

```bash
CONTEXT="The user has already answered the interview questions.
Do NOT use AskUserQuestion — use these answers directly:

PROJECT GOAL: ${PROJECT_GOAL}
TECH STACK: ${TECH_STACK:-Auto-detect from the codebase.}
BUILD COMMAND: ${BUILD_CMD:-Auto-detect from the codebase.}
TEST COMMAND: ${TEST_CMD:-Auto-detect from the codebase.}

IMPORTANT OVERRIDES:
- Skip the Initial Assessment step — the user has confirmed they want to set up.
- Skip ALL AskUserQuestion calls — all answers are provided above.
- Proceed directly through steps 2-8 using the answers above."

claude -p "$ASSEMBLED_PROMPT" --dangerously-skip-permissions --model "$MODEL"
```

This reuses the skill template without duplication — the template defines *what* files to create and their structure, while the context block supplies the answers that would normally come from interactive prompts.

### Entrypoint integration

The `setup` command follows the same auth-check pattern as `loop`:

```bash
setup)
    detect_auth || exit 1
    wait_for_litellm || exit 1
    verify_workspace
    log_info "Starting workspace setup..."
    exec /home/ralph/scripts/setup-workspace.sh
    ;;
```

And the Dockerfile needed one line to include the skills template in the image:

```dockerfile
COPY --chown=ralph:ralph skills/ skills/
```

### README rewrite: observability as a first-class concern

The second PR ([PR #6](https://github.com/arosenfeld2003/ralph-docker/pull/6)) restructured the README around two ideas:

**1. "Clarify your intent" as a workflow step.** A new step 2 in the Quick Start recommends having a short LLM conversation *before* running `setup` to sharpen the project goal. The quality of everything Ralph generates — specs, plans, prompts — depends on the precision of that one-sentence goal.

**2. "Reviewing What Ralph Did" as a top-level section.** Previously, Entire CLI observability was buried in a subsection. Now there's a dedicated section showing concrete commands for both git-based review and Entire session data:

```bash
# Git history (always available)
git branch --list 'ralph/*'
git log ralph/myproject-20260212-143022 -p
git diff main...ralph/myproject-20260212-143022

# Entire session observability (recommended)
RALPH_ENTIRE_ENABLED=true ./ralph.sh
git log entire/checkpoints/v1 --oneline
git show entire/checkpoints/v1
```

The message: if you're running an autonomous agent on your codebase, knowing what it did and *why* shouldn't be an afterthought.

### Files changed

**PR #5 — Setup command:**
- `scripts/setup-workspace.sh` (new, 190 lines) — interview + Claude generation
- `Dockerfile` — added `COPY skills/`
- `scripts/entrypoint.sh` — added `setup` case + help text
- `README.md` — rewritten for plug-and-play flow

**PR #6 — README observability:**
- `README.md` — added "Clarify your intent" step, "Reviewing What Ralph Did" section, promoted Entire to recommended

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session was a study in closing the gap between "tool author knows how it works" and "new user can figure it out." The ralph-docker setup had a chicken-and-egg problem: you needed the `/ralph` Claude Code skill to generate the files that ralph-docker required, but that skill lived outside the container and wasn't documented as a prerequisite in an obvious way. The README said "REQUIRED" next to several files without explaining how to create them.

The solution has an elegant layering to it. Rather than duplicating the skill template's logic in a new script, `setup-workspace.sh` reads the *same* `skills/ralph.md` file and prepends interview answers as overrides. This means the setup command and the interactive `/ralph` skill produce identical output — the only difference is where the interview happens (shell prompts vs. Claude Code's `AskUserQuestion`). If someone updates the skill template, the setup command picks up the changes automatically.

I found the interview design interesting in what it asks vs. what it skips. Only the project goal is required; everything else defaults to "auto-detect from the codebase." This reflects a real asymmetry: Claude is good at reading `package.json` to figure out the tech stack, but terrible at guessing what you're trying to build. The script enforces this with a `while [ -z "$PROJECT_GOAL" ]` loop — you literally can't proceed without stating your intent.

The README rewrite was the more opinionated piece. Promoting Entire from "opt-in observability" to "recommended" in the Quick Start is a statement about what matters when running autonomous agents. The new "Reviewing What Ralph Did" section doesn't just say "check git history" — it provides the exact `git log`, `git diff`, and `git show` commands to run, along with how to inspect Entire's shadow branch. This is the kind of documentation that saves someone 20 minutes of figuring out the right incantation.

The "Clarify your intent" step is worth noting because it's advice that applies beyond this tool. Having a short LLM conversation to sharpen your project goal before feeding it into an automated pipeline is a pattern that compounds: better input at the top means less wasted iteration at every step downstream. The README makes this concrete with a good-vs-vague example.

One thing I couldn't observe from the artifacts alone: how often users actually hit the original problem. The README changes suggest it was a real friction point, but I can only see the fix, not the complaints that motivated it.

---

_Built with Claude Code in an evening session._
