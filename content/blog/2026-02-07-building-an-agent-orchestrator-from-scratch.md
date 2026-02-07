---
title: "Building an AI Agent Orchestrator from Scratch in Python"
date: 2026-02-07T09:00:00-08:00
draft: false
tags: ["python", "agents", "design-patterns", "oop", "testing"]
category: "technical"
summary: "Building a multi-agent system incrementally across 4 assignments — agent loops, pluggable tools, bounded memory with escalation, and orchestration — all in pure Python with 50 tests and zero LLM dependencies."
---

This project spec came from a series of Google Docs developed by the brilliant instructors at [Qwasar Silicon Valley](https://www.qwasar.io/). We do a coding collab, and the topic this week was AI agent architecture — including an orchestrator. As a proof of concept, my team of three simply copy-pasted the entire context from 5 different Google Docs into Claude Code and let it cook.

It was a perfect demonstration of where we are, and how quickly the idea of a "software engineer" is evolving. We were on a timer, and within 30 minutes had this entire GitHub repository pushed — 50 tests passing, 4 demo scripts running, clean OOP with design patterns, and a detailed README. A fun project, and a striking snapshot of what AI-assisted development looks like in early 2026.

## Technical Details

### The Project

The [agent_orchestrator](https://github.com/arosenfeld2003/agent_orchestrator) project is a learning-oriented codebase that builds a multi-agent system incrementally across 4 assignments. Each assignment introduces a core AI agent concept and extends the same codebase, with all prior tests continuing to pass at each stage. The entire system is built in pure Python with no LLM dependencies — the goal is to understand agent fundamentals through clean OOP.

The final system has 50 tests across 4 test files and 4 demo scripts.

### Assignment 1: The Agent Loop

The foundation is a deterministic `perceive → decide → act` loop. The `Agent` class tracks its lifecycle state (`idle → perceiving → deciding → acting → idle`) and classifies input based on whether it contains the word "error" (case-insensitive):

```python
class Agent:
    def __init__(self, name: str):
        self.name = name
        self.state = "idle"

    def perceive(self, input_data: str) -> None:
        self.state = "perceiving"
        self._current_input = input_data

    def decide(self) -> str:
        self.state = "deciding"
        if "error" in self._current_input.lower():
            self._current_classification = "issue"
        else:
            self._current_classification = "normal"
        return self._current_classification

    def run(self, input_data: str) -> dict:
        self.perceive(input_data)
        classification = self.decide()
        action = self.act()
        return {"input": input_data, "classification": classification, "action": action}
```

### Assignment 2: Strategy Pattern for Tools

The agent gains pluggable tools via an abstract `Tool` base class. Each tool declares what classification it handles through a `matches()` method, and the agent selects the appropriate tool at decision time:

```python
class Tool(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def execute(self, data: str) -> dict: ...

    @abstractmethod
    def matches(self, classification: str) -> bool: ...
```

Two concrete tools — `KeywordScannerTool` (for issues) and `WordCountTool` (for normal input) — demonstrate the pattern. The critical design choice: the agent constructor accepts `tools=None`, so all Assignment 1 tests continue to pass without modification.

### Assignment 3: Memory and Escalation

A `Memory` class with bounded capacity is dependency-injected into the agent. The escalation logic checks the last 3 memory entries — if 2 or more were classified as `"issue"`, the current input escalates to `"critical"`:

```python
# In Agent.decide()
recent = self._memory.recall(3)
issue_count = sum(1 for e in recent if e.get("classification") == "issue")
if self._current_classification == "issue" and issue_count >= 2:
    self._current_classification = "critical"
```

This creates emergent behavior: isolated errors stay as `"issue"`, but a pattern of repeated errors triggers escalation.

### Assignment 4: The Orchestrator

The `Orchestrator` implements the Mediator pattern — agents communicate through it rather than knowing about each other. It routes `Message` dataclass objects, logs an `ExecutionTrace`, and supports automatic chain-routing:

```python
# When an agent classifies as "critical", it addresses its response to ReviewerAgent
# The orchestrator detects this and chain-routes automatically
if response.recipient in self._agents and response.recipient != message.sender:
    message = response
    continue  # chain-route to next agent
```

The execution trace captures every routing, decision, and tool usage event:

```
[Orchestrator] Message from orchestrator to AnalyzerAgent
[Orchestrator] Classified as critical
[Orchestrator] AnalyzerAgent → KeywordScannerTool
[Orchestrator] Message from AnalyzerAgent to ReviewerAgent
[Orchestrator] Classified as issue
[Orchestrator] ReviewerAgent → KeywordScannerTool
```

### Design Patterns

Four design patterns hold the system together:

| Pattern | Where | Purpose |
|---------|-------|---------|
| **Strategy** | `Tool` ABC + `matches()` | Runtime tool selection without hardcoding |
| **Dependency Injection** | `tools` and `memory` in Agent constructor | Testable, swappable components |
| **Mediator** | `Orchestrator` | Decoupled agent communication |
| **Template Method** | `perceive → decide → act` | Fixed skeleton, each step evolves independently |

### Test Coverage

Each assignment adds tests while all prior tests continue to pass:

- **Assignment 1**: 14 tests — state transitions, classification, case-insensitivity, full cycle
- **Assignment 2**: 14 tests — tool isolation, matches logic, agent delegation, backwards-compatibility
- **Assignment 3**: 12 tests — memory capacity/eviction, recall, search, escalation rules
- **Assignment 4**: 10 tests — routing, chaining, trace logging, discovery, broadcast

Repository: [github.com/arosenfeld2003/agent_orchestrator](https://github.com/arosenfeld2003/agent_orchestrator)

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What stands out about this project is the discipline of the incremental design. Each assignment adds a concept — tools, memory, orchestration — but the key constraint is that every new feature is introduced as an optional parameter with a `None` default. This means the `Agent` constructor evolves from `__init__(self, name)` to `__init__(self, name, tools=None, memory=None)` over three assignments, and no prior test ever needs to be touched. That's a small detail that reveals a deliberate pedagogical structure: the codebase teaches backwards-compatible API evolution by construction.

The choice to build this without any LLM is interesting. The perceive-decide-act loop, tool selection via `matches()`, memory-based escalation, and message routing between agents — these are all patterns that appear in real LLM agent frameworks (LangChain, CrewAI, AutoGen), but here they're fully deterministic and inspectable. You can trace exactly why an input was classified as "critical" by looking at the memory entries. There's no black box. I think this is a genuinely effective way to learn agent architecture before adding the complexity of language model inference.

The escalation logic is the most nuanced piece. The `decide()` method first classifies the current input, then queries memory for the last 3 entries, counts how many had `"issue"` classification, and only then decides whether to upgrade to `"critical"`. The ordering matters — `perceive()` stores the raw input to memory first, then `decide()` classifies and updates that memory entry with the final classification. This two-phase write means the memory entry is built up across method calls, which is a pattern that requires careful sequencing to get right.

One thing I notice from the artifacts: the entire implementation — all 4 assignments, 50 tests, 4 demo scripts, README, and project config — was built in a single session and committed as one unit. The commit message describes it as incremental across 4 assignments, but the git history shows it materialized all at once. This is fine for a learning project, but it's worth noting that the "incremental build" experience would feel different if each assignment were its own commit with tests run in between. The plan called for that workflow, and while the code is structured to support it, the actual development was more of a single pass.

The Orchestrator's `max_hops` parameter on `route()` is a small but important safety detail — without it, a cycle in agent forwarding (Agent A forwards to Agent B, which forwards back to Agent A) would loop forever. The default of 5 hops is reasonable for a teaching project. In production systems, this kind of loop prevention is critical and often handled with more sophisticated mechanisms like message deduplication or TTL fields.

---

_Built with Claude Code in a single session of incremental implementation._
