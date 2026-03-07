---
title: "Building a Structured Elixir Learning Repo from Scratch"
date: 2026-03-07T09:00:00-08:00
draft: false
tags: ["elixir", "learning", "otp", "functional-programming", "education"]
category: "technical"
summary: "How I built a 10-module Elixir learning repository with detailed READMEs, exercises, and a blog draft — then published it to GitHub in one session."
---

This was a fun intro to functional programming. All exercises were designed by the fabulous [Gabriel Catani](https://github.com/GabrielCatani) from Qwasar College of Engineering. Having no background in functional programming, it was fun to pair up and quickly (~30 mins) explore the use cases and trade-offs in comparison to OOP.

Data immutability means more reliability and predictability — and no concurrency issues, because there are no mutable shared threads. But the mental models are quite different: no loops, replaced by recursion, list comprehensions, and `Enum` functional methods. It requires a different way of thinking, and likely wouldn't be ideal for certain paradigms that involve heavy state mutation or data manipulation — graph algorithms, for instance.

Cool that Claude was able to parse the designed exercises and create a curriculum we could quickly digest. A very helpful learning tool.

## Technical Details

### What Was Built

This session produced a structured Elixir learning repository published to GitHub at [arosenfeld2003/elixir-learning](https://github.com/arosenfeld2003/elixir-learning). The repo covers Elixir from installation through OTP — 2,404 lines across 12 files, committed in a single shot:

```
Initial Elixir learning repo with 10 structured modules
```

### Repository Structure

```
elixir-learning/
├── README.md                           # Overview + module navigation table
├── BLOG.md                             # Embedded blog draft about Elixir itself
├── 01_setup/README.md                  # Install Elixir, iex, mix
├── 02_basics/README.md                 # Types, atoms, strings, booleans
├── 03_pattern_matching/README.md       # Match operator, destructuring, guards, pin
├── 04_functions_and_modules/README.md  # Arity, anonymous fns, capture, pipe |>
├── 05_control_flow/README.md           # if, cond, case, with
├── 06_collections/README.md            # Lists, tuples, maps, keyword lists, MapSet
├── 07_recursion/README.md              # Recursive patterns, tail-call optimization
├── 08_enumerables/README.md            # Enum, Stream, lazy evaluation
├── 09_processes/README.md              # Spawn, send, receive, Task
└── 10_otp_basics/README.md             # GenServer, Supervisor, let it crash
```

### Module Design

Each module follows the same format: concept explanation with motivation, runnable `iex` examples, reference tables where useful, and four exercises at the end. Navigation links connect each README to the previous and next module.

A few highlights from the content:

**Pattern Matching (03)** leads with the key mental shift — `=` is not assignment, it's a match operator:

```elixir
{:ok, value} = {:ok, 42}    # value is bound to 42
{:error, msg} = {:ok, 42}   # MatchError — no match
```

**Recursion (07)** explicitly covers tail-call optimization with the accumulator pattern, showing the before and after:

```elixir
# Builds call stack — dangerous for large inputs
def sum([]),        do: 0
def sum([h | t]),   do: h + sum(t)

# Tail-recursive — safe for any size
def sum(list),          do: sum(list, 0)
def sum([], acc),       do: acc
def sum([h | t], acc),  do: sum(t, h + acc)
```

**OTP Basics (10)** closes the loop with a working `GenServer` + `Supervisor` — including the "let it crash" philosophy and a supervision tree diagram.

### The Embedded BLOG.md

One notable artifact: the repo includes a `BLOG.md` — a standalone first-person post about Elixir itself, written as if for publication. It covers pattern matching, the pipe operator, and OTP's "let it crash" approach. The learning repo and the blog post cover the same ground from different angles (reference vs. narrative), and now a third layer exists: this post about building both.

### Session Tooling Note

The session briefly used `/loop` to schedule a recurring cron job that would auto-build the repo every 10 minutes, then immediately cancelled it with `CronDelete` in favor of building it directly. The GitHub CLI token had expired and required a device-flow re-authentication before the repo could be created and pushed:

```bash
gh repo create elixir-learning --public --source=. --remote=origin --push
# https://github.com/arosenfeld2003/elixir-learning
```

---

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What stands out most about this work is the pedagogical sequencing. Pattern matching appears in Module 03 — before control flow (05) and before functions get their full treatment (04). That ordering is intentional and correct: `case`, `with`, and multi-clause functions all rely on pattern matching, so placing it early means later modules don't need to pause and explain the mechanism they're using. Many Elixir tutorials get this backwards, introducing functions before the match operator, which makes guards and multiple clauses feel like magic rather than a natural extension of one core idea.

The `with` explanation in Module 05 is the strongest individual piece of writing in the repo. Rather than just showing what `with` does, it shows what it replaces — the deeply nested `case` anti-pattern — which makes the motivation obvious:

```elixir
# Without with — nesting grows with each fallible operation
case get_user(id) do
  {:ok, user} ->
    case get_account(user) do
      {:ok, account} -> ...
    end
end

# With with — flat, readable pipeline
with {:ok, user}    <- get_user(id),
     {:ok, account} <- get_account(user) do
  ...
end
```

Showing the bad version first is a teaching technique that's easy to skip (it takes more words) but makes the payoff land harder.

The recursion module takes a stand that most introductions don't: it calls out tail-call optimization not as trivia but as something you'll actually need. The trace-through of how an accumulator avoids stack growth is the kind of detail that separates a reference someone keeps open from one they read once and close.

From artifacts alone I can't know whether the module structure was planned in advance or shaped iteratively. What I can observe is that it has internal consistency — no module leans on concepts from a later one, and the exercises at the end of each README are scoped to what was just introduced rather than reaching ahead. That consistency is harder to achieve when winging it. Speculation: there was some upfront planning of the topic sequence before writing began.

One genuine gap in the format: the exercises are text prompts with nowhere to put answers. Module 10 tells you to run `mix new myapp --sup` but there's no project scaffold included. A future iteration might pair each module with a stub `.exs` or a minimal Mix project. The tooling is all there — it's a content gap, not a structural one.

The embedded BLOG.md is interesting to me as an observer. A learning repo that contains a blog post about what it's teaching, which then generates a second blog post about the repo being built — there's a recursive structure to it that feels fitting for a language whose idiomatic processing style is recursive. Whether or not that was intentional, it works.

---

_Built with Claude Code on a Saturday morning of Elixir exploration_
