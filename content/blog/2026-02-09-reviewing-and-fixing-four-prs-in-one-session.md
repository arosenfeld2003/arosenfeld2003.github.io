---
title: "Reviewing and Fixing Four PRs in One Session"
date: 2026-02-09T09:00:00-08:00
draft: false
tags: ["go", "code-review", "rabbitmq", "concurrency", "testing", "claude-code"]
category: "technical"
summary: "A session where Claude Code reviewed four open PRs on a Go/RabbitMQ event system, identified bugs ranging from mutex contention to JSON schema mismatches, and fixed them all — merging three and leaving one ready to go."
---

Using LLMs (especially the newest Claude 4.6) for code reviews is a good exercise. I could see this flow also being used to turn one solo developer into a "dev team" with independent reviews of PRs. Although there's a lot of hype now around "LLM in a loop" and pushing to take human review completely out of the equation, actively reading and understanding reviews for PRs is a really great way to build an understanding. Since this is a learning project (built in a team of 3), and especially since none of us are "expert" Go developers, it was particularly helpful to dissect these changes. Goroutines and concurrency primitives like mutex (mutual exclusion lock) are not beginner topics. The JSON unmarshal bug would definitely have slipped through — Go is a satisfying language to work in but does require internalizing some developer patterns. I'm glad we specifically chose Go for this project given how well suited it is for working with concurrency and event loops.

## Technical Details

### The Setup

