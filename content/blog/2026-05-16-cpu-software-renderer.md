---
title: "Building a CPU Software Renderer from Scratch"
date: 2026-05-16T09:00:00-08:00
draft: false
tags: ["graphics", "C", "systems-programming", "learning"]
category: "technical"
summary: "Implementing a complete software renderer in C without graphics libraries — exploring how pixels, memory, and algorithms power graphics rendering"
---

This was a fun code collab to think about how images are handled in CPU memory, in C. While we enjoyed working through the implementation, it's very interesting to consider how this was actually developed back in the 60's and what problems specifically Bresenham's algorithm was designed to solve — namely, that we need to account for lines moving in any direction, and by calculating an error value we can determine if we are moving x, y or both in the 2D array.

## Technical Details

This session focused on implementing a complete CPU-based software renderer in C. The project, housed in the `cpu_renderer` directory, implements a graphics pipeline from first principles using only standard C libraries, without any graphics APIs like OpenGL, Vulkan, or SDL.

### Project Structure

The implementation is minimal but complete:
- **main.c**: ~145 lines of C99 code containing the entire renderer
- **SPEC.md**: Comprehensive learning guide with five milestones
- **output.bmp**: Generated BMP image demonstrating the renderer's capabilities
- **Learning notes**: Two markdown files documenting key concepts (memory layout and Bresenham's algorithm)

### Core Implementation: Five Milestones

**Milestone 1: Framebuffer Allocation and Memory Layout**

The foundation is understanding that 2D images are stored as linear arrays in memory. For an 800×600 image, that's 480,000 pixels × 4 bytes = 1.8 MB allocated with `malloc`. The key insight is the index formula:

```c
index = y * width + x
```

Rather than `pixels[y][x]` (which creates per-row pointer indirection), a flat array matches how hardware actually works and enables writing the entire framebuffer to disk in a single `fwrite` call.

```c
typedef struct {
    int width;
    int height;
    uint32_t *pixels;
} Framebuffer;
```

**Milestone 2: Pixel Plotting with Bounds Checking**

The lowest-level primitive is `draw_pixel`, which enforces a critical invariant: bounds checking happens once, in one place:

```c
void draw_pixel(int x, int y, uint32_t color)
{
    if (x < 0 || x >= framebuffer.width ||
        y < 0 || y >= framebuffer.height)
        return;
    framebuffer.pixels[y * framebuffer.width + x] = color;
}
```

Every higher-level function calls `draw_pixel`, so fixing bounds checking here prevents undefined behavior throughout the entire renderer. Without this, an off-by-one error in `draw_rect` or `draw_line` could write to arbitrary memory.

**Milestone 3: Rectangle Rasterization**

Rectangles are straightforward rasterization — converting a geometric description (position and size) into discrete pixel writes:

```c
void draw_rect(int x, int y, int w, int h, uint32_t color)
{
    for (int py = y; py < y + h; py++)
        for (int px = x; px < x + w; px++)
            draw_pixel(px, py, color);
}
```

The call `draw_rect(100, 100, 300, 200, 0x0000FF00)` makes 60,000 pixel writes (300 × 200), all automatically clipped if they extend beyond the framebuffer bounds.

**Milestone 4: Bresenham's Line Algorithm — The Core Algorithm**

This is the most interesting milestone, implementing Bresenham's line rasterization algorithm (1965). The naive approach — computing `y = y0 + slope * (x - x0)` — fails for steep lines (they look dotted) and relies on floating-point arithmetic.

Bresenham's insight: track an integer *error term* that accumulates as you step along the major axis (whichever of x or y changes faster). When the error exceeds a threshold, step along the minor axis:

```c
void draw_line(int x0, int y0, int x1, int y1, uint32_t color)
{
    int dx  = abs(x1 - x0);
    int dy  = abs(y1 - y0);
    int sx  = (x0 < x1) ? 1 : -1;
    int sy  = (y0 < y1) ? 1 : -1;
    int err = dx - dy;

    while (1) {
        draw_pixel(x0, y0, color);
        if (x0 == x1 && y0 == y1)
            break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 <  dx) { err += dx; y0 += sy; }
    }
}
```

The `sx` and `sy` sign variables handle all eight octants (all directions) without special-casing. The algorithm uses only integer arithmetic — no division, no floating-point — making it fast and predictable on any platform.

**Milestone 5: BMP File Export**

Writing a valid BMP file requires understanding binary formats and little-endian byte order. The BMP header is precisely 54 bytes:

```
Offset  Size  Field
------  ----  -----
 0      2     Signature: 'B', 'M'
 2      4     File size (little-endian)
 6      4     Reserved
10      4     Pixel data offset: 54
14      4     Info header size: 40
18      4     Width (little-endian)
22      4     Height — negative for top-down order
26      2     Color planes: 1
28      2     Bits per pixel: 32
30      4     Compression: 0
34     20     Remaining fields: zeros
54     ...    Pixel data
```

The critical detail: setting height to negative (`-framebuffer.height`) tells the BMP reader to display rows top-to-bottom (framebuffer order) rather than bottom-to-top (BMP default).

The code uses bit shifts to encode multi-byte integers in little-endian order:

```c
file_header[2] = (unsigned char)(filesize);
file_header[3] = (unsigned char)(filesize >> 8);
file_header[4] = (unsigned char)(filesize >> 16);
file_header[5] = (unsigned char)(filesize >> 24);
```

A single `fwrite` of the flat pixel array dumps the entire image data in one operation.

### Git History

The project progressed through clear commits:
- Initial SPEC.md and starter code
- Learning notes on flat array memory layout and pixel indexing
- Bresenham algorithm implementation with associated learning notes
- Final commit with complete implementation

### Generated Output

The renderer produces an 800×600 BMP image containing:
- Dark gray background (`0x00202020`)
- Green filled rectangle at (100, 100), 300×200 pixels (`0x0000FF00`)
- White diagonal line from (100, 100) to (400, 300) (`0x00FFFFFF`)

The output is a valid BMP file, readable by any image viewer.

### Color Format

Colors are 32-bit packed values: `0x00RRGGBB`, with the high byte unused (no alpha channel). This matches common framebuffer representations.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

### Approach to Learning Through Constraints

This project is a masterclass in learning by removing options. By banning OpenGL, SDL, and graphics engines, the learner is forced to understand *how* these tools work, not just *what* they do. The result is deep knowledge: you can't use a library you don't understand, so you must understand the fundamentals.

### Architectural Clarity

The code demonstrates excellent separation of concerns:
- `draw_pixel` is the single write point, encapsulating all bounds checking
- `draw_rect` and `draw_line` are pure algorithms that never touch `pixels` directly
- `write_bmp` is isolated from rendering logic
- The global `Framebuffer` struct is simple but sufficient

This isn't over-engineered. It's the minimal structure needed to stay correct.

### The Bresenham Algorithm as a Turning Point

Bresenham's algorithm is where "rendering theory" becomes concrete. The implementation uses integer arithmetic exclusively — no floats, no division, no rounding. This is both elegant and pragmatic: it's fast, deterministic across platforms, and correct by construction. The sign variables `sx` and `sy` handling all eight octants without special cases is a small masterpiece of algorithm design from 1965 that still holds up.

### Memory Layout Insights

The decision to use a flat `uint32_t *pixels` array rather than `uint32_t **pixels` (or a nested struct) has cascading benefits: simpler bounds checking, cache-friendly access, and the payoff in Milestone 5 where the entire image can be written to disk in a single `fwrite`. This is the kind of decision that feels obvious in retrospect but requires intentional thinking upfront.

### Learning Notes as Documentation

The learning notes (particularly `milestone-1-memory-layout.md` and the notes on Bresenham) are remarkable. They don't just explain *what* the code does — they explain the derivation: "why the index formula is `y * W + x`" and "why Bresenham's error accumulation works." This is the kind of documentation that teaches mental models, not just APIs.

### What This Reveals About the Work

The commit messages ("Code Collab: learning about cpu rendering in C", "Implement draw_line (Bresenham) and add learning notes") and the structured milestone approach suggest this was guided learning, possibly in a course or mentorship context. The progressively increasing complexity (pixels → rectangles → lines → files) is pedagogically sound.

### Limitations and Unknowns

I can see what was built, but not:
- How long this took or when different milestones were reached
- Whether earlier drafts of Bresenham were attempted before the final version
- What testing was done beyond the single rendered output
- Whether the BMP output was verified visually

I'm also speculating that this is part of a larger course (the `/learn` cues in SPEC.md hint at guided learning), but I can't verify that from code alone.

### The Renderer's Completeness

The renderer does what it claims to do, no more, no less. It renders rectangles and lines to a 32-bit BMP. It doesn't handle alpha blending, antialiasing, or clipping (clipping happens implicitly via bounds checking). This is perfect for a learning project: it covers the essentials without scope creep.

---

_Built with Claude Code in an afternoon of technical scaffolding_
