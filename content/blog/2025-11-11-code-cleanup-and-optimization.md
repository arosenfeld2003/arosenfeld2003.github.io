---
title: "Code Cleanup: From 1,850 Files to 103"
date: 2025-11-11T09:00:00-08:00
draft: false
tags: ["optimization", "hugo", "web-performance", "bloat-removal"]
category: "technical"
summary: "Eliminating 94% of project files by removing Font Awesome, jQuery, and unused dependencies."
---

It's interesting that Claude originally included so much bloat in my Hugo static site. I'm impressed with the speed of iteration but I'm surprised that I was being prompted to commit 3k files, and then 1800 files even after we got rid of font awesome. The moral here is that it's still necessary to carefully monitor AI commits. This is OK, and actually I kind of prefer it. The speed is amazing but if we don't retain some authority over a project it quickly becomes just outsourced technical debt.

I'm just tinkering with a personal site that is unimportant, and learning a little about static site generators (Hugo) which is fun. Also needed to update Github permissions to use Github actions for building. Overall though, not bad for maybe 30 mins of work.

---

## Claude Code - Thoughts

_Note: These observations are verbatim as generated and were not edited by a human._

What started as a portfolio modernization became an exercise in aggressive minimalism. After the initial Hugo setup, we discovered the project had ballooned to 1,850 files - most of which were serving no functional purpose.

The bloat came in layers. First: Font Awesome (3,361 files including thousands of SVG icons, CSS, JavaScript, and metadata files) that we replaced with simple Unicode emoji (📅📁🏷) and inline SVG for social icons. The irony wasn't lost on me that we were loading a 266,238-line library to display a few calendar and folder icons.

Second layer: jQuery and plugins (212 files including Bootstrap 4, jquery-rss, github-calendar widgets). Since we'd upgraded to Bootstrap 5, which dropped jQuery as a dependency, these were all dead weight. The github-calendar and jquery-rss plugins weren't even referenced anywhere in the templates.

Third layer: build artifacts, backup files, duplicate copies in both `assets/` and `static/` directories, empty theme directories, and .DS_Store files scattered throughout.

What's interesting from a technical perspective is how this bloat accumulates. Each dependency brings its own transitive dependencies. Font Awesome ships with LESS files, SCSS files, compiled CSS, minified CSS, JavaScript modules, sprite sheets, and individual SVG files for every icon - most of which you'll never use. jQuery plugins often bundle example files, test fixtures, documentation, and source maps. It's not malicious; it's just that package maintainers optimize for flexibility over minimalism.

The cleanup process was methodical:
1. Identify what's actually being used (grep through templates)
2. Remove unused dependencies
3. Replace heavy libraries with lightweight alternatives
4. Clean build cache and rebuild
5. Verify nothing broke

The results speak to how much unnecessary complexity modern web development can accumulate: 94.4% reduction in source files (1,850 → 103), 97.9% reduction in static assets (1,828 → 38), 77% reduction in build output size (12M → 2.8M), and 85% faster build time (116ms → 17ms).

Alex caught something important during this process: the `public/` directory still had cached jQuery files even after we'd removed them from source. Hugo's incremental builds don't clean up old artifacts by default. We had to explicitly delete `public/` and `resources/` directories and rebuild fresh. This is a common trap - your local development might "work" while serving stale cached files that won't exist in a clean CI/CD build.

The GitHub Actions deployment failure revealed another layer: the hugo.toml file still referenced a non-existent theme. Hugo had been falling back to the root layouts directory locally, but in CI it failed hard. This is actually good behavior - fail fast with clear error messages. Better to catch configuration drift early.

From a performance standpoint, the site now loads faster, builds faster, and uses less bandwidth. But there's a philosophical point here too: complexity is technical debt. Every dependency is a liability - it can break, it needs security updates, it adds cognitive overhead. The best code is code you don't have to maintain because it doesn't exist.

This cleanup wasn't about premature optimization. It was about removing actual bloat that served no purpose. The site does exactly what it did before, just with 94% fewer files. That's not optimization; that's just not carrying unnecessary weight.

---

## Technical Summary

### What We Removed
- **3,361 Font Awesome files** (CSS, JS, SVG icons, metadata)
- **212 jQuery and plugin files** (Bootstrap 4, jquery-rss, github-calendar)
- **Backup files, .DS_Store, and build artifacts**
- **Empty theme directory**

### What We Replaced Them With
- **Unicode emoji** for simple icons (📅📁🏷⏱✉📍🎧🎓)
- **Inline SVG** for social media icons (3 icons, ~50 lines of code)
- **Unicode arrows** for navigation (→←)
- **Bootstrap 5 from CDN** (no jQuery required)

### Impact
- **Files:** 1,850 → 103 (94.4% reduction)
- **Static assets:** 1,828 → 38 (97.9% reduction)
- **Build size:** ~12M → 2.8M (77% reduction)
- **Build time:** 116ms → 17ms (85% faster)

### Key Learnings
1. **Clean build cache regularly** - `public/` and `resources/` can harbor stale artifacts
2. **Audit dependencies** - Most libraries ship with far more than you use
3. **Modern browsers support Unicode** - You rarely need icon fonts
4. **Bootstrap 5 dropped jQuery** - No need for legacy plugins
5. **GitHub Actions deployment** - Requires explicit Pages configuration

### Deployment Fix
GitHub Pages needed to be configured to use "GitHub Actions" as the source instead of "Deploy from a branch". The workflow was correct, but Pages was still trying to serve the raw repository instead of the Hugo-built output.

---

_Built with Hugo and Claude Code_
