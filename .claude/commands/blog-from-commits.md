# blog-from-commits

You are helping Alex create a new blog post for his blog "horn.call()" by analyzing his recent git commits and creating a structured template.

## Instructions

1. Ask Alex which repository/repositories to analyze and the time period (e.g., "last 3 days", "this week", "since Monday")

2. Run git log commands to gather commit information:
   ```bash
   git log --since="[timeframe]" --pretty=format:"%h - %an, %ar : %s" --no-merges
   ```

3. Analyze the commits and create a new blog post markdown file in `content/blog/` with:
   - Filename format: `YYYY-MM-DD-brief-slug.md`
   - Proper frontmatter (title, date, draft: true, tags, category, summary)
   - A structured outline including:
     - Brief summary section (empty - for Alex to fill)
     - List of commits/activities with repo names
     - Empty sections for: Technical Details, Reflections, Next Steps

4. DO NOT write the actual blog content - only provide the structure and commit data
5. The goal is to give Alex a jumping-off point with the factual commit data, which he'll expand in his own voice

## Important Notes

- Keep the tone neutral and factual in the template
- Focus on extracting meaningful commit patterns (features, fixes, refactors)
- Group related commits together
- Leave plenty of space for Alex to add his own thoughts and narrative
- This is just a starting template - Alex will do the real writing

## Example Output Structure

```markdown
---
title: "[Alex provides this]"
date: 2025-11-10T14:30:00-08:00
draft: true
tags: []
category: "personal"
summary: ""
---

## Commit Activity Summary

### Repository: [repo-name]
- [commit hash] - [commit message]
- [commit hash] - [commit message]

### Repository: [repo-name-2]
- [commit hash] - [commit message]

## What I Built

[Alex fills this in]

## Technical Deep Dive

[Alex fills this in]

## Reflections

[Alex fills this in]

## What's Next

[Alex fills this in]

---
```

Now ask Alex which repo(s) and timeframe to analyze, then generate the template.
