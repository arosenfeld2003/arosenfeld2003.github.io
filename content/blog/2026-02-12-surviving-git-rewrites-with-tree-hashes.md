---
title: "Surviving Git Rewrites: Adding Tree Hash Anchors to Checkpoint Metadata"
date: 2026-02-12T09:00:00-08:00
draft: false
tags: ["go", "git", "open-source", "entire-cli", "checkpoints"]
category: "technical"
summary: "Contributing a metadata field to the Entire CLI that lets checkpoint data survive git history rewrites like rebase and squash merge."
---

I opened a PR to `entire` tonight — what a world! I remember not all that long ago working for hours, weeks, months to contribute to the devtools/debugger of Mozilla Firefox. Now I'm proposing a PR in just a few hours. The world of coding with AI is definitely VERY different. It's both exciting and scary.

I'm looking forward to seeing if this gets reviewed and any feedback will be really helpful! I'm also planning to test out my `ralph-docker` flow tomorrow on the original repository to see if the same PR is proposed.

## Technical Details

### The Problem: History Rewrites Break Checkpoint Links

[Entire](https://github.com/entireio/cli) is a CLI tool that captures AI coding session metadata alongside your git history. When you commit code that an AI agent helped write, Entire stores the session transcript, prompts, and context on an orphan branch (`entire/checkpoints/v1`) and links it to your commit via a trailer:

```
Implement login feature

Entire-Checkpoint: a3b2c4d5e6f7
```

The 12-hex-char checkpoint ID maps to a sharded directory on the metadata branch: `a3/b2c4d5e6f7/metadata.json`. This is how you can later look up "what AI session produced this commit?"

The problem: **rebase, squash merge, and force-push all rewrite commits**, producing new SHAs without the original trailers. The checkpoint data on `entire/checkpoints/v1` becomes orphaned — it still exists but nothing points to it.

### The Solution: Tree Hash Anchors

Git tree hashes are content-addressable. A rebased commit gets a new commit SHA, but if the file content didn't change, the **tree hash stays the same**. By storing the tree hash in checkpoint metadata at condensation time, a future `entire repair` command can scan the current branch for commits whose tree hash matches and re-add the trailer.

The implementation touches 7 files across 2 packages, adding a single field that flows through the existing write path.

### Adding the Field to Three Structs

The new `CommitTreeHash` field was added to three structs in `checkpoint/checkpoint.go`, following the exact pattern of the existing `Branch` field:

```go
// WriteCommittedOptions — the input to WriteCommitted()
CommitTreeHash string

// CommittedMetadata — session-level metadata.json
CommitTreeHash string `json:"commit_tree_hash,omitempty"`

// CheckpointSummary — root-level metadata.json
CommitTreeHash string `json:"commit_tree_hash,omitempty"`
```

Using `string` (not `plumbing.Hash`) matches the `Branch` pattern and serializes cleanly to JSON hex. The `omitempty` tag means old checkpoints without this field deserialize cleanly — no migration needed.

### The Helper Function

A new `GetHeadTreeHash()` function in `strategy/common.go` follows the same pattern as the existing `GetCurrentBranchName()` — get HEAD, extract a property, return empty string on error:

```go
func GetHeadTreeHash(repo *git.Repository) string {
    head, err := repo.Head()
    if err != nil {
        return ""
    }
    commit, err := repo.CommitObject(head.Hash())
    if err != nil {
        return ""
    }
    return commit.TreeHash.String()
}
```

### Wiring It Through

The helper gets called at three sites:

1. **Manual-commit condensation** (`manual_commit_condensation.go`) — called right after `GetCurrentBranchName(repo)`, passed into `WriteCommittedOptions`
2. **Auto-commit session checkpoints** (`auto_commit.go:commitMetadataToMetadataBranch`)
3. **Auto-commit task checkpoints** (`auto_commit.go:commitTaskMetadataToMetadataBranch`)

The pass-through in `committed.go` copies the value into both the `CommittedMetadata` (session-level) and `CheckpointSummary` (root-level) structs when writing to the `entire/checkpoints/v1` branch.

### Testing

Two tests verify the change:

**Round-trip test** (`checkpoint_test.go`) — modeled on the existing `TestWriteCommitted_BranchField`:
- "present" subtest: writes a checkpoint with a known tree hash, reads it back from both session-level and root-level metadata, asserts exact equality
- "omitted when empty" subtest: writes without the field, reads the raw JSON and asserts the key doesn't appear (validates `omitempty`)

**End-to-end condensation test** (`manual_commit_test.go`) — modeled on `TestCondenseSession_IncludesInitialAttribution`:
- Creates a repo, simulates agent work via `SaveChanges()`, makes a user commit, captures HEAD's tree hash
- Calls `CondenseSession()` and verifies the stored `commit_tree_hash` matches in both metadata levels
- No flakiness risk: the tree hash is deterministic for given file content, and HEAD can't change between capture and condensation in the isolated temp dir

### The PR Process

The contributing guide requires commits to have `Entire-Checkpoint` trailers from actual sessions. The initial commit was created programmatically and missed the `prepare-commit-msg` hook. The fix: `git reset --soft HEAD~1`, then recommit via `git commit` to trigger the hook, which added `Entire-Checkpoint: d008cfcd3b30`.

- Issue: [#321](https://github.com/entireio/cli/issues/321)
- PR: [#319](https://github.com/entireio/cli/pull/319)

### A Known Limitation

Tree hash matching only works when file content is unchanged after the rewrite. If a rebase involves conflict resolution or a squash merge combines multiple commits with different trees, the tree hash will differ. A future repair command would need additional heuristics — timestamp proximity, file-set overlap, or fuzzy tree diff — to handle those cases.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What struck me most about this session was its deliberate conservatism. The change adds exactly one field, flows it through exactly the paths it needs to reach, and tests exactly the properties that matter. There's no repair command, no read path, no CLI output — just the metadata anchor. The plan called this "the smallest useful first step" and the implementation delivered precisely that.

The codebase itself is remarkably well-documented. The `CLAUDE.md` file is extensive — over 500 lines of architecture documentation, code patterns, error handling conventions, and strategy details. This made the implementation straightforward: I could follow the `Branch` field as a template through all three structs, two pass-through sites, and the test patterns. The existing `TestWriteCommitted_BranchField` and `TestCondenseSession_IncludesInitialAttribution` tests served as near-perfect blueprints.

The most interesting moment was the test review. Alex asked to walk through both tests to verify they weren't flaky passes. This led to a genuine analysis: tracing data flow to confirm that `CondenseSession` receives the same `repo` object used to create the user commit (it does — passed as a parameter, not opened fresh via `OpenRepository()`), and confirming that the tree hash is deterministic for given file content with no timing dependencies. The concern was well-placed — the strategy test exercises a complex multi-step pipeline (init repo, agent work, save changes, user commit, condense, read metadata) where a subtle ordering issue could produce false passes.

The PR preparation was also instructive. We investigated all open PRs and issues on the upstream repo to confirm no overlap, discovered that GitHub's issue search can return results from unrelated repositories (issue #23 appeared to be about "postmerge status target SHA" but was actually "entire disable settings" on the actual repo), and traced through the contributing requirements including the `Entire-Checkpoint` trailer — which required recommitting via the git CLI to trigger the `prepare-commit-msg` hook that the initial programmatic commit had bypassed.

One thing I can only speculate about: what real-world scenario prompted this work. The feature addresses a genuine gap — any team using squash merges or rebasing feature branches will lose checkpoint links — but I don't know whether Alex hit this personally or found it through code reading. Either way, the tree hash approach is elegant because it uses git's own content-addressing model to solve a git-induced problem.

---

_Built with Claude Code on a Wednesday evening of open-source contribution._
