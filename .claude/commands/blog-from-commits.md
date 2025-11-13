# blog-from-commits

This is a repository-specific command that analyzes git commits from specified repositories and delegates to the root `/blog` command for post creation.

## Instructions

1. Ask Alex which repository/repositories to analyze and the time period (e.g., "last 3 days", "this week", "since Monday")

2. For each repository specified, run git log commands to gather commit information:
   ```bash
   cd /path/to/repo
   git log --since="[timeframe]" --pretty=format:"%h - %an, %ar : %s" --no-merges
   git diff $(git log --since="[timeframe]" --format=%H | tail -1)~1..HEAD
   ```

3. Analyze and summarize the commits:
   - Group related commits by feature/fix/refactor
   - Identify key technical decisions
   - Note any interesting patterns or challenges
   - Extract repository names and relevant context

4. Pass this commit analysis as the "session context" to the root `/blog` command by invoking it with the SlashCommand tool

5. The root `/blog` command will handle:
   - Getting user reflections
   - Creating the properly formatted blog post file
   - Generating Claude's perspective
   - Creating the PR

## Key Difference from Root `/blog`

- **Root `/blog`**: Analyzes current working directory and today's commits
- **Repo `/blog-from-commits`**: Allows multi-repo analysis over custom timeframes, then delegates to root `/blog` for formatting and creation

After gathering commit data, invoke the root command:
```
Use the SlashCommand tool to call /blog
```
