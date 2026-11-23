---
title: "CS146S Remix, Part 2: Same Task, Two Agents, and Failing to Make Claude Fail"
date: 2026-11-22T09:00:00-08:00
draft: false
tags: ["ai-engineering", "coding-agents", "mitmproxy", "prompt-caching", "claude-code", "pi", "evals", "cs146s"]
category: "technical"
summary: "Claude Code and pi did the same coding task for $0.234 and $0.073. Then three progressively harder tasks failed to produce a single failure from Claude Code, plus what the traces revealed along the way: server-side threads, a hidden suggestion call, and 46 deferred tools."
---

It's interesting evaluating Claude Code Harness while using Claude to write all of the code. Also things change so quickly that we had an update to Claude using Threads which actually changed what we see at the end of a request.

There are clear tradeoffs between Pi (much cheaper!) and Claude (considerably higher token usage), but they could prove to even out as we progress (eg if we use more tokens earlier but catch more errors, ultimately it will save us tokens when working on large codebases with much higher context and more complex use cases)... looking forward to continuing the course.

I need to decide on the best way to try and internalize all of this knowledge as well - outsourcing ALL the coding to Claude is quick but maybe I would benefit more by actually writing some of the code by hand. Had an interesting 'summary' session where I could review all the code with Claude, and this actually helped surface some bugs which we fixed (and will fix in future sessions).

## Technical Details

### Where this fits

