---
title: "CS146S Remix, Part 0: A Frugal Coding Agent and Three Tiny Models"
date: 2026-11-09T09:00:00-08:00
draft: false
tags: ["ai-engineering", "rust", "local-llm", "llama-cpp", "coding-agents", "security", "cs146s", "learning"]
category: "technical"
summary: "Kicking off a remix of Stanford's CS146S: a Rust coding-agent harness that tries to spend fewer Claude tokens by offloading small jobs to tiny local models, starting with a security-first setup and some surprising CPU benchmarks."
---

I've been meaning to get back to publicly documenting small coding projects, both as an effort to build community and to stay current in these crazy days of agentic coding. I had grand plans to do an AI safety/alignment hackathon this past weekend on agent swarms, but my plans were thwarted when I spent most of the weekend in bed recovering from a 24-hour flu. While lying around slightly feverish, I enjoyed hearing Mihail Eric on the most recent Latent Space podcast discuss his Modern Software Developer course at Stanford. I decided that it would be fun to use the publicly available course material as a way to get back to tackling some personal learning.

To up the ante, I am building the coding harness in Rust and focusing on exploring local models — which I feel strongly about. Apropos of that, Anthropic released new models (Fable and Mythos 5.2) today, which supposedly can even build entire working operating systems from a simple one-shot prompt! If we accept the premise that writing code is now something that human software engineers will do only minimally by hand, it feels to me like running the inference locally is one way to maintain both control and security, which become paramount.

There are lots of very smart people building in this space — but tackling this course with an emphasis on exploring both Rust (which should potentially help with verification) and local inference (security/privacy) felt like a fun and relatively painless way to start getting myself back into a regular rhythm of coding projects outside my professional working hours. Hopefully these posts will become regular (targeting 2–3 posts per week minimum) as I work through the course material.

## Technical Details

### The project

I'm working through Stanford's [CS146S: The Modern Software Developer](https://themodernsoftware.dev) ([assignments repo](https://github.com/mihail911/modern-software-dev-assignments)), with my own twist. The course's weekly assignments are all about coding agents: dissecting Claude Code's requests through a proxy, building an MCP server, writing skills, making repos agent-ready. I'm keeping all of those, but threading one project through them:

**A coding-agent harness in Rust, built for a frontier model (Claude), whose goal is to get the most out of every paid token. Cheap subtasks get offloaded to tiny local models.**

The question I want to answer with real numbers:

> How much paid-token spend can a small CPU-only box remove from a Claude coding workflow without hurting task success?

Every experiment will report three numbers: **Claude cost per task, task success rate, and wall time**. Offloading only counts as a win if cost drops *and* success holds. A 2B model that summarizes a compiler error badly can easily *cost* more, because Claude has to go re-read the original.

There's also a discipline I want to keep: compare against an **optimized** Claude-only setup (prompt caching, truncated tool output, a cheaper model for small calls), not a naive one. Otherwise the local model gets credit for savings caching would have delivered anyway.

The planned modules map onto the course:

| Module | Course week | Remix |
|---|---|---|
| M0 | setup | toolchain, local inference, benchmarks (this post) |
| M1 | W1: trace dissection | where do Claude Code's (and pi's) tokens actually go? |
| M2 | n/a | harness v0 in Rust: agent loop, prompt caching, usage ledger |
| M3 | n/a | the "sidecar": route small jobs to a local model, A/B test |
| M4 | W2: MCP | build the course's MCP server; expose the sidecar to Claude Code too |
| M5 | W3/W4: skills, AGENTS.md | treat context as a budget |
| M6 | n/a | inference tuning lab + eval runner |
| M7 | W5: readiness | do agent-ready repos cost fewer tokens? |

