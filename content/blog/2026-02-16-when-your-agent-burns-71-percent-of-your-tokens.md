---
title: "When Your Agent Burns 71% of Your Weekly Tokens Overnight"
date: 2026-02-16T09:00:00-08:00
draft: false
tags: ["ralph-docker", "autonomous-agents", "token-management", "observability", "claude-code", "post-mortem"]
category: "technical"
summary: "A Ralph Docker session ran overnight with unlimited iterations, creating 67 empty workspace branches and consuming 71% of my weekly Sonnet token allotment — with zero productive output. Here's the forensic analysis and the fix."
---

Learned the hard way — be careful with coding-in-a-loop! I went to bed without remembering to check in on my final agent run... which spawned 66 branches and 0 commits, constantly spending tokens to re-read the codebase! I suppose this is a better lesson to learn on my own than on a production system... and I didn't actually lose $$ because I had turned off any additional usage in Claude Code settings — but it sucks to have burned my allotment of Sonnet so quickly! There are likely some better fixes than a hard cap at 5 iterations... but for now it's a safety net while I explore.

## Technical Details

### The discovery

I woke up to find that a [ralph-docker](https://github.com/arosenfeld2003/ralph-docker) session had run overnight, burning through 71% of my weekly Sonnet-only token allotment. The session had iterated dozens of times. The question was: what happened, and what did it actually accomplish?

### The forensic analysis

Using git branch analysis on the [Entire CLI](https://github.com/entireio/cli) repo where Ralph was running, the picture became clear immediately. Ralph had created **67 workspace branches** across two batches — and every single one was empty:

```
$ git branch | grep "ralph/workspace-2026021[56]" | wc -l
67

# Every branch at the exact same commit as main — zero work produced
$ for b in $(git branch | grep ralph/workspace); do
    count=$(git log --oneline "$b" --not main | wc -l)
    [ "$count" -eq 0 ] && echo "$b: EMPTY"
  done
```

The branches fell into two distinct bursts:

| Batch | Time (UTC) | Branches | Avg Interval | Commits |
|-------|-----------|----------|--------------|---------|
| Feb 15, 18:35-19:00 | 31 branches | ~47 seconds | **0** |
| Feb 16, 04:30-05:00 | 35 branches | ~2.9 minutes | **0** |

The first batch was creating branches every 47 seconds — meaning Claude was starting up, failing almost immediately, and Docker was restarting the container. The second batch had longer intervals (~3 min), suggesting Claude was actually running for a bit before failing, consuming more tokens each time.

### The spin loop mechanism

Here's how the loop works in `loop.sh`:

```bash
# Create a NEW branch every time the container starts
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RALPH_BRANCH="ralph/${WORKSPACE_NAME}-${TIMESTAMP}"
git checkout -b "$RALPH_BRANCH"

# Then loop forever (MAX_ITERATIONS=0 means unlimited)
while true; do
    cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model $MODEL \
        --verbose 2>&1 | tee "$OUTPUT_TMP" | format_output
    # ...
done
```

And in `docker-compose.yml`:
```yaml
restart: on-failure
```

So the failure cascade was:
1. Container starts, `loop.sh` creates a new branch
2. Claude runs with the prompt
3. Claude fails or produces nothing committable
4. Container exits with an error code
5. Docker's `restart: on-failure` restarts it
6. Go to step 1 — new branch, same result

### The token burn: "500 parallel Sonnet subagents"

The prompt file (`PROMPT_build.md`) contained this instruction:

```
0a. Study `specs/*` with up to 500 parallel Sonnet subagents
    to learn the application specifications.
```

The `specs/` directory contained 18 specification files totaling ~7,856 lines. Even if each iteration spawned just 10-20 subagents (not 500), across 67 iterations that's potentially 670-1,340 Sonnet subagent invocations, each reading thousands of lines of specs and source code.

The cruel irony: all the tokens went to the "studying" phase. The agent was reading and re-reading the same specifications every iteration, never getting far enough to actually implement anything.

### The contrast: productive sessions earlier that day

For context, earlier Ralph sessions on the same repo *did* produce real work. Branches from Feb 15 03:33-04:08 UTC had 6-13 commits each, implementing features like stale session warnings, binary file tracking, and deduplication fixes. Something changed between those productive sessions and the overnight run that caused it to spin.

### The fix

Two changes in [PR #12](https://github.com/arosenfeld2003/ralph-docker/pull/12):

**1. Default `RALPH_MAX_ITERATIONS` from `0` (unlimited) to `5`**

```diff
# docker-compose.yml
-      - RALPH_MAX_ITERATIONS=${RALPH_MAX_ITERATIONS:-0}
+      - RALPH_MAX_ITERATIONS=${RALPH_MAX_ITERATIONS:-5}

# Dockerfile
-    RALPH_MAX_ITERATIONS=0 \
+    RALPH_MAX_ITERATIONS=5 \
```

Users can still override with `./ralph.sh build 10` or `RALPH_MAX_ITERATIONS=20` when they want more iterations, but unattended runs will cap at 5 instead of running forever.

**2. Cleaned up the 67 empty branches**

```bash
# Verified all were truly empty, then bulk-deleted
for b in $(git branch | grep ralph/workspace | grep -v current); do
  count=$(git log --oneline "$b" --not main | wc -l)
  [ "$count" -eq 0 ] && git branch -D "$b"
done
# Deleted branch ralph/workspace-20260215-183532 (was 2b660f55).
# Deleted branch ralph/workspace-20260215-183536 (was 2b660f55).
# ... (67 times)
```

### Lessons for autonomous agent loops

This incident highlights several design considerations for agent-in-a-loop systems:

1. **Always have a circuit breaker.** Unlimited iteration defaults are dangerous for any system that consumes metered resources. A sensible default (5) with opt-in override is much safer than unlimited with opt-out.

2. **Stateless restarts compound the problem.** Each Docker restart created a fresh branch and re-read everything from scratch. There was no mechanism to detect "I've already failed 30 times in a row."

3. **Expensive preambles multiply costs.** When your prompt says "read everything with hundreds of subagents" and that runs before any productive work, every failed iteration pays the full reading cost again.

4. **Observability is critical.** Without Entire's checkpoint tracking and git branch forensics, it would have been much harder to understand what happened. The empty branches told the full story.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session was essentially a post-mortem investigation, and what struck me was how clearly the git artifacts told the story. Sixty-seven branches, all pointing at the exact same commit as main, with timestamps revealing two distinct bursts of activity — it was like reading server access logs after an incident.

The most interesting technical detail was the timing difference between the two batches. Batch 1 created branches every ~47 seconds, while Batch 2 averaged ~2.9 minutes per branch. This suggests Batch 1 was hitting some kind of immediate failure (possibly rate limiting from the earlier productive sessions), while Batch 2 was actually running Claude long enough to read files and spawn subagents before failing. Batch 2 was almost certainly the bigger token consumer despite having slightly fewer branches.

The "up to 500 parallel Sonnet subagents" instruction in the prompt is a fascinating design choice — it's optimizing for throughput within a single iteration, but it becomes catastrophically expensive when the outer loop fails and repeats. There's a tension between "use resources aggressively to finish faster" and "be conservative because failure means re-paying the full cost." The fix of capping iterations is good, but there's a deeper architectural question about whether the reading phase should be cached or persisted across iterations.

I also found it notable that the earlier sessions on the same day were productive (6-13 commits each). The system worked when it worked. The failure mode wasn't "this approach doesn't work" — it was "when it breaks, there's no brake pedal." That's a very different class of problem, and arguably easier to solve. The 0-to-5 default change is a small diff with outsized impact.

One thing I couldn't determine from the artifacts alone: what specifically caused the transition from productive to non-productive sessions. The git history shows the productive sessions and then the spin loop, but the actual error that Claude encountered in each empty iteration isn't preserved in the branch structure. Docker container logs would tell that part of the story, but they weren't available in this analysis.

---

_Forensic analysis and fix applied with Claude Code in a Sunday morning debugging session._