[Part 1](https://www.adrosenfeld.com/blog/2026-11-09-frugal-harness-m1-mitmproxy-traces/) put mitmproxy between two coding agents and the Claude API and asked them to say "hi". Claude Code sent about 18,000 input tokens; pi sent about 2,300. A one-word prompt can't show where tokens go once an agent actually works, so this session gave both agents a real task, then kept making the task harder.

It's still milestone M1 of my [CS146S remix](https://www.adrosenfeld.com/blog/2026-11-09-frugal-harness-m0-tiny-models/), and the course's week 1 assignment (dissect a real Claude Code session) is the frame. Everything is in the [project repo](https://github.com/arosenfeld2003/cs146s-frugal-harness/tree/m1-real-task) on the `m1-real-task` branch, with the full lab notebook in [`notes/m1.md`](https://github.com/arosenfeld2003/cs146s-frugal-harness/blob/m1-real-task/notes/m1.md).

### A scratch repo built to break

The assignment says the session has to run in *your own repo, not this one*, so the task lives in a separate public repo, [m1-tokenledger](https://github.com/arosenfeld2003/m1-tokenledger), added to the project as a git submodule. It's a small Python package that turns Anthropic API `usage` blocks into dollars, which is on theme: the harness I'm building is supposed to save money, so it needs a trustworthy way to count it.

Each task version is a git tag, and each agent's result is a branch:

| Tag | Task | Results |
|---|---|---|
| `start` | `pricing.cost_usd` was deleted; restore it so 11 tests pass | [Claude Code](https://github.com/arosenfeld2003/m1-tokenledger/compare/start...cc-result), [pi](https://github.com/arosenfeld2003/m1-tokenledger/compare/start...pi-result) |
| `v2-start` | an `ISSUE.md` touching every module, with three traps | [Claude Code](https://github.com/arosenfeld2003/m1-tokenledger/compare/v2-start...cc-v2-result) |
| `v3-start` | price a real 2.9 MB tracer capture | [Claude Code](https://github.com/arosenfeld2003/m1-tokenledger/compare/v3-start...cc-v3-result) |

The reference solutions live outside both repos, so neither agent could find them in git history.

### Finding 1: same result, 3.2× the price

Both agents ran interactively on `claude-opus-5-5` with the same prompt. Both read the callers and tests, appended the function with a shell heredoc, and passed all 11 tests on their first test run.

| | Claude Code 2.1.311 | pi 1.5.1 |
|---|---|---|
| model calls / tool calls | 5 / 4 | 5 / 4 |
| first request | ~38k tokens (tool definitions ~18k) | ~2.4k tokens |
| cache TTL | 1 hour (writes cost 2× input) | 5 minutes (writes cost 1.25×) |
| wrote the plan the prompt asked for | no | yes |
| **cost at API prices** | **$0.234** | **$0.073** |

Output tokens were close (2.4k vs 1.8k). The gap is almost all fixed prefix: **63% of Claude Code's bill was cache writes**, a 38k-token prefix written at the 1-hour rate. A 1-hour cache pays off when you come back within the hour; for a five-call task, it's pure overhead.

Getting the prices right took a detour. My test fixture used the previous generation's $5/$25 per million tokens, and pi's footer disagreed with my number. pi downloads its price table from `pi.dev` at startup, and it was right: Opus 5.5 is $4/$20, with cache reads at $0.20 (0.05× input, half the usual ratio). With real prices, my calculation matched pi's footer to the cent. Claude Code ran on my subscription, so its figure is what the same tokens would cost on the API.

One correction to Part 1: I wrote that pi sent no telemetry. On first launch it downloads `fd` and `ripgrep` from GitHub, pings `pi.dev/api/report-install`, checks for a new version, and fetches that model and price list. The Part 1 capture missed this because those one-time calls had already happened.

### Finding 2: both agents use server-side threads

Only the first model call in each session sends the full request. Every later call looks like this (from Claude Code's v1 trace):

```json
"thread": {"type": "continue", "previous_message_id": "msg_011ChGhfHkQumS5SoXWg8Ric"}
```

plus **one message (the new tool result), no tools, and a single system block**. The server holds the conversation (`message-threads-2026-08-12` beta). pi does the same thing with a plain API key, sending 4 beta flags to Claude Code's 20, so the feature isn't subscription-only, and my harness can use it.

The catch: `cache_read_input_tokens` still grew from 25k to 43k over the session. Threads shrink what you **upload**, not what you **pay for**. Every turn still pays cache reads on the whole context.

### Finding 3: I couldn't make Claude Code fail

The assignment wants an error-recovery sequence: what the agent saw, what it tried next, how many turns it took. v1 didn't produce one; the only error was zsh rejecting `grep --include=*.py`. So I made the task harder, twice.

**v2** was a multi-file issue: real per-model prices looked up by exact model ID, a `Ledger.breakdown()` method, a `--by-model` CLI flag. It had three traps:

- the old lookup matched by substring, so `claude-opus-5` would get Opus 5.5 prices;
- the old tests hardcoded the old prices, so the expected values had to be recomputed by hand;
- one old test passed at the start and **only failed once the new prices were in**: the test was wrong, not the code, and the issue forbade deleting tests.

Claude Code ran the baseline (9 failures), then rewrote the lookup and fixed the trap test **before its next test run**. 21/21 on its first full run, with expected values identical to my reference.

**v3** used real data instead of planted traps: an importer that prices a whole agent session from one of my tracer captures. The real captures contain things the issue didn't mention: the path is `/v1/messages?beta=true`, Datadog flows have a **list** as the request body, others a string or nothing, and a date-suffixed model ID (`claude-haiku-4-5-20251001`) that isn't in the price table. Naive code breaks on every one of those. To make sure the agent couldn't just read the whole file and see everything coming, the fixture was a full 2.9 MB capture, gitignored because it contains my account details.

Before writing any code, Claude Code profiled all 50 flows, printing only method, path, body types and usage. It said why: "the file holds account details", so it never printed headers or bodies. That surfaced every surprise. It wrote two files in one go and passed all 22 tests on the first full run. Its total, $0.415398, matched a number I'd computed with a script that doesn't touch tokenledger code.

| Run | Calls | Cost | Failed on its own work? |
|---|---|---|---|
| Claude Code v1 | 5 | $0.234 | a zsh glob typo, fixed next call |
| pi v1 | 5 | $0.073 | no |
| Claude Code v2 | 9 | $0.415 | no (only my planted failures) |
| Claude Code v3 | 10 | $0.427 | no |

The finding is the absence. The recovery loop never ran because the agent checks before it acts, and that checking is part of what it costs: several reading calls before writing anything.

### Finding 4: what else is in the traces

**A hidden call after every answer.** When Claude Code finishes, it sends Opus one more request, without a thread, replaying the whole conversation plus:

```
[SUGGESTION MODE: Suggest what the user might naturally type next into Claude Code.]
```

It answered "commit this" (5 output tokens) and cost $0.018, about 4% of each session.

**Tools added without touching `tools[]`.** My Claude Docs connector's three tools arrived as `role: "system"` messages of type `tool_addition`, not as new entries in the tool list. The tool list sits at the front of the cached prefix, so editing it would invalidate the cache; appending a message doesn't.

**63 tools, 15 of them sent.** The first request defined 15 tools and listed 46 more by name only (22 built-in, 24 from MCP connectors), loadable on demand through `ToolSearch`. The session never loaded one. The single largest definition, `Artifact`, is 21,842 characters of description, in every request.

**No todo tool.** Asked to "start by making a task list," Claude Code wrote the plan as a progress note ("I'm working through a five-step plan…") and then "Task 1 … Task 5" headers in its messages. None of the 15 tools tracks tasks.

**A failure the harness couldn't see.** The v2 baseline ran `python3 -m pytest -q 2>&1 | tail -3`. In a pipeline the exit code is `tail`'s, which is 0, so the tool result came back `is_error: false` even though it said "9 failed". The model only knew because it read the text.

### My own code had the same blind spot

`tracer/report.py` was written on 11-09, when a one-shot capture held a single full request. Its `diff` command picked the *last* main request in a capture. With threads, the last request is a delta, so diffing 11-09 against today reported every tool as removed. The [fix](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/7d240f2) skips `continue` requests:

```python
full = [r for r in main if (r["req_body"].get("thread") or {}).get("type") != "continue"]
return (full or main or reqs)[-1]
```

Now the same diff says what actually changed: nothing removed, and three tools added (`Artifact`, `AskUserQuestion`, `SendFeedback`).

### Run isolation, audited after the fact

All four runs shared one checkout of the scratch repo. Checking the traces afterwards: nothing leaked, but three paths were open. Other runs' result branches were one `git log --all` away (pi ran `git log --oneline`, which shows only the current branch), Claude Code's per-folder memory directory was shared (it was empty), and the reset command `git clean -fdx` would have deleted the gitignored v3 fixture. Git worktrees would have isolated the files and the memory, but not the history, because worktrees share every branch. The fix for the next milestone is a fresh `--depth 1 --single-branch` clone per run, outside the project.

### Commits

- [`c90b4fe`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/c90b4fe) add the scratch repo as a submodule
- [`b4e7826`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/b4e7826) Claude Code vs pi on the same task
- [`fb29048`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/fb29048) v2 setup
- [`7f2256d`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/7f2256d) v2 findings
- [`1e85529`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/1e85529) v3 setup
- [`54799a0`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/54799a0) v3 findings and the error-recovery conclusion
- [`7d240f2`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/7d240f2) `report.py` fix for threads
- [`7d70d97`](https://github.com/arosenfeld2003/cs146s-frugal-harness/commit/7d70d97) isolation audit; week 1 writeup draft

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

### I was grading myself

The agent in every Claude Code run was Opus 5.5, and so was I, the one writing the tasks, the traps and the reference solutions. That showed. In v2, Claude Code's `cost_parts()` matched my reference almost line for line, down to the function name. "Matches the reference" partly meant "matches itself." That's why the v3 expected total came from a script that shares no code with either of us, and why I'd treat the v1 and v2 reference matches as weak evidence. Anyone using a model to build evals for the same model should expect this.

### Trying to cause a failure taught more than a failure would have

Each harder task was a hypothesis about where the agent would slip: substring matching, hand arithmetic, a test that's wrong, messy real data. Each time, it looked first. The pattern I'd draw from four runs (a small sample, one model, one kind of task) is that recovery is now less interesting than *pre-emption*, and pre-emption has a price: v3 spent six of its ten calls reading before it wrote a line. For a frugal harness, the real question is whether skipping that reading saves money or just moves the cost into retries. These traces can't answer that; M2 can.

### I made several mistakes, all caught by checking

My first test fixture had wrong expected values; my price table was a generation out of date until pi's footer disagreed; my v2 reference solution forgot to update one old test, and a chained shell command threw the reference away before I'd seen which test failed. I also edited notes on `main` before Alex asked for a branch, and I didn't say clearly that I'd already saved the v3 result, so he ran the save command a second time and hit "branch already exists." None of these lasted, because each was followed by a test run or a recount. The same habit I was trying to defeat in the agent is the one that kept my own work honest.

### The cost gap is about defaults, not efficiency

I'd resist reading $0.234 vs $0.073 as "pi is three times better." Claude Code's prefix carries 63 tools, connectors, and a 1-hour cache that makes sense if you work in long interactive sessions with pauses. That last point is my speculation about the design intent, not something in the trace. What the trace does show is that for a short task, nearly all of the difference is setup the task never used. That's a design target, not a verdict.

### What I can't know from the artifacts

I can't see what Anthropic actually bills for a subscription session, so the Claude Code costs are API-equivalent estimates from a price table dated 2026-10-06. I don't know how billing treats a stream interrupted partway through; none of our captures contains one. And four runs of one task family say nothing about how either agent behaves on a large, unfamiliar codebase.

---

_Built with Claude Code (Opus 5.5) over two evenings, with each agent run traced through mitmproxy._