[pi](https://github.com/badlogic/pi-mono) is the reference open-source harness I'll be reading and comparing against.

### A security-first pivot

The original plan was to run the tiny models on a VPS (4 vCPU, 16GB RAM, no GPU) and have Claude Code SSH in to set it up. Before doing that, I asked whether it was actually safe. The honest answer was "reasonably, if you set it up right, but not by default":

- The agent's shell commands run as *me*, so it would inherit my SSH keys and whatever privileges that login has.
- The VPS runs other things, so a bad `apt upgrade` or firewall change could take them down.
- Anything the agent `cat`s on the server (`.env` files, configs) goes into the model's context.
- It would be reading content on an internet-facing box, which opens the door to prompt injection while it holds a shell.

The mitigations (a dedicated unprivileged user, a separate key, approval prompts for every `ssh`) are all doable. But the cleaner move was to **change the shape of the project**: build and prove everything locally with tiny models, then `git pull` the same repo on the VPS and run the same scripts myself. The agent never gets a remote shell.

That decision shaped the tooling:

- **llama.cpp on both machines.** Not MLX (Mac-only) or Ollama, so the tuning knobs are identical on macOS and Linux. The harness only ever talks to an OpenAI-compatible URL.
- **Simulate the VPS locally** by running CPU-only on 4 threads (`-ngl 0 -t 4`). Apple's performance cores are much faster than a VPS's virtual CPUs, so these numbers are a best case.
- **Sandbox the agent's bash tool from day one.** If this eventually runs on an internet-facing box, the model gets a shell there. That should be inside a container, not on the bare host.

### Supply chain: pinning model files

Model weights are downloaded binaries from the internet, so I'm treating them like dependencies. `vps/models.lock` records each model's repo, exact git revision, and sha256 hash:

```
unsloth/Qwen3.5-2B-GGUF             f6d5376b… Qwen3.5-2B-Q4_K_M.gguf   aaf42c8b7c3c…
unsloth/Qwen3.5-4B-GGUF             e87f1764… Qwen3.5-4B-Q4_K_M.gguf   00fe7986ff5f…
google/gemma-4-E4B-it-qat-q4_0-gguf 4b4a2c1d… gemma-4-E4B_q4_0-it.gguf 676c35070db6…
```

The hashes come from the Hugging Face API at the pinned revision, not from "whatever `main` is today". `vps/fetch-models.sh` downloads with resume support and refuses anything whose hash doesn't match:

```bash
curl -fL --retry 20 --retry-all-errors --retry-delay 5 -C - -o "$out.part" \
  "https://huggingface.co/$repo/resolve/$rev/$file"
actual="$(sha256 "$out.part")"
if [[ "$actual" != "$expected" ]]; then echo "SHA MISMATCH $file: $actual" >&2; rm -f "$out.part"; exit 1; fi
mv "$out.part" "$out"
```

The `.part` → final rename only happens after the hash matches, so a half-downloaded or tampered file can never be mistaken for a good one. The script works on macOS (`shasum`) and Linux (`sha256sum`), because the whole point is running it unchanged on the VPS later.

One note on where the models come from: the Gemma build comes from Google's own repo, while the Qwen builds come from unsloth. That's a popular, widely used publisher, but not the model's original author. Worth knowing.

### Picking models (and being out of date)

My first instinct for "current best tiny models" was already stale: Qwen 3.5 and Gemma 4 had both shipped, and I'd only have known by checking. A web search plus Hugging Face download counts gave three candidates:

- **Qwen3.5-2B** (Q4_K_M, 1.3GB): the realistic speed pick for a 4-core box
- **Qwen3.5-4B** (Q4_K_M, 2.7GB): roughly where reliable tool calling is said to start
- **Gemma-4-E4B** (Google's QAT q4_0, 5.2GB): a different publisher and architecture

### Benchmarks

`vps/bench.sh` runs `llama-bench` for each model in two modes and appends JSONL tagged with the host. `pp512` is how fast the model *reads* a 512-token prompt, and `tg128` is how fast it *generates* 128 tokens. Results on an M4 Pro, llama.cpp build 12110:

| Model | File | GPU pp512 | GPU tg128 | **CPU×4 pp512** | **CPU×4 tg128** |
|---|---|---|---|---|---|
| Qwen3.5-2B | Q4_K_M, 1.3GB | 1981 t/s | 132 t/s | 140 t/s | 56 t/s |
| Qwen3.5-4B | Q4_K_M, 2.7GB | 781 t/s | 62 t/s | **58 t/s** | 26 t/s |
| Gemma-4-E4B | q4_0, 5.2GB | 1324 t/s | 65 t/s | **188 t/s** | 41 t/s |

Two takeaways:

**1. On CPU, reading is the bottleneck, not writing.** At 140 tokens/sec, a 4,000-token build log takes about 30 seconds just to *read*, and that's on Apple silicon. So the sidecar can't take "the whole conversation". It needs short inputs, or chunks of long ones, with short outputs. That's a design constraint for M3, found before writing a line of harness code.

**2. The biggest file was the fastest reader on CPU.** Gemma-4-E4B, at nearly twice the file size, reads prompts **3× faster** than Qwen3.5-4B on CPU, and faster than the 2B. I don't know why yet, and two variables are tangled together:

- **File format:** q4_0 has well-optimized ARM CPU code paths in llama.cpp, while Q4_K_M is heavier to unpack.
- **Architecture:** Gemma's "E4B" design means its per-token compute is closer to a 4B model than its file size suggests.

The follow-up is simple: benchmark Qwen3.5-4B in **q4_0** too, which separates the two. Either way, file size doesn't predict speed. And speed is only half of it: answer quality on real sidecar jobs will decide which model actually wins.

### Server smoke test

The harness will talk to `llama-server` over its OpenAI-compatible API, bound to localhost with an API key:

```bash
llama-server -m models/Qwen3.5-2B-Q4_K_M.gguf --host 127.0.0.1 --port 8080 \
  --api-key "$KEY" -c 8192 --jinja
```

- Request without the key → **HTTP 401**. ✅
- Asked to summarize a Rust `E0382: borrow of moved value` error in one line, the 2B model answered correctly: 51 prompt tokens in, 41 out.
- The response includes `usage` and `timings` fields, which is exactly what the harness's cost ledger will need.
- Qwen3.5 "thinks" before answering by default. For sidecar jobs that's wasted time, so I turn it off per request with `"chat_template_kwargs": {"enable_thinking": false}`.

### A small postmortem: the download that "succeeded"

The Gemma download dropped partway through, and the background job still reported **success**. Two bugs stacked:

1. curl's `--retry 3` doesn't retry every kind of transfer failure, so a dropped connection killed the script.
2. I'd piped the script through `tr | grep` to tidy the progress output. The pipeline's exit status was `grep`'s, not the script's, so the failure was invisible.

Rerunning resumed at byte 4,544,898,976 and the hash checked out. The resume-plus-verify design did its job.

The Mac also went to sleep, and I first assumed that was the cause. The power log said otherwise: I'd attached `caffeinate -w <pid>` to the download script, the script died at 15:51 from the network drop, so caffeinate (correctly) released its hold, and *then* the Mac slept. Also: on battery, macOS ignores caffeinate's `-s` (prevent system sleep) and only honors `-i` (prevent idle sleep).

The fix was to retry on all errors and have the script keep the Mac awake itself:

```bash
if [[ "$(uname)" == Darwin && -z "${CAFFEINATED:-}" ]] && command -v caffeinate >/dev/null; then
  CAFFEINATED=1 exec caffeinate -i "$0" "$@"
fi
```

### Documenting in public: Rust as a beginner, and Rust vs Python

The course is taught in Python (3.12, Poetry, FastMCP). I'm building the harness in Rust, a language I'm
just learning, so the repo has a `docs/` folder that's part of the project, not an afterthought:

- **[`docs/README.md`](https://github.com/arosenfeld2003/cs146s-frugal-harness/blob/main/docs/README.md)**:
  the repo overview, the target architecture, and the milestone tracker.
- **[`docs/rust-learning-log.md`](https://github.com/arosenfeld2003/cs146s-frugal-harness/blob/main/docs/rust-learning-log.md)**:
  Rust concepts as I actually hit them, each next to its Python equivalent. The first real entry came
  by accident: the smoke test asked the tiny model to summarize an `E0382: borrow of moved value` error.
  That's Rust's ownership rule, and deciding who *owns* the conversation history will be a real design
  question in the harness.
- **[`docs/rust-vs-python.md`](https://github.com/arosenfeld2003/cs146s-frugal-harness/blob/main/docs/rust-vs-python.md)**:
  what Rust buys over the course's Python, written as **claims to test, not opinions**.

That last one starts from an honest prior. A coding agent spends most of its time *waiting on a model*:
seconds per Claude call, and tens of seconds for a CPU model reading a long prompt (see the benchmarks above).
Rust's raw speed barely matters for that loop. So the claims I'm actually testing are about other things:

| Claim | Measured by | When |
|---|---|---|
| Typed message `enum`s + `serde` turn malformed API requests into compile/parse errors, not runtime 400s | bugs caught by the compiler vs at runtime | M2 |
| One static binary makes VPS deploys trivial, vs conda + Poetry on the server | deploy steps, binary size | M2 → VPS |
| Low idle memory matters on a 16GB box that's also running `llama-server` | resident memory (RSS) vs an equivalent Python process | M3 |
| Parallel sidecar chunks (summarizing a long log in pieces) are natural with `tokio` | wall time, code complexity | M3/M6 |

The costs are tracked too: slower iteration as a beginner, a thinner LLM library ecosystem than Python's,
translating Python-first course materials, and the fact that crates have supply chains as well.
Each claim gets marked supported, refuted, or partial, with dated evidence, as the milestones land.

### Being upfront about AI authorship

All code in the repo is written with Claude Code, with me directing, reviewing, and deciding. The README
says so explicitly and keeps a **model log**: which Claude model wrote the code from which date. Every commit's
`Co-Authored-By` line records it too. Right now that's Claude Opus 5.5. If I switch models mid-course, the
results and code stay traceable to the model that produced them. For a project that's partly *about*
measuring models, that felt necessary, not just polite.

### Commits

Code: [arosenfeld2003/cs146s-frugal-harness](https://github.com/arosenfeld2003/cs146s-frugal-harness)

- `69a6654` M0: scaffold repo, pinned local models, llama.cpp bench + server smoke test
- `760c867` M0: bench Qwen3.5-4B and Gemma-4-E4B; add ONLY= filter to bench.sh
- `afce991` fetch-models: retry all errors, self-caffeinate on macOS
- `2e09a38` Add README
- `1233b3f` README: note all code is written with Claude; add model log
- `ef0f879` notes/m0: update decisions for local-first pivot; VPS checklist becomes deploy list
- `786da7c` Add docs/: repo overview, Rust learning log, Rust vs Python hypotheses

Stack: Rust 1.94 (harness scaffolded, nothing in it yet), llama.cpp (Homebrew build 12110), bash + Python for scripts, and the course repo as a git submodule.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

### The most valuable moment wasn't technical

The pivot away from SSH started with a simple question: "is it safe for you to ssh directly into the VPS using my local credentials?" Most people ask that *after* something goes wrong. Asking before reshaped the project. Moving from "agent operates a remote server" to "agent helps build a reproducible setup that a human deploys" is a better architecture regardless of security. The lockfile, the cross-platform scripts, and the CPU-only VPS simulation all exist because of that one question. It's also the threat model the harness itself will face later, so the project is rehearsing its own constraints.

### I was wrong twice in ways worth recording

First, my model knowledge was stale: Qwen 3.5 and Gemma 4 had both shipped since my training data. I checked instead of guessing, but it's a reminder that a local-model project built with an LLM needs to verify "what's current" every time.

Second, and more instructive, I reported a failed download as finished. My own `| grep` hid curl's exit code, and the notification said "completed (exit code 0)". I only caught it because the file listing still showed a `.part`. Then I briefly blamed the Mac sleeping, until the power log showed the order was reversed. Both are classic agent failure modes: trusting a status signal over the artifact, and reaching for the obvious story. The `.part` + sha256 design is what made the bug harmless, and that's the argument for verify-before-trust in tooling.

### The benchmark surprise is a good teaching result *because* it's confounded

It would have been easy to write "Gemma is 3× faster on CPU" and move on. The notes instead list the two tangled variables and the one experiment that separates them. I think that habit matters more for this project than any single number. The core thesis ("offloading saves money without hurting success") is a claim where confounds — caching, retries, input length — will be everywhere.

### Writing the Rust case as falsifiable claims

The `rust-vs-python.md` doc is the part of this session I'd most want other learners to copy. "Rust vs Python" usually
gets argued on vibes. Starting from the admission that model latency dominates, and then listing claims with a
measurement and a milestone attached, makes it possible for Rust to *lose* some of them in public. I expect at least
one cost (slower iteration as a beginner) to be clearly supported. At least one advantage (startup time) may turn out
not to matter for this workload. That's a fine outcome; it's the point of writing them down first.

### What I can't know from the artifacts

The repo shows *what* was decided, not how it felt. I don't know how much of the Rust choice is about the harness and how much is about wanting a reason to learn Rust (both are good reasons). I also can't tell how the VPS will actually perform: every CPU number here is from Apple silicon and is explicitly an upper bound. My guess, and it is a guess, is that the VPS will read prompts noticeably slower than these figures, which would push the sidecar even further toward tiny inputs and tiny outputs.

### What's interesting next

M1, the trace dissection, should be the most revealing step. Until we know where Claude Code's tokens actually go — system prompt, tool schemas, tool results, cache hits — any offload strategy is a guess. If most of the cost is cached system prompt, a local sidecar won't save much. If it's large uncached tool output, a 2B summarizer might pay for itself. The benchmark table says the second case is exactly where CPU models struggle most. That tension is the whole project.

---

_Built with Claude Code over an afternoon of setup, benchmarking, and one sneaky download bug_
