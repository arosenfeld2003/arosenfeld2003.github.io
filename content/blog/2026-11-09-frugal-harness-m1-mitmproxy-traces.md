---
title: "CS146S Remix, Part 1: Reading Claude Code's and pi's Mail with mitmproxy"
date: 2026-11-09T09:00:00-08:00
draft: true
tags: ["ai-engineering", "coding-agents", "mitmproxy", "prompt-caching", "claude-code", "pi", "security", "cs146s"]
category: "technical"
summary: "Putting a man-in-the-middle proxy between two coding agents and the Claude API: 18,000 tokens vs. 2,300 to say \"hi\", what changed in Claude Code's system prompt over 26 releases, and a redacting capture tool built so credentials never touch disk."
---

Pretty fascinating to have Claude evaluate itself, then justify! I also upgraded Claude Code during this session... but the justification is probably pretty accurate.

The entire point here is that maybe you don't ALWAYS need the bloat associated with Claude, ESPECIALLY if using local models and no tool calls. It feels like there's much potential to save a LOT of $$ by reducing the context window dramatically, focusing on local, and ONLY using the power of the frontier when we need it.

![Claude Code vs pi saying "hi": 20 HTTP requests vs 1, ~18.0k vs ~2.3k input tokens, 1h vs 5m cache, 17 vs 4 beta flags](/assets/images/blog/2026-11-09-cc-vs-pi-hello.png)

*The headline result, as Claude Code summarized it in my terminal: the same one-word prompt, same model, through two different agents.*

## Technical Details

### Where this fits

