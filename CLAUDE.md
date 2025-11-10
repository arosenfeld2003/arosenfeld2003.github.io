# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Alex Rosenfeld's portfolio website and blog "horn.call()" - a retro 8-bit terminal-themed developer blog exploring the intersection of music, humanity, and technology. Built with Hugo static site generator and deployed to GitHub Pages at https://www.adrosenfeld.com

## Blog Philosophy

- **Personal Voice**: Alex writes in his own style - do NOT auto-generate blog content
- **Theme**: Intersection of arts, humanities, and technology from the perspective of an orchestral musician turned software engineer
- **Topics**: Technical work, AI/LLMs, developer tooling, music/arts, Focal Dystonia, human creativity vs. technology
- **Audience**: Professional content suitable for LinkedIn, highlighting both technical and writing skills
- **Goal**: Daily posts (if possible), organic community growth

## Tech Stack

- **Hugo** v0.152.2 (static site generator written in Go)
- **Bootstrap 5** (CSS framework)
- **Custom Retro Terminal CSS** (8-bit aesthetic with CRT effects)
- **GitHub Pages** (hosting with custom domain)
- **GitHub Actions** (automated deployment)

## Project Structure

```
arosenfeld2003.github.io/
├── .claude/commands/
│   └── blog-from-commits.md    # Custom slash command for blog post templates
├── .github/workflows/
│   └── hugo.yml                # GitHub Actions deployment workflow
├── archetypes/
│   └── blog.md                 # Template for new blog posts
├── assets/
│   ├── css/
│   │   ├── retro-terminal.css  # Custom 8-bit terminal theme
│   │   └── styles.css.backup   # Original theme (backup)
│   ├── images/                 # Profile images, project screenshots
│   ├── fontawesome/            # Self-hosted Font Awesome icons
│   └── js/
│       └── main.js             # Custom JavaScript
├── content/
│   └── blog/
│       ├── _template-example.md    # Example post structure
│       └── [blog posts].md         # Individual blog posts
├── layouts/
│   ├── _default/
│   │   ├── baseof.html         # Base template for all pages
│   │   ├── taxonomy.html       # Tag/category archive pages
│   │   └── terms.html          # List of all tags/categories
│   ├── blog/
│   │   ├── list.html           # Blog listing page
│   │   └── single.html         # Individual blog post layout
│   ├── partials/
│   │   ├── head.html           # HTML head with meta tags
│   │   ├── navbar.html         # Navigation bar
│   │   ├── footer.html         # Footer
│   │   ├── scripts.html        # JavaScript includes
│   │   ├── experience.html     # Work experience section
│   │   ├── opensource.html     # Open source contributions
│   │   ├── education.html      # Education history
│   │   └── music.html          # Music interests
│   └── index.html              # Homepage/portfolio layout
├── public/                     # Generated site (gitignored)
├── hugo.toml                   # Hugo configuration
├── CNAME                       # Custom domain: adrosenfeld.com
└── .gitignore
```

## Development Commands

### Local Development
```bash
# Start Hugo development server
hugo server --buildDrafts

# The site will be available at http://localhost:1313
# Hugo watches for changes and auto-reloads
```

### Build Site
```bash
# Build production site
hugo --gc --minify

# Build with drafts (for testing)
hugo --buildDrafts

# Clean build
hugo --cleanDestinationDir
```

### Create New Blog Post
```bash
# Create a new blog post using the archetype
hugo new content/blog/2025-11-10-my-post-title.md

# Or use the custom Claude Code slash command
/blog-from-commits
```

## Custom Claude Code Command

### `/blog-from-commits`

Analyzes git commits from specified repos and timeframe, then generates a structured blog post template with:
- Frontmatter (title, date, tags, category, summary)
- List of commits grouped by repository
- Empty sections for Alex to fill in his own voice

**Usage:**
1. Run `/blog-from-commits`
2. Specify repo paths and timeframe when prompted
3. Claude generates template in `content/blog/`
4. Alex edits and expands the template in his own voice
5. Remove `draft: true` when ready to publish

## Blog Post Frontmatter

