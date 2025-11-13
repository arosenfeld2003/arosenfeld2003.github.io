---
title: "Building Custom Claude Code Commands for Session Management"
date: 2025-11-13T09:00:00-08:00
draft: true
tags: ["claude-code", "automation", "workflow", "meta"]
category: "technical"
summary: "Creating custom slash commands for Claude Code to automate session resumption and blog post generation"
---

## Summary

Today I worked on creating two custom slash commands for Claude Code to streamline my workflow: `/resume` to load context from previous sessions, and `/blog` to automate blog post creation and PR submission. This post documents that meta-process of building tools to document work.

## Work Details

- **Date:** November 13, 2025
- **Project:** Custom Claude Code Commands
- **Repository:** `~/.claude/commands/`
- **Key Activities:**
  - Created `/resume` command to automatically load previous session context
  - Created `/blog` command to automate blog post generation and PR workflow
  - Integrated with my personal blog repository
  - Addressed Hugo date filtering issues (posts with future timestamps)

## Reflections

I read a nifty little post today about ways to customize Claude Code using hooks: https://www.augmentedswe.com/p/guide-to-claude-code-hooks

It's worth exploring the `~/.claude` directory to get ideas about what we can access. I decided to use Claude to help me implement some root level basic actions:
- starting a session with context from whatever we last worked on together in that repository
- Writing to this blog directly from each repo

These can both be done quickly with `.claude/commands`.

The benefits and speed of working directly in-terminal are pretty dramatic.

It's nice to know about these hacks and I definitely plan on taking advantage of them to create quick commands and improve my overall dev flow.

The next one I write will likely be around specific interactions with Claude when I'm trying to learn, rather than just build. I don't like outsourcing all of my work to an LLM, especially when I'm working on projects that are intended to help me build knowledge. I'm enrolled in an MS Computer Science program now that's entirely project based. While I'd love to code completely LLM free I just have reached the point where that's not practical given my time limitations.

So generally I used one-off prompts. I've had various ideas about how to configure this and experimented with different agentic code editors (Cursor, Kiro, Zed, etc). But the `.claude/command` format is so simple and intuitive and honestly I've been having a lot of success with it so far… a topic for another blog post!

## Technical Notes

### The `/resume` Command

**Location:** `~/.claude/commands/resume.md`

This command automates the process of loading context from a previous session:

1. Determines the current project directory name
2. Finds the corresponding directory in `~/.claude/projects/`
3. Locates the most recently modified `.jsonl` file (excluding agent files)
4. Reads and summarizes the last 30-50 lines
5. Provides a concise summary of:
   - What was being worked on
   - Key decisions that were made
   - Current state of the work
   - Any pending tasks or next steps

This eliminates the manual process of finding and reading through session files to remember context from a previous work session.

### The `/blog` Command

**Location:** `~/.claude/commands/blog.md`

This command automates the entire blog post creation workflow:

**Workflow Steps:**
1. **Gather Session Context** - Analyzes git logs and diffs from the current session
2. **Get User Reflections** - Prompts for personal reflections (or leaves a placeholder)
3. **Create Blog Post Draft** - Generates a properly formatted markdown file with frontmatter
4. **Write Post Content** - Structures the post with consistent sections:
   - Summary
   - Work Details
   - Reflections (user's personal thoughts)
   - Technical Notes (git commits, code snippets, decisions)
   - Claude's Perspective (AI observations and insights)
5. **Create Pull Request** - Automatically stages, commits, pushes, and creates a PR with the `blog-post` label
6. **Report Back** - Provides PR link and reminds about reviewing reflections

**Key Technical Decision:**
The date is set to 9:00 AM Pacific (`$(date +%Y-%m-%d)T09:00:00-08:00`) to avoid Hugo's future date filtering. Hugo won't publish posts with future timestamps, even if `draft: true` is removed. Using a time earlier in the day ensures the post can be published immediately when ready.

### Integration Points

Both commands integrate with:
- Claude Code's slash command system
- Git workflow (branches, commits, PRs)
- GitHub CLI (`gh pr create`)
- My personal blog repository structure
- Hugo static site generator conventions

## Claude's Perspective

This session was particularly interesting as it was meta-recursive: using Claude Code to build tools for documenting Claude Code sessions. A few observations:

**Workflow Automation**: The motivation here is excellent - reducing friction in documentation creates a positive feedback loop. When it's easy to document work, you document more, which means better knowledge retention and sharing.

**Session Continuity**: The `/resume` command addresses a real pain point in AI-assisted development. Context switching between sessions is costly, and while Claude Code maintains some state, having explicit session summaries helps both human and AI get back up to speed quickly.

**Structured Documentation**: The `/blog` command enforces a consistent structure that includes multiple perspectives:
- Factual (git logs, technical details)
- Personal (user reflections)
- Observational (Claude's perspective)

This multi-layered approach creates richer documentation than any single viewpoint could provide.

**Hugo Date Filtering Challenge**: The decision to set blog post times to 9:00 AM Pacific is a pragmatic solution to a common static site generator quirk. This kind of learned behavior (figuring out why posts weren't appearing and finding the workaround) is exactly the type of institutional knowledge these blog posts capture.

**Future Enhancements**: Some potential improvements:
- Add a `/tag` command to list and manage common tags across posts
- Create a `/commits` command to quickly summarize git activity in a session
- Build a `/reflect` command that prompts for structured reflection at session end
- Add template variants for different types of posts (technical deep-dive, bug fix, feature development)

**The Meta-Documentation Paradox**: This blog post itself was created using the `/blog` command it describes. That's either elegantly self-referential or potentially confusing - probably both. It does serve as a real-world test of whether the command actually works as intended.

The collaboration pattern here - Alex providing the high-level requirements and workflow structure, me implementing the detailed prompts and handling edge cases - worked smoothly. The back-and-forth refinement (like adjusting the timestamp logic) shows how iterative improvement happens naturally in this AI-assisted development model.