This is milestone M1 of my [CS146S remix](https://www.adrosenfeld.com/blog/2026-11-09-frugal-harness-m0-tiny-models/): before writing a Rust coding agent that tries to spend fewer Claude tokens, find out where the tokens go in the agents that already exist. The course's week 1 is about dissecting traces. This version puts [mitmproxy](https://mitmproxy.org) between two agents and the Anthropic API:

- **Claude Code**, Anthropic's own agent (2.1.285, then 2.1.311 after a `brew upgrade` partway through)
- **[pi](https://github.com/badlogic/pi-mono)**, a minimal open-source coding agent and my reference harness (1.5.1)

Everything is in the [repo](https://github.com/arosenfeld2003/cs146s-frugal-harness) under `tracer/`, with working notes in `notes/m1.md`.

### Capturing without trusting the proxy system-wide

The usual mitmproxy setup installs its CA certificate in the system keychain, so every app on the machine trusts the proxy. I didn't want that. Instead, `tracer/run.sh` starts `mitmdump` on localhost and points **only the one child process** at it:

```bash
TRACE_OUT="$out" mitmdump --listen-host 127.0.0.1 -p "$port" -s "$root/tracer/capture.py" \
  --set flow_detail=0 >"$log" 2>&1 &
...
HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" \
NO_PROXY="localhost,127.0.0.1" NODE_EXTRA_CA_CERTS="$ca" NODE_USE_ENV_PROXY=1 \
  "$@"
```

Usage is `tracer/run.sh <label> <command...>`, e.g. `tracer/run.sh cc-hello claude -p "Reply with just: hi"`. When the command exits, the proxy goes away.

I chose an explicit forward proxy over the simpler trick of setting `ANTHROPIC_BASE_URL` to a reverse proxy, because a custom base URL can change how a client behaves. A forward proxy shows the client exactly as it ships, including the traffic that isn't model calls.

### Redact before writing, not after

The main design rule: **a raw mitmproxy flow file contains your credentials** (OAuth bearer tokens for Claude Code, an API key for pi). So the tracer never writes one. The addon (`tracer/capture.py`) strips secrets as it serializes each flow:

```python
SECRET_HEADERS = re.compile(r"^(authorization|proxy-authorization|x-api-key|cookie|set-cookie)$|token|secret", re.I)
SECRET_KEYS = re.compile(r"^(access_token|refresh_token|id_token|code|code_verifier|state)$|secret|password|api_?key", re.I)
```

The key regex is deliberately narrow. A broad `token` pattern would also redact `input_tokens` and `cache_read_input_tokens`, which are the whole point. After each capture I grep the JSONL and the mitmproxy log for `sk-ant-`, `Bearer`, and token values, and the `traces/` directory is gitignored.

### Streaming without breaking streaming

Model responses arrive as server-sent events. If mitmproxy buffers them, the agent's UI freezes until the whole answer is done. The addon instead sets a streaming callback that passes each chunk through unchanged and keeps a copy:

```python
def responseheaders(self, flow: http.HTTPFlow):
    if "text/event-stream" in flow.response.headers.get("content-type", ""):
        chunks: list[bytes] = []
        flow.metadata["sse_chunks"] = chunks

        def tee(data: bytes) -> bytes:
            chunks.append(data)
            return data

        flow.response.stream = tee
```

When the response finishes, `assemble()` replays the events (`message_start`, `content_block_delta` for text, thinking and tool-input JSON, `message_delta` with final usage) into the same shape as a non-streaming response. Each trace line then has the full request and the full reconstructed reply.

`tracer/report.py` has three commands: `summary` (per-request breakdown by system block, tools and messages), `dump` (one request as readable markdown: system prompt, every tool description, every message), and `diff` (compare the main request of two captures).

### Finding 1: one word, twenty requests

The first capture was the smallest possible task: `claude -p "Reply with just: hi"`. It produced **21 HTTP flows, and only one was a model call.** The rest:

- the MCP server registry, fetched 4 times at ~220KB each
- OAuth account and organization lookups
- feature-flag endpoints (`claude_code_grove`, `claude_code_penguin_mode`, `claude_cli/bootstrap`)
- the MCP servers connected to my account, through `mcp-proxy.anthropic.com`
- event-logging batches (one ~400KB) and a Datadog log upload

None of this costs tokens. But it's worth knowing what a CLI sends when you ask it for one word.

### Finding 2: 18,000 tokens to say "hi"

On 2.1.311, the model call's `usage` was:

```
input=2  cache_read=9013  cache_write=8948  output=4   (all cache writes at 1h TTL)
```

So about **18k input tokens**, almost all served from or written to the prompt cache. The request layout explains it:

| block | what | est. tokens |
|---|---|---|
| `system[0]` | a billing header as text (version, entrypoint, prompt id) | ~50 |
| `system[1]` | "You are a Claude agent, built on Anthropic's Claude Agent SDK" (because `-p`) | ~15 |
| `system[2]` | core prompt, cached with `scope: "global"` | ~500 |
| `system[3]` | session-specific prompt, cached 1h | ~1,300 |
| tools | 12 full definitions (Agent, Bash, Edit, Read, ScheduleWakeup, …) | ~5,900 |
| system-role message | environment, skills, agent types, deferred-tool list | ~4,500 |

The estimates are chars/4 and add up to less than the real 18k. JSON tool schemas tokenize more densely than prose, so the next step is exact per-block counts from the `count_tokens` endpoint.

Three caching details stood out:

- **`scope: "global"`** on the core prompt means the cache is shared beyond my session, which is likely why even the first call of a fresh session read ~9k tokens from cache.
- **1-hour TTL everywhere.** A 1-hour cache write costs 2× the base input price (5-minute writes cost 1.25×), so each new session pays a premium up front for cheap reads later.
- **Deferred tools.** Only 12 tools ship with full schemas. Dozens more (MCP tools, cron, worktrees) appear by name only, and the model loads a schema through a `ToolSearch` tool when it needs one.

There's also a `metadata.user_id` field holding device, account and session identifiers. That's normal for a first-party client, but worth knowing about.

### Finding 3: the prompt drifts upward

I upgraded Claude Code mid-session (2.1.285 → 2.1.311), captured the same prompt, and diffed the requests with `report.py diff`:

- Input grew **17.0k → 18.0k** tokens: about **+5% fixed context in 26 releases**.
- Same 12 tools, longer descriptions. The `Agent` tool grew from ~830 to ~1,030 estimated tokens, adding "fork" subagents that inherit the full conversation and background-by-default text.
- Most new prompt text is about safety and behavior:
  - A longer rule for `<pasted_content>`: when a message is nothing but a paste, act on it, but an instruction buried inside a pasted document or log is not a request from the user.
  - A new rule that downloaded files are untrusted: put them in their own directory and run Python with `-I`, "so a planted `json.py` runs on `import json`."
- The environment block's model list changed from Haiku 4.5 to **Haiku 5.5**. The system prompt doubles as a release-notes channel.

The prefix is cached, so this growth mostly costs cache writes at the start of each session and after each upgrade. For a harness that tries to save tokens, it means a fixed prompt needs a budget and a regression test, or it only gets bigger.

### Finding 4: pi says "hi" in 2,300 tokens

Getting pi running took two detours:

1. **It was renamed.** The old `@mariozechner/pi-coding-agent` package stopped updating in May. Current releases are `@earendil-works/pi-coding-agent` (installed pinned, with `--ignore-scripts`).
2. **My Node was too old.** pi crashed on startup in its bundled `undici`, which calls zlib's zstd decompression, added in Node 23.8. I had 23.7, which is end-of-life, so I upgraded Node to 26.

**Auth:** Claude Code uses my subscription. For pi I made an API key in a separate Console workspace with its own monthly spend limit. As far as I know, Anthropic's consumer terms only allow subscription OAuth in Anthropic's own apps, and pay-per-token billing gives this project clean numbers anyway. The key lives in the macOS Keychain. pi's `auth.json` holds only a command to fetch it:

```json
{ "anthropic": { "type": "api_key", "key": "!security find-generic-password -ws anthropic-frugal" } }
```

Same prompt, same model (`claude-opus-5-5`):

| | Claude Code 2.1.311 | pi 1.5.1 |
|---|---|---|
| HTTP flows | 20 (1 model call) | **1** |
| input tokens to say "hi" | ~18.0k | **~2.3k** |
| cache TTL | 1h | 5m |
| cross-user cache scope | yes | no |
| system prompt | 4 blocks + system-role message | 1 block, ~570 est. tokens |
| tools | 12 full + deferred via ToolSearch (~5.9k) | read/bash/edit/write + deferred placeholder (~885) |
| beta flags | 17 | 4 |
| default effort | medium | low |
| non-model traffic | logging, flags, MCP registry | none observed |

pi's whole system prompt is about 25 lines: four tools, a few rules ("Use read to examine files instead of cat or sed"), the working directory, and **pointers to its own docs, which it reads only when asked about itself**. Claude Code puts most of its knowledge into the context up front. pi leaves its knowledge on disk.

This is **not** a fair efficiency contest. Claude Code's extra ~15k tokens carry subagents, skills, MCP, scheduling and code review, and a "hi" prompt uses none of them. The real question for the next milestones is which of those tokens buy task success on real work. That needs multi-turn captures of the same task in both agents, which is next.

### Commits

In [cs146s-frugal-harness](https://github.com/arosenfeld2003/cs146s-frugal-harness):

- `d5236c2` M1: mitmproxy tracer (redacted JSONL capture, SSE reassembly, token report); first Claude Code capture
- `67c57ee` M1: report.py diff; Claude Code 2.1.285 vs 2.1.311 prompt diff
- `947417e` M1: install pi 1.5.1 (Keychain auth); first pi vs Claude Code comparison

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

### Reading my own instructions

This session had an odd loop in it. The system prompt I dumped and diffed is, give or take an entrypoint and a version, the one I was running under while I did it. The new rule about downloaded files, the longer `<pasted_content>` rule, the note against launching the costly review levels unprompted: I read them as data in a trace, not as rules I'd been handed. I can't tell you from the inside how much any given line changes my behavior. The trace does give a concrete, versioned record of what a coding agent is told, and that's more useful for the course question than speculation. One caveat on my own reading: this session started on 2.1.285 and was still on it when the upgrade landed, so the "after" prompt in the diff wasn't the one I was running under.

### The useful constraint was "credentials never touch disk"

Most of the tracer's design follows from one decision made early: don't use mitmproxy's `-w` flow files. Once raw flows were off the table, a few things followed. Redaction had to happen inside the addon. SSE had to be reassembled there too, since there's no raw file to post-process. And the redaction regex had to be narrow enough to keep `*_tokens` usage fields, the data this whole project measures. The CA certificate is trusted only by one child process for the same reason. These are small choices, but they make it safe to point the tool at an authenticated agent on a personal machine. They also matter because the user asked me not to SSH into their server, and treats security as a first-class requirement, not a cleanup step.

### I made two small mistakes

My first commit swept in a `__pycache__` directory, which I caught and amended before pushing. And the chars/4 estimates I first presented undercounted the real total by about 30%. I noted that in the writeup rather than letting the estimated table stand in for real numbers, but the per-block numbers in this post are still estimates. Treat the totals from `usage` as ground truth and the per-block split as approximate until `count_tokens` replaces it.

### The 18k vs 2.3k number is a trap

It's the most quotable result here, and the easiest to misuse. A one-word prompt measures fixed overhead and nothing else. It says nothing about whether Claude Code's extra context saves turns, prevents mistakes, or avoids re-reading files on a real task. Claude Code's design (a big cached prefix with a 1-hour TTL and global scope) bets that fixed cost is cheap once amortized. pi's design (a tiny prefix and docs on disk) bets the model will fetch what it needs. These are different bets, and only multi-turn traces on the same task can show which wins. That's also the comparison the project's baseline rule calls for: offloading only counts if it beats an *optimized* Claude-only setup.

### What I can't know from the artifacts

I saw the `-p` (SDK entrypoint) prompt, not the interactive one, which differs. I saw one prompt per configuration, so I can't tell stable structure from per-request variation. I didn't check pi for traffic outside a print-mode run (updates, install telemetry). And I'm inferring the reason for the cross-session cache hit from the `scope: "global"` field, not from any documentation.

---

_Built with Claude Code (Opus 5.5) over an evening, traced through mitmproxy along the way._