```yaml
---
title: "Post Title"
date: 2025-11-10T14:00:00-08:00
draft: true                      # Remove when ready to publish
tags: ["tag1", "tag2"]          # For categorization
category: "personal"            # "personal" or "professional"
summary: "Brief summary for listings and social shares"
---
```

## Retro Terminal Theme

The site uses a custom retro 8-bit terminal aesthetic:

### Colors
- **Background**: `#0a0a0a` (near black)
- **Primary Text**: `#00ff00` (terminal green)
- **Accent Cyan**: `#00ffff`
- **Accent Magenta**: `#ff00ff`
- **Accent Amber**: `#ffb000`

### Fonts
- **Headers**: 'Press Start 2P' (pixel font)
- **Terminal Text**: 'VT323' (monospace terminal font)
- **Body**: 'IBM Plex Mono' (modern monospace)

### Effects
- CRT scanline overlay
- Text glow/shadow effects
- Pixelated image rendering
- Subtle screen flicker animation

### Key CSS Classes
- `.glow-text` - Animated glowing text
- `.cursor-blink` - Blinking terminal cursor
- `.badge` - Tags and labels
- `.btn-cta-primary`, `.btn-cta-secondary` - CTA buttons with retro styling

## Deployment

### Automatic Deployment
- Push to `master` branch triggers GitHub Actions
- GitHub Actions builds Hugo site
- Deploys to GitHub Pages
- Available at https://www.adrosenfeld.com (via CNAME)

### Manual Deployment
```bash
# Build the site
hugo --gc --minify

# Commit and push
git add .
git commit -m "Update site"
git push origin master
```

### GitHub Pages Configuration
- **Source**: GitHub Actions workflow
- **Custom Domain**: adrosenfeld.com (configured in repo settings and CNAME file)
- **Branch**: Deploys from `gh-pages` branch (created by workflow)

## Content Guidelines

### Writing Blog Posts
1. **Create draft**: `hugo new content/blog/YYYY-MM-DD-slug.md`
2. **Write content**: Use markdown, code blocks, headings
3. **Add frontmatter**: Tags, category, summary for SEO
4. **Preview locally**: `hugo server --buildDrafts`
5. **Remove draft status**: Delete `draft: true` line
6. **Commit and push**: Triggers automatic deployment

### Portfolio Updates
- Update partials in `layouts/partials/` for sections
- Experience: `experience.html`
- Open source: `opensource.html`
- Education: `education.html`

### Theme Customization
- CSS: `assets/css/retro-terminal.css`
- Modify CSS variables in `:root` for color changes
- Update fonts in `layouts/partials/head.html`

## Important Notes

### Hugo Version
- Using Hugo v0.152.2 (extended)
- Extended version required for SCSS processing
- Update GitHub Actions workflow if changing Hugo version

### Custom Domain
- Domain configured via `CNAME` file
- DNS points to GitHub Pages
- HTTPS enforced

### Asset Organization
- Keep original assets in `assets/` directory
- Hugo processes and copies to `public/` on build
- Images, CSS, JS all served from `/assets/` path

### Markdown Features
- Full markdown support in blog posts
- Syntax highlighting for code blocks
- Emoji support enabled (`:emoji:` syntax)
- HTML allowed in markdown (for advanced formatting)

## Common Tasks

### Adding a New Experience/Job
Edit `layouts/partials/experience.html` - add new `.item` div with company, role, dates, and bullet points.

### Updating Social Links
Edit `hugo.toml` in the `[params.social]` section.

### Changing Site Title/Description
Edit `hugo.toml` - update `title` and `params.description`.

### Adding a Menu Item
Add new `[[menu.main]]` entry in `hugo.toml` with name, url, and weight.

### Testing Before Deploy
Always run `hugo server --buildDrafts` locally to preview changes before pushing to production.

## Working with Alex

### As an Editor/Soundboard
- Help refine Alex's writing while preserving his voice
- Suggest structural improvements
- Provide technical accuracy checks
- DO NOT rewrite in an "AI voice" - maintain his personal style

### Content Suggestions
- Based on his background (music + tech), suggest relevant topics
- Highlight connections between arts and technology
- Reference his unique perspective as former musician

### Technical Assistance
- Help with Hugo templating and Go templates
- CSS/styling adjustments for the retro theme
- Markdown formatting and best practices
- SEO optimization for blog posts
