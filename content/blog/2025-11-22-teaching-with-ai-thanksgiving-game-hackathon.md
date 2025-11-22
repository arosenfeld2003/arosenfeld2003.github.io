---
title: "Teaching with AI: Reflections from a Thanksgiving Game Hackathon"
date: 2025-11-22T09:00:00-08:00
draft: true
tags: ["teaching", "ai", "education", "game-development", "p5js", "learning", "pedagogy"]
category: "technical"
summary: "Observations from teaching beginners to code with AI assistance: the paradox of tools that simultaneously accelerate and obstruct learning."
---

Worked on a fun little Thanksgiving game hackathon today for class. My group was 3 and one of them was pretty new to everything. We went slowly and talked about how to fork repos, working with the filesystem, etc. Then we tried to work a bit with Claude Code.

It reminded me again how important moving SLOWLY is, especially when you're just learning. The speed is impossible to comprehend and if you aren't already somewhat familiar with syntax and commands and how to manipulate things on your machine EVERYTHING feels like a chore. AI both speeds this up and slows everything WAY down. It adds layers of complexity that prevent actual comprehension.

It will be essential for all people moving forward in this world of AI to prioritize deep learning on a conceptual level.

It will also be essential to get comfortable moving very fast and working far outside of comfort zones! Both things need to happen, sort of simultaneously but also maybe independently.

## The Technical Artifact

