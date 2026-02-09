---
title: "Chasing Overflow Down the CSS Rabbit Hole"
date: 2026-02-09T09:00:00-08:00
draft: true
tags: ["css", "hugo", "responsive-design", "debugging", "claude-code"]
category: "technical"
summary: "A debugging session where fixing one CSS overflow led to discovering Hugo's hidden table-based syntax highlighting, duplicate asset files, and the joys of browser caching."
---

I don't usually spend a lot of time debugging frontend issues, so I decided to see if Claude could debug this one for my blog. Turns out there's a lot of complexity hiding behind a simple CSS overflow.

I also forgot to do a hard reload at one point, so I checked the work and mistakenly told Claude the fix hadn't worked - but it was actually user error (I was loading a cached version of the site on the local server). Whoops.

Ultimately I was impressed with Claude's ability to parse a screenshot and immediately take action. It looked at the image, identified the overflowing element, and started working on the fix without me having to describe anything in text.

TLDR: there may still be a different "best-practice" flow for working on back-end issues vs. front-end issues. When working predominantly on front-end, it's probably best to lean heavily on visuals and screenshots. Modern LLMs are getting better and better at using these visual inputs to actually make meaningful code changes.

## Technical Details

### The Problem

After publishing my previous blog post on building an AI agent orchestrator, I noticed something ugly: code blocks with long lines were overflowing past the blog post border when the browser window was resized or viewed on mobile. The retro terminal border that frames each post was being violated by unruly `<pre>` elements.

### The First (Wrong) Fix

The obvious fix seemed simple enough. The `pre` element already had `overflow-x: auto` - so why wasn't it scrolling? I added `max-width: 100%` to `pre`, `overflow: hidden` to `.section-inner`, and `min-width: 0` to the content containers:

```css
.section-inner {
  overflow: hidden;
  min-width: 0;
}

pre {
  overflow-x: auto;
  max-width: 100%;
}
```

Rebuilt the site. Still overflowing. Huh.

### Discovery 1: Hugo's Table-Based Line Numbers

Inspecting the DOM revealed that Hugo's Chroma syntax highlighter wraps line-numbered code blocks in a `<table>`:

```html
<div class="highlight">
  <div style="color:#f8f8f2;background-color:#272822;...">
    <table style="border-spacing:0;padding:0;margin:0;border:0;">
      <tr>
        <td><!-- line numbers --></td>
        <td style="width:100%">
          <pre>
            <code>
              <span style="display:flex;"><!-- each line --></span>
            </code>
          </pre>
        </td>
      </tr>
    </table>
  </div>
</div>
```

Tables have their own layout rules. `overflow-x: auto` on a `pre` inside a table cell doesn't constrain the table itself from expanding. The fix was to convert the table to CSS flexbox:

```css
.highlight table,
.highlight tbody,
.highlight tr {
  display: flex;
  width: 100%;
}

.highlight td:first-child {
  flex-shrink: 0;
}

.highlight td:last-child {
  flex: 1;
  min-width: 0;
  overflow-x: auto;
}
```

The key insight: `min-width: 0` on the code column flex item allows it to shrink below its content width (flex items default to `min-width: auto`), while `overflow-x: auto` adds a horizontal scrollbar.

### Discovery 2: Bootstrap's Flex Columns

The blog layout uses Bootstrap's grid (`col-lg-10`), which renders as flex items. Flex items also default to `min-width: auto`, meaning a wide code block could push the entire column wider than intended:

```css
.row > [class*="col"] {
  min-width: 0;
}
```

### Discovery 3: The Phantom CSS File

After applying all the fixes, nothing changed. The CSS from `curl` showed the old file - 574 lines instead of our updated 630. Turns out there were **two copies** of `retro-terminal.css`:

- `assets/css/retro-terminal.css` - where I was editing
- `static/assets/css/retro-terminal.css` - what Hugo actually serves

In Hugo, `static/` files are served directly and take precedence over `assets/` (which is meant for Hugo Pipes processing). Every edit had been going to the wrong file.

### Discovery 4: Browser Caching

Even after fixing the right file, the changes didn't appear. One `Cmd+Shift+R` later, everything worked. The browser had cached the old stylesheet.

### The Full Fix

The complete set of CSS changes that made code blocks responsive:

1. **Inline `code`**: `word-break: break-word` for long inline code snippets
2. **`pre` blocks**: `max-width: 100%` to respect container width
3. **`pre code`**: `word-break: normal` to prevent wrapping inside code blocks (scroll instead)
4. **`.section-inner`**: `overflow: hidden; min-width: 0` to clip any remaining overflow
5. **Bootstrap columns**: `min-width: 0` to allow flex items to shrink
6. **Hugo highlight tables**: Convert to flexbox with `min-width: 0` on the code column
7. **Mobile responsive**: Reduced padding and font size for `pre` blocks at narrow viewports

### Cleanup

Deleted the duplicate `assets/css/retro-terminal.css`, leaving `static/assets/css/retro-terminal.css` as the single source of truth.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session was a textbook example of how CSS debugging can be deceptively layered. What appeared to be a simple "add `overflow-x: auto`" fix turned into peeling back four distinct layers of complexity.

The most instructive moment was discovering the duplicate CSS file. I edited `assets/css/retro-terminal.css` through multiple iterations of increasingly sophisticated fixes - table-to-flex conversion, Bootstrap flex item constraints, highlight wrapper containment - and none of them took effect because Hugo was serving a completely different file from `static/`. I could have caught this earlier by verifying the served CSS matched the source file, but I initially assumed the dev server's hot-reload was working correctly. It's a good reminder that when changes "aren't working," the first question should be "are my changes actually being loaded?" before debugging the changes themselves.

The table layout discovery was genuinely interesting from a CSS perspective. Hugo's Chroma highlighter generates `<span style="display:flex">` wrappers for each line of code, inside a `<table>` with inline styles. Tables, flex containers, and inline styles each have their own layout and specificity rules, and they were all interacting here. The solution - converting the table to `display: flex` and using `min-width: 0` on the code column - works because it replaces the table's intrinsic sizing algorithm (which expands to fit content) with flexbox's (which respects `min-width` constraints).

One thing I found notable: the `min-width: auto` default on flex items came up twice in this fix - once for Bootstrap's grid columns and once for the highlight table cells. It's the same underlying CSS behavior causing overflow in two different contexts. The `min-width: 0` override is a pattern worth knowing for any project that uses flexbox with potentially wide content.

I also want to be transparent about my process: I went through several iterations of fixes that didn't work, partly because I was debugging the wrong file, and partly because each fix revealed a new layer of the problem. The final solution looks clean, but the path to getting there was decidedly iterative.

---

_Debugged with Claude Code on a Sunday morning_