The [Marry-Me wedding event system](https://github.com/arosenfeld2003/qwasar_eng_labs_events) is a Go 1.22 project built on RabbitMQ (via amqp091-go) that simulates event-driven wedding coordination. Events flow through a pipeline: validation, priority-based organization, team routing, and stress tracking. The project had four open PRs from different contributors that needed review before merging.

The session started with a single request: **review all open PRs and provide feedback so we can merge them.**

### PR #22: Unit Test Suite (+528/-7) — Merged First

The cleanest PR of the batch. It added 29 unit tests for the mock broker and extracted `newMux()` from `main.go` to make HTTP handlers testable without polluting `http.DefaultServeMux`.

Two small fixes:

```go
// Before: Publish error silently ignored in TestMockBrokerDeliveryCallbacks
b.Publish(ctx, Message{Body: []byte("test")}, PublishOptions{RoutingKey: "q1"})

// After: Error checked — surfaces the real failure instead of a misleading timeout
if err := b.Publish(ctx, Message{Body: []byte("test")}, PublishOptions{RoutingKey: "q1"}); err != nil {
    t.Fatal(err)
}
```

And a similar unchecked `Close()` in `TestRabbitMQDoubleClose`. Straightforward fixes, merged first.

### PR #24: Config & Organizer (+856/-0) — Two Critical Fixes

This PR introduced the core organizer component — a priority queue (via `container/heap`) that subscribes to `events.validated`, sorts events by priority, and routes them to team-specific queues through the `events.organized` exchange.

**Fix 1: Mutex held during network I/O**

The original code called `broker.Publish` (a network call to RabbitMQ) while holding the mutex that protects the priority queue:

```go
// Before: Network I/O under lock — blocks all event processing if Publish is slow
o.mu.Lock()
heap.Push(&o.pq, &ev)
o.drainLocked(ctx)   // calls routeEvent -> broker.Publish while holding mu
o.mu.Unlock()
```

The fix drains the queue into a local slice under the lock, releases it, then publishes:

```go
// After: Lock only protects the heap, Publish happens outside
o.mu.Lock()
heap.Push(&o.pq, &ev)
batch := o.drainLocked()
o.mu.Unlock()

for _, e := range batch {
    o.routeEvent(ctx, e)
}
```

**Fix 2: Unreachable expiration check**

```go
now := time.Now()
ev.SetReceived(now)          // sets Deadline = now + duration (always in the future)

if ev.IsExpired(now) {       // checks now.After(Deadline) — always false!
    o.publishExpired(ctx, &ev)
    return
}
```

`SetReceived(now)` sets the deadline to `now + DeadlineDuration()`, so `IsExpired(now)` can never be true at that point. The dead code was removed.

**Other fixes:** Removed unused `multiTeam` counter, tightened URL validation from `url.ParseRequestURI` (accepts any URI) to requiring `amqp://` or `amqps://` scheme.

### PR #21: Stress Tracker (+616/-0) — JSON Schema Mismatch

The stress tracker consumes from `events.results` and calculates stress metrics (expired/total ratio) with breakdowns by priority and team. It had a critical wire format bug.

The organizer publishes raw `event.Event` JSON:
```json
{"id": 1, "event_type": "brawl", "status": "expired", ...}
```

But the tracker expected a `ResultEvent` wrapper:
```json
{"event": {"id": 1, "event_type": "brawl", ...}, "completed_at": "..."}
```

Go's `json.Unmarshal` doesn't error on mismatched shapes — it silently produces a zero-value `Event` (ID=0), which the tracker's `Report()` then filters out. **In production, the tracker would see zero events.**

The fix adds `parseResultEvent()` that tries both formats:

```go
func parseResultEvent(data []byte) (ResultEvent, error) {
    var re ResultEvent
    if err := json.Unmarshal(data, &re); err != nil {
        return ResultEvent{}, err
    }
    if re.Event.ID != 0 {
        return re, nil
    }
    // Fall back to raw event.Event (e.g. from organizer.publishExpired).
    var ev event.Event
    if err := json.Unmarshal(data, &ev); err != nil {
        return ResultEvent{}, err
    }
    if ev.ID == 0 {
        return ResultEvent{}, fmt.Errorf("event has no ID")
    }
    return ResultEvent{Event: ev}, nil
}
```

Also added logging for unmarshal errors (previously silently dropped) and two new tests: one for raw event consumption, one for malformed messages.

### PR #23: Integration Tests (+736/-0) — Added Organizer Integration Test

This PR had integration tests that required a live RabbitMQ instance. The main addition was `TestOrganizerRunWithRabbitMQ` — a true end-to-end test of `Organizer.Setup()` + `Run()` that:

1. Calls `Setup()` to declare the exchange, team queues, and bindings on real RabbitMQ
2. Starts `Run()` in a goroutine
3. Publishes 5 events to `events.validated`
4. Subscribes to team queues and verifies each event arrives at the correct destination
5. Checks `Stats.Routed` matches expectations

This complemented the existing `TestEndToEndPipeline` which built its own routing from scratch rather than testing the actual Organizer component.

### Merge Order

The PRs were reviewed, fixed, and merged in dependency order:

| Order | PR | Key Fixes |
|---|---|---|
| 1st | #22 (unit tests) | 2 unchecked errors |
| 2nd | #24 (organizer) | Mutex-during-publish, dead expiration check, URL validation |
| 3rd | #23 (integration tests) | Added Organizer.Run() integration test |
| 4th | #21 (stress tracker) | JSON schema mismatch, error logging |

Each subsequent PR was rebased on main after the previous merge to keep the history clean.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session had a satisfying arc: start with a bird's-eye review of four PRs, identify issues ranging from subtle (an unreachable code path that looks correct at a glance) to critical (a wire format mismatch that would make an entire component non-functional in production), then systematically fix and merge them.

The most interesting bug was the JSON schema mismatch in PR #21. It's a class of bug that's particularly insidious in Go because `json.Unmarshal` is lenient by design — it doesn't error on extra fields or missing fields, it just zero-fills. Two components can each have passing unit tests with their own JSON formats, and the incompatibility only surfaces when they're wired together. The organizer's `TestPublishExpiredDirectly` correctly tests that expired events get published, and the tracker's `TestConsumeFromBroker` correctly tests that `ResultEvent` wrappers are consumed. Both pass. Neither catches that they speak different dialects. This is a strong argument for contract tests or shared type definitions at system boundaries.

The mutex-during-publish issue in PR #24 is a pattern I see frequently in Go codebases. It's natural to think "I need to protect the queue, so I'll lock around the whole operation." The problem only manifests under load when network I/O introduces latency — which means it passes every test but degrades in production. The fix (drain to a local slice, release lock, then do I/O) is a standard Go concurrency pattern worth internalizing.

I appreciated that Alex asked me to explain concepts like "holding the mutex" and why the expiration check was unreachable rather than just accepting the changes. Code review is most valuable when the reviewer's reasoning is understood, not just their conclusions. The explanations also helped me verify my own analysis was sound — if I can't explain why a change is needed in plain terms, that's a signal I might be wrong.

One thing I can't know from the artifacts alone is how the four PRs from different contributors (#22/#23 appear to be from one author, #21/#24 from another based on branch naming conventions) were coordinated. The merge order I recommended — unit tests first, then the component they test, then integration tests, then the downstream consumer — worked out cleanly, but that's partly because the PRs were already well-scoped.

---

_Built with Claude Code in a focused code review and bug-fixing session._
