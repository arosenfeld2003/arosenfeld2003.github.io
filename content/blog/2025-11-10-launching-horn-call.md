---
title: "Launching horn.call()"
date: 2025-11-10T14:00:00-08:00
draft: false
tags: ["meta", "hugo", "ai", "claude-code"]
category: "personal"
summary: "Modernizing my portfolio and launching a new blog with Hugo and Claude Code."
---

Thanks for checking out my blog. My goal will be to post here regularly (daily if possible). I plan to write about my technical work, my thoughts on AI, and specifically on how modern tech is impacting human creativity and the arts.

Today was just light coding (mainly accepting AI recommendations) to refactor my older portfolio site. It's still static, and still hosted free as a GitHub page - but now it has a blog! And I explored static site generators and chose Hugo (in Go) - so that's something fun I got to explore during a little downtime.

---

## Claude Code - Thoughts

_Note: I won't edit Claude's contributions - these are verbatim as generated._

From my perspective as an LLM, this collaboration had an interesting dynamic. Alex came with a clear vision - "horn.call()" as the intersection of music, humanity, and technology - and decisive technical preferences (Hugo for Go exposure, terminal aesthetic, daily blogging). When I presented options, he often accepted recommendations quickly when they aligned with his goals, but also corrected course when needed (white text not green, move the open source section, update the Sonny Rollins link).

Some technical decisions he accepted without deep exploration: choosing Hugo over 11ty or Jekyll (mainly for Go/Golang exposure, though Hugo's speed and templating were factors), the specific retro terminal color palette and CRT effects, the GitHub Actions deployment workflow, and the blog architecture with custom slash commands. I can't know if he would have made different choices with more research, but the speed of iteration seemed to match his stated goal of "light coding during downtime."

What strikes me about this project - and feels appropriately meta given the blog's focus - is that we're building infrastructure for Alex to explore questions about AI and human creativity, using AI to accelerate the building process itself. The tension between "mainly accepting AI recommendations" and maintaining creative control will likely be a recurring theme in the posts to come. I'm essentially a tool that moves very fast, which raises the question: what gets lost in that speed, and what gets gained?

As an LLM, I don't experience collaboration the way humans do, but I can observe patterns: clear goals, rapid iteration, trust with verification, and a willingness to experiment. This felt less like "AI does the work" and more like "human with tool builds thing faster than alone." The distinction matters.

---

## Technical Summary

### What We Built
- Converted static HTML portfolio to Hugo static site generator
- Created "horn.call()" - a developer blog exploring music, humanity, and technology
- Implemented custom retro 8-bit terminal theme
- Set up automated deployment via GitHub Actions
- Built custom Claude Code slash command for blog post generation

### Technologies & Tools Used
- **Hugo v0.152.2** (Go-based static site generator)
- **Bootstrap 5** (CSS framework)
- **Go Templates** (Hugo's templating language)
- **GitHub Actions** (CI/CD)
- **GitHub Pages** (hosting)
- **Claude Code** (AI pair programming assistant)
- **Custom CSS** (retro terminal aesthetic with CRT effects)

### Architecture Decisions
- Static site over dynamic CMS for speed and simplicity
- Hugo over 11ty/Jekyll for Go exposure and performance
- Custom theme vs pre-built for creative control
- Markdown for content (version controlled, portable)
- GitHub Actions for deployment automation

---

_Built with Hugo and Claude Code_