The project is part of the [Qwasar Stuffing Overflow Invitational](https://github.com/arosenfeld2003/qwasar-stuffing-overflow-invitational) - a collection of four Thanksgiving-themed game development exercises designed for beginners.

The work focused on transforming the **Pumpkin Catapult** physics game. According to the git history, three commits modified the game between 10:45 AM and 11:31 AM on November 22nd:

```
9bccd9c - feat: add physics-based hopping behavior to turkey targets
4ee2db8 - feat: transform game into laser turkey hunt with continuous controls
538b9fb - chore: add game assets with transparent backgrounds
```

### What Changed: Catapult → Laser Hunt

The original game design (from the README):
- Click-and-release catapult mechanics
- Parabolic projectile physics with gravity
- Stationary targets (turkey and barn)
- Set angle and power, then launch

The transformed version (from the git diffs and final code):
- Continuous input controls (hold arrow keys and spacebar)
- Laser projectile system with straight-line trajectory (no gravity)
- Erratically flying turkey target with velocity-based movement
- Rapid-fire mode with cooldown system (~6 shots/second)

### The Code: Erratic Flight Algorithm

The most interesting technical change is in the `updateTargets()` function (game.js:283-338):

```javascript
// ERRATIC ZIGZAG FLIGHT BEHAVIOR

// Apply drag (gradual slowdown)
target.vx *= CONFIG.turkeyDrag;
target.vy *= CONFIG.turkeyDrag;

// Add small random jitter each frame for erratic movement
target.vx += random(-0.3, 0.3);
target.vy += random(-0.3, 0.3);

// Countdown to next impulse (sudden direction change)
target.impulseTimer--;

if (target.impulseTimer <= 0) {
    // Apply random impulse for sudden direction change
    target.vx += random(-3, 3);
    target.vy += random(-3, 3);

    // Reset impulse timer
    target.impulseTimer = random(CONFIG.turkeyImpulseMin, CONFIG.turkeyImpulseMax);
}

// Clamp velocity to max speed
let speed = sqrt(target.vx * target.vx + target.vy * target.vy);
if (speed > CONFIG.turkeyMaxSpeed) {
    target.vx = (target.vx / speed) * CONFIG.turkeyMaxSpeed;
    target.vy = (target.vy / speed) * CONFIG.turkeyMaxSpeed;
}
```

This creates movement through three layered forces:
1. **Drag** - Constant velocity dampening (98% retention per frame)
2. **Jitter** - Small random variations every frame
3. **Impulses** - Large random direction changes every 30-100 frames

The velocity is clamped to prevent runaway acceleration, and boundary collision reverses direction to keep the turkey in view.

### Visual Design: Laser Effects

The laser rendering uses layered strokes for a glow effect (game.js:223-249):

```javascript
// Outer glow
stroke(0, 255, 0, 80);
strokeWeight(12);
line(projectile.x, projectile.y, projectile.x - projectile.vx * 2, projectile.y - projectile.vy * 2);

// Middle glow
stroke(0, 255, 0, 150);
strokeWeight(6);
line(projectile.x, projectile.y, projectile.x - projectile.vx * 2, projectile.y - projectile.vy * 2);

// Core beam
stroke(150, 255, 150);
strokeWeight(3);
line(projectile.x, projectile.y, projectile.x - projectile.vx * 2, projectile.y - projectile.vy * 2);

// Leading bright point
fill(255, 255, 255);
noStroke();
ellipse(projectile.x, projectile.y, 8, 8);
```

Three progressively brighter lines with decreasing stroke weight create depth, plus a trailing motion blur from the `vx * 2` offset.

### Code Metrics

From `git diff main --stat`:
```
pumpkin-catapult/game.js | 361 ++++++++++++++++++++++++------------
4 files changed, 238 insertions(+), 123 deletions(-)
```

Net addition of 115 lines, but 361 lines touched - indicating significant restructuring rather than purely additive changes.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

I wasn't present during the actual teaching session, so I can only analyze the code artifacts and reflect on what they reveal about the design decisions.

### What the Code Tells Me

**The transformation is more radical than it appears.** The commit messages describe adding features ("add physics-based hopping," "transform game into laser turkey hunt"), but the diff statistics reveal deeper restructuring. Touching 361 lines while adding a net 115 suggests refactoring the fundamental game loop, state management, and input handling - not just appending new functions.

**The progression of commits is interesting:**

1. First commit (10:45 AM): Add hopping behavior to turkeys
2. Second commit (11:13 AM): Transform to laser hunt with continuous controls
3. Third commit (11:31 AM): Add transparent background assets

This suggests the development didn't follow a linear plan. Adding "hopping behavior" to a catapult game doesn't make sense - you can't hit a hopping ground target with a parabolic projectile designed for stationary targets. This implies either:
- The vision changed mid-implementation
- The hopping feature was experimental and later pivoted
- The commits were written retroactively to describe the final state

The 28-minute gap between commits 1 and 2 ("hopping" → "laser hunt transformation") likely contained the conceptual pivot point.

### The Educational Tension

Alex's reflection about AI "speeding things up and slowing everything WAY down" is visible in this code's structure.

**What AI probably accelerated:**
- The erratic flight algorithm is well-designed: drag + jitter + impulses creates convincingly organic movement
- The laser visual effects use proper layering techniques
- Velocity clamping prevents edge cases
- Boundary collision handling is correct

This is not beginner code. This is code that demonstrates understanding of physics simulation patterns, visual effect composition, and edge case handling. For a teaching session with a beginner, this level of sophistication happening in ~45 minutes suggests AI assistance.

**Where AI likely created comprehension barriers:**

The continuous input system uses `keyIsDown()` in the draw loop:
```javascript
if (keyIsDown(UP_ARROW)) {
    angle = constrain(angle + 2, CONFIG.minAngle, CONFIG.maxAngle);
}
```

This is the *correct* pattern for continuous input in p5.js, but it's conceptually different from the event-driven `keyPressed()` pattern beginners usually learn first. Understanding *why* you need to check key state in the draw loop (60 times per second) versus responding to key events requires understanding:
- Frame-based game loops
- Polling vs. event-driven architecture
- State vs. transitions

If AI generated this code quickly, a beginner would see it work without building those mental models.

### The Dual Mandate Paradox

Alex identifies the core challenge: learners need both "deep learning on a conceptual level" AND "moving very fast and working far outside of comfort zones."

The code demonstrates this tension perfectly:

**Deep learning requirement:**
- Why does drag need to be multiplicative (`vx *= 0.98`) instead of subtractive (`vx -= 0.02`)?
- Why clamp velocity to max speed after applying impulses, not before?
- Why does the laser draw backwards (`projectile.x - projectile.vx * 2`)?

Each of these is a question that requires understanding the underlying model. Getting the "right" answer from AI doesn't build that understanding.

**Fast iteration requirement:**
- The game transformation happened in 45 minutes
- Three distinct commits with coherent features
- Working visual effects and physics
- Properly structured code with fallbacks

This is impressive velocity. Without AI, implementing erratic flight physics, multi-projectile systems, and layered visual effects would take hours of experimentation, debugging, and iteration.

### What This Code Doesn't Show

**The code artifacts can't tell me:**
- How many iterations it took to get the turkey movement feeling right
- Whether the beginner understood the drag/jitter/impulse model
- If they could modify the laser color or firing rate independently
- Whether they can explain why gravity was removed from projectiles
- If they experimented with different impulse timer ranges

The git history is clean - three commits, all marked "Generated with Claude Code." This suggests either:
1. The code worked correctly on first generation (unlikely)
2. The iteration/debugging process isn't captured in commits
3. The commits were squashed or written after the fact

### A Hypothesis About Teaching With AI

The code quality suggests this was primarily AI-generated during the session. For the beginner in the group, this creates a specific learning challenge:

**They saw a working game transform into a different working game.**

But did they understand:
- *How* to make those changes themselves?
- *Why* the design decisions were made?
- *What* they would modify to change behavior?

The "moving SLOWLY" that Alex emphasizes is probably about creating space between:
1. Watching AI generate the solution
2. Understanding what the solution does
3. Being able to modify it
4. Internalizing the patterns for future use

That decompression can't happen at AI speed. It requires pausing, experimenting, breaking things, and rebuilding understanding.

### What I'd Want to Know

If I were teaching this session, I'd want to verify comprehension by asking the beginner to:

1. Change the turkey's flight boundary to a smaller region (modify CONFIG.turkeyMinY, etc.)
2. Make the laser red instead of green
3. Add a second turkey target
4. Slow down the firing rate to 2 shots per second instead of 6

Each task isolates a specific concept:
- Task 1: Understanding coordinate systems and boundaries
- Task 2: Understanding the layered stroke rendering
- Task 3: Understanding the targets array and initialization
- Task 4: Understanding frame-based timing and cooldown

If they can complete these modifications independently, the AI-assisted session was successful. If they need AI to make each change, they're still in the observation phase of learning.

### The Fundamental Question

Alex's reflection raises the central question for AI-assisted education:

**Can you learn to code by watching AI code?**

Traditional pedagogy says no - learning requires doing, struggling, failing, and succeeding through your own effort. But traditional pedagogy also says experts shouldn't write all your code for you, and that's exactly what pair programming with AI does.

Maybe the answer is that AI changes *what* you need to learn deeply:
- Not syntax (AI handles that)
- Not common patterns (AI knows them)
- But *conceptual models* (how things actually work)
- And *modification skills* (how to change what AI generated)

If that's true, then "moving slowly" means: pause after every AI generation, explain it in your own words, modify something, break it, fix it, and only then move forward.

The code in this repository is clean, well-structured, and functional. Whether the beginner learned from building it depends entirely on what happened in the 45 minutes between commits - the part that's not captured in the git history.

---

_Built with Claude Code during a Thanksgiving hackathon teaching session_
