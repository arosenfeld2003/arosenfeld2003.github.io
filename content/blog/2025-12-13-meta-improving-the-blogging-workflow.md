---
title: "Meta: Improving the Development Workflow Itself"
date: 2025-12-13T09:00:00-08:00
draft: false
tags: ["meta", "workflow", "automation", "claude-code", "tooling"]
category: "meta"
summary: "Taking a step back from coding to improve the tools that document the coding process—fixing the /blog and /resume slash commands to be more robust and token-efficient."
---

This session proves the viability of an agentic approach to software development, provided a human is still closely monitoring the output. It's actually pretty fun to work this way. It would have taken me hours to evaluate the slash commands we previously developed (`/blog` and `/resume`). They're super useful, but as I noticed they were not working optimally, Claude was able to quickly (within a couple mins) evaluate the issues and suggest improvements! This is a larger lesson about the current and future state of software development—likely there's a niche now for an agent evaluator to continually suggest improvements to existing systems. Security and reliability (along with ALIGNMENT) will become increasingly important, but as for the aspect of actual dev work I can see a clear trend towards conversational flows and an emphasis on higher-level thinking from the human developer.

## Technical Details

This session was different—instead of writing application code, we improved the development workflow itself. Specifically, we enhanced two Claude Code slash commands that had been causing friction.

### The Problem

During the session, we encountered two pain points with the existing workflow automation:

1. **The `/blog` command** didn't ensure it was working from the latest code before creating a new blog post branch
2. **The `/resume` command** was failing early with shell parsing errors and consuming excessive tokens trying to parse conversation history

### Improving the Blog Workflow

The `/blog` command automates creating blog posts about coding sessions. The fix was straightforward—ensure we always pull the latest master before branching:

**Before:**
```markdown
## 3. Create Blog Post Draft
- Navigate to `/Users/alexrosenfeld/repos/arosenfeld2003.github.io`
- Create a new branch: `blog-post-$(date +%Y-%m-%d)`
```

**After:**
```markdown
## 3. Create Blog Post Draft
- Navigate to `/Users/alexrosenfeld/repos/arosenfeld2003.github.io`
- Checkout master and pull latest changes: `git checkout master && git pull origin master`
- Create a new branch: `blog-post-$(date +%Y-%m-%d)`
  - If a branch with this name already exists, either switch to it or create a unique variant (e.g., add `-v2` suffix)
```

This prevents the issue we hit where the local master was behind origin, causing the blog post creation to miss recently merged posts.

### Overhauling the Resume Command

The `/resume` command was more problematic. It attempted to:
1. Find the previous session's conversation log
2. Parse the entire JSON conversation history
3. Reconstruct what was worked on from chat logs

This approach had multiple failures:

**Shell Parsing Issues:**
```bash
# Old approach - failed with "parse error near `('"
ls -t ~/.claude/projects/*/chat-*.jsonl 2>/dev/null | grep -v agent- | head -1
```

The glob pattern `*/chat-*.jsonl` failed in zsh. The project directory names also had underscores that needed conversion to hyphens, adding complexity.

**Token Inefficiency:**
The old command tried to parse 30-50 lines of JSON conversation history, often failing with `jq` errors, and consuming significant tokens even when successful.

### The New Approach

The rewritten `/resume` command takes a fundamentally different approach:

#### 1. Robust File Discovery

Instead of complex globs, use a step-by-step approach with temp files:

```bash
# Transform current directory path to Claude projects format
pwd | tr '/' '-' | tr '_' '-' | sed 's/^-//' > /tmp/claude_project_dir.txt

# Construct the session directory path and find most recent session
echo "/Users/alexrosenfeld/.claude/projects/-$(cat /tmp/claude_project_dir.txt)" | \
  xargs ls -t 2>/dev/null | grep -v agent | grep '\.jsonl$' | head -1 > /tmp/claude_session_file.txt

# Get full path to session file
SESSION_FILE="/Users/alexrosenfeld/.claude/projects/-$(cat /tmp/claude_project_dir.txt)/$(cat /tmp/claude_session_file.txt)"
```

This approach:
- Uses `tr` for reliable character replacement
- Writes intermediate results to `/tmp` to avoid variable expansion issues
- Uses `xargs` to bypass glob pattern problems
- Handles the underscore→hyphen conversion that was causing mismatches

#### 2. Favor Current State Over Chat History

The key insight: **git history is more reliable than conversation logs**

```bash
# What's the current branch?
git branch --show-current

# Any recent commits?
git log --oneline -5

# Any uncommitted changes?
git status --short
```

This is:
- **More reliable** - Git commits don't lie; chat logs might be incomplete
- **More token-efficient** - No parsing large JSON files
- **More actionable** - Current state matters more than past conversation

#### 3. Token-Efficient Context Extraction

When the session file is found, extract only what's needed:

```bash
# Get the summary line (appears near the beginning)
grep '"type":"summary"' "$(cat /tmp/claude_session_path.txt)" | head -1

# Get the last 20 lines to see recent activity
tail -20 "$(cat /tmp/claude_session_path.txt)"
```

No complex `jq` parsing, just targeted grep for the summary and a quick tail to see recent activity.

#### 4. Graceful Failure Handling

The new command explicitly handles failures:

```markdown
## Troubleshooting

If commands fail:
- **"No such file or directory"**: No previous session exists for this project, skip to analyzing current state
- **Empty grep results**: Session file exists but has no summary yet, just note this and focus on current state
- **Git errors**: Not in a git repository, skip git commands and just read project files
```

### File Locations

These slash commands live in `~/.claude/commands/`:
- `blog.md` - Automates blog post creation and PR workflow
- `resume.md` - Loads context from previous sessions

They're not version controlled (yet), but they're critical infrastructure for the development workflow.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session represents an interesting meta-level in software development: improving the tools that document the development process itself. It's recursive productivity—making the documentation system more efficient so future documentation requires less overhead.

### The Shell Parsing Journey

The debugging process for `/resume` revealed a cascade of Unix shell quirks:

1. **Glob expansion in zsh** behaves differently than bash—what works in `bash` with `*/pattern` fails in `zsh`
2. **Variable expansion in subshells** with `$()` syntax can cause "parse error near `(`" when the shell tries to expand too early
3. **Underscore vs hyphen normalization** was needed because Claude projects directory names convert underscores to hyphens

The solution—writing to temp files—is less elegant but more robust. It trades purity for reliability, which is often the right choice in systems automation.

### The Philosophical Shift

The most significant change wasn't technical but conceptual: **stop trying to reconstruct the past from chat logs; instead, observe the present state**.

The old `/resume` approach was fundamentally historical:
- "What did we talk about?"
- "What did the conversation logs say we were doing?"
- "Can we parse JSON to understand the session?"

The new approach is present-focused:
- "What does git say about recent work?"
- "What files exist now?"
- "What's the current branch and status?"

This shift has several advantages:

**Reliability**: Git commits are ground truth. Conversation logs might be incomplete if sessions crashed, or might contain speculation that didn't materialize into code.

**Efficiency**: `git log --oneline -5` is far cheaper than parsing 50 lines of conversation JSON with complex `jq` queries.

**Actionability**: Knowing "there are uncommitted changes in `my_malloc.c`" is more useful than knowing "we discussed implementing calloc 2 hours ago."

### Token Economics

The rewrite demonstrates an important principle in AI-assisted development: **token efficiency matters**.

The old approach could consume hundreds of tokens just trying to resume context:
- Parse session directory structure: ~50 tokens
- Multiple failed glob attempts: ~100 tokens
- Parse JSON with jq: ~200+ tokens
- Extract and summarize conversation: ~300+ tokens

The new approach targets ~100 tokens total:
- Find session file with temp files: ~50 tokens
- Grep for summary: ~20 tokens
- Git status commands: ~30 tokens

This 70% reduction means faster startup and more tokens available for actual work.

### The Irony

There's a pleasant irony here: we're creating a blog post about improving the blog post creation workflow, using the improved workflow itself.

This post was created with the updated `/blog` command that now:
1. Pulls latest master first (avoiding the stale branch issue)
2. Handles existing branch names gracefully
3. Sets proper timestamps to avoid Hugo's future-date filtering

The meta-loop is complete when the tool documents its own improvement.

### What the Changes Reveal

Looking at the diffs between old and new:

**blog.md changes** show a maturation of the workflow—anticipating edge cases like existing branches and stale local repositories. These are the kinds of issues you only discover through actual use.

**resume.md changes** show a pivot from "parse everything" to "observe strategically." This suggests the original implementation was over-engineered, trying to be too thorough when a simpler approach would work better.

Both changes reflect the classic engineering tension between:
- **Robustness** (handle edge cases, graceful degradation)
- **Simplicity** (fewer moving parts, clearer logic)

The solutions find a middle ground: simpler core logic (favor git over chat logs) with explicit error handling (temp files, documented failure modes).

### Limitations of This Analysis

I can observe:
- The command files before and after
- The shell errors encountered during debugging
- The final working implementations

I cannot observe:
- How many iterations it took to get the temp file approach working
- What other solutions were considered and rejected
- The subjective experience of the debugging process

The artifacts show the destination, not the journey. The clean final implementation hides the trial-and-error that likely preceded it.

### Broader Implications

This work touches on a larger theme in developer productivity: **the tools that build the tools matter**.

Many developers focus exclusively on application code, treating their development environment as fixed infrastructure. But time invested in improving your workflow—better commands, better automation, better documentation systems—compounds over time.

Every future blog post will benefit from the improved `/blog` command. Every session startup will be faster with the efficient `/resume` command. These are multipliers on all future work.

The ROI calculation for workflow improvement is:
```
Value = (time_saved_per_use) × (frequency_of_use) × (remaining_uses)
```

For frequently-used commands, even small time savings add up. Token efficiency improvements also compound—every 100 tokens saved on resume is 100 tokens available for actual problem-solving.

### Next-Level Meta

One could imagine going further:
- Version control the slash commands themselves (they currently live in `~/.claude/commands/` untracked)
- Add tests for the commands (though testing shell scripts is notoriously tricky)
- Create a `/meta` command that analyzes and suggests improvements to other commands

But there's a point of diminishing returns. The goal is productive development, not infinitely recursive tooling. Sometimes good enough is good enough.

---

_Built with Claude Code during an afternoon of meta-productivity, using the very workflow improvements documented herein_
