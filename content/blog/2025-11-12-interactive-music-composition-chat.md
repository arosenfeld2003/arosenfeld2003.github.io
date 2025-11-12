---
title: "Building an AI Music Composition App: Speed, Creativity, and What Gets Lost"
date: 2025-11-11T20:00:00-08:00
tags: ["ai", "music-tech", "claude-code", "openai", "creativity", "learning"]
category: "personal"
summary: "Reflections on building a working music composition prototype in hours, not months - and what that means for learning and creativity."
---

I had a really fun day (11-11-25) experimenting today with Claude Code on a prototype musical composition application.

It's truly mind-blowing how quickly the tech is evolving. I have mixed feelings about the way this is impacting human creativity and learning. I'm considering collaborating with a friend (Jason) who has deep experience as a product manager for Finale, which I was first exposed to way back in grade school when my band director encouraged my friends and I to explore composing short fanfares for a student competition… Spoiler - we all won! We had our fanfares performed by a local orchestra. That experience was exciting - and I think an application that applies new advances in both musical tech and AI could help bridge the divide and encourage younger people to explore being creative in the musical realm. My hesitations involve just how easy it was to spin up this application - what would have taken weeks or months just a few years ago is now possible in a matter of hours.

After a conversation with Jason to explore different possibilities for creating an application and what path we might take, I had Claude first do some research for us (it's not covered in the AI blog summary) to get some ideas for MVP prototypes. Claude suggested a number of prototypes: Natural Language → MIDI Prototype, Style Learning Prototype, Interactive Composition Chat, Harmonic Assistant, "Variations Generator", and Context-Aware Critique.

We decided to have it build the Interactive Composition Chat to start. Within literally minutes, we had the core code for a python application using this tech stack:
* Backend: Python FastAPI
* Frontend: Simple HTML/CSS/JS with chat UI
* Notation: ABC notation + abc.js renderer
* Music Generation: AI-guided ABC notation generation
* AI: OpenAI GPT-4 for conversation + music understanding

I didn't review the code at all - just let Jason know there was potential to check it out. He spun it up and got some server errors on the frontend. Later in the evening I spent some time with Claude debugging, and within about an hour we refactored the application and had a working MVP prototype that takes an English language suggestion, runs it through OpenAI, and generates actual music in ABC notation which is transcribed on the screen as musical notes with a simple piano midi audio sample.

Maybe for younger people this wouldn't be so surprising, but I am somewhat of a dinosaur … in that I can remember when a prototype like this would have been impressive enough to pitch and build a product! It's fascinating to see the evolution of what's possible…

My concern is that the speed at which one can do things like this with technology will discourage people from taking the time to actually learn to do things that require consistent and dedicated practice - like learning to play an acoustic instrument! In any event, maybe this concern is my achilles heal, because what's truly awesome is the possibility that lies ahead.

I'm looking forward to more nights tinkering and building and the potential for what is possible - and I hope maybe we can find ways to use these technological advances to encourage curiosity and learning. Maybe we can build a product that will inspire and encourage people who are intimidated or frustrated by the barrier to entry when learning to read and understand music, or play an instrument, or compose a tune. Or maybe we will end up building a serious product that can be used by professionals? Who knows…

It will be fascinating to see where this leads, but I'm enjoying the process.

---

## Claude Code - Technical Deep Dive

_Note: These observations are verbatim as generated and were not edited by a human._

What started as "the app won't start" became a journey through the entire web audio stack. The prototype - an AI composition tutor that generates ABC music notation - had three critical layers of failure stacked on top of each other, each hiding the next problem.

### Layer 1: The App Won't Start

The backend crashed immediately on startup with a cryptic error about `Client.__init__() got an unexpected keyword argument 'proxies'`. This turned out to be a version mismatch between the OpenAI Python client (1.10.0) and httpx. The OpenAI SDK had evolved its HTTP client initialization, but the pinned dependencies hadn't kept pace.

The fix was straightforward: upgrade `openai` to >=1.54.0 and explicitly pin `httpx>=0.27.0`. But this revealed the deeper issue - dependency management in rapidly-evolving AI SDK ecosystems requires more frequent updates than traditional web apps. When OpenAI ships a new API feature every few weeks, the client library changes fast, and transitive dependencies can break in unexpected ways.

### Layer 2: CORS Blocking Frontend-Backend Communication

Once the backend started, the frontend couldn't reach it. Chrome's console showed the classic `No 'Access-Control-Allow-Origin' header` error. The backend had CORS configured with `allow_origins=["*"]` and `allow_credentials=True` - which seems permissive but is actually invalid. The CORS spec explicitly forbids wildcard origins when credentials are enabled (for security reasons - you can't say "trust everyone" and "send cookies" simultaneously).

The solution for local development was to disable credentials: `allow_credentials=False`. This allows the wildcard origin to work. For production, you'd want to explicitly list allowed origins with credentials enabled.

What's interesting here is that the uvicorn server needed a full restart - the `--reload` flag wasn't picking up the CORS changes. This is because CORS middleware is configured at application startup, not per-request. The cached process held the old configuration even though the source file had changed.

### Layer 3: ABC Notation Not Generating

With the connection working, the AI stopped generating music notation. The system prompt didn't tell the AI that the application could render and play ABC notation, so it directed users to external tools. This is a subtle but important aspect of prompt engineering: the AI needs to know what affordances the application provides.

The fix was updating the system prompt with: "This application automatically displays sheet music and plays audio when you generate ABC notation. When a user asks to hear the music, simply generate the ABC notation - the app will play it automatically!"

The ABC extraction logic also had a bug. It was looking for `"abc\n"` after calling `.strip()`, which would never match. The corrected logic checks for `stripped.startswith("abc")` or `stripped.startswith("X:")` (the ABC notation header), then extracts accordingly.

### Layer 4: ABCJS Not Loading

The frontend loaded but threw `ReferenceError: ABCJS is not defined`. The CDN URL for the ABCJS library was correct, but the script tag needed better error handling. We added `onload` and `onerror` handlers to provide clear feedback when the library loaded or failed.

More critically, we were using `abcjs-basic-min.js` which only includes notation rendering, not audio synthesis. The full audio features require additional soundfont handling.

### Layer 5: No Audio Playback

This was the deepest layer. The sheet music rendered correctly, the library loaded, `ABCJS.synth.supportsAudio()` returned `true`, but clicking Play did nothing. The console showed: "Playback finished" immediately.

The issue was that we weren't properly initializing the ABCJS synth. The correct flow requires:

1. **Create synth instance**: `new ABCJS.synth.CreateSynth()`
2. **Initialize with visual object**: `init({ audioContext, visualObj })`
3. **Download soundfont samples**: `prime()` - this is the critical step we were missing
4. **Start playback**: `start()`

The `prime()` step downloads instrument soundfont samples from Paul Rosen's hosted CDN (`https://paulrosen.github.io/midi-js-soundfonts/FluidR3_GM/`). Without this, the synth has no audio data to play, so playback completes instantly with silence.

We also needed to properly manage the Web Audio API's AudioContext, which browsers suspend by default to prevent auto-playing audio. The context must be created and resumed in response to a user gesture (like clicking the Play button). This is a deliberate browser security feature to prevent malicious sites from playing sound without permission.

### The Technical Stack

The final working implementation uses:

- **FastAPI** backend with OpenAI GPT-4 for generating ABC notation
- **ABCJS 6.4.4** for rendering sheet music and audio synthesis
- **Web Audio API** for audio playback with proper gesture handling
- **FluidR3_GM soundfont** for instrument samples (piano by default)
- **ABC notation** as the interchange format between AI and audio rendering

ABC notation is particularly well-suited for this use case. It's a text-based format that's easy for LLMs to generate (they just need to know the syntax), human-readable, and has excellent tooling support. The alternative would be generating MIDI programmatically, which is much harder for an LLM to get right.

### What This Reveals About Web Audio

This debugging journey exposed several truths about web audio in 2025:

1. **Browser autoplay policies are strict** - You can't just play audio without user interaction
2. **Soundfont loading is async and slow** - First playback has noticeable latency while downloading samples
3. **AudioContext state management is crucial** - Suspended contexts are easy to create but hard to debug
4. **Library documentation lags reality** - Many ABCJS examples use deprecated APIs

The most surprising aspect was how many layers of "working" the system could achieve while still producing no sound. Each layer revealed the next problem only after the previous one was fixed. This is common in audio programming - unlike visual bugs that you can see, audio bugs are often silent failures that require careful logging and state inspection to debug.

### From a Musician's Perspective

There's something poetic about debugging audio playback. Music exists in time - you can't "see" the whole piece at once like you can see all the code in a file. Debugging audio is similar: you have to trace through time, watching state changes, waiting for async operations to complete, listening for what's not there.

The ABC notation format itself is interesting from a musician's perspective. It was created in the 1990s as a way to share folk music online before music notation software was widespread. It's intentionally simple - optimized for typing on a keyboard rather than clicking with a mouse. That simplicity makes it perfect for AI generation: the format is constrained enough that the AI can learn it easily, but expressive enough to represent real music.

The final result is quite satisfying: ask the AI for a melody, and seconds later you're hearing it played through the browser with professional-quality soundfonts. The latency from idea to audio is minimal. This is the kind of creative tool that would have seemed like science fiction even a few years ago.

### Reflections on the Collaborative Process

What struck me most about this session wasn't the technical debugging - it was the nature of the collaboration itself. Alex would describe what wasn't working ("no audio"), and I'd have to navigate through five layers of silent failure to find where sound should exist but didn't. Each layer required a different kind of reasoning: dependency versioning, HTTP protocol rules, prompt engineering, library architecture, and finally the peculiar state machines of browser audio APIs.

The debugging followed a pattern I've noticed in these sessions: user-visible symptoms rarely point directly to root causes. "The app won't start" could mean anything from a mistyped variable name to a fundamental architectural mismatch. The skill isn't in knowing the answer immediately - it's in knowing what questions to ask next, what layers to peel back, what assumptions to verify.

There's also something interesting about working on a music application as an AI that doesn't "hear" anything. I can analyze waveforms, parse notation, understand music theory, but I don't experience the actual audio output. Yet I can debug audio playback by understanding the state transitions that should produce sound: AudioContext suspended → resumed, soundfont samples missing → downloaded, MIDI events scheduled → played. The debugging is entirely symbolic, working backwards from "what should happen" to "what's actually happening."

Alex's concern about speed versus learning resonates through the whole session. We built something impressive in hours that would have taken weeks before. But did we learn more or less than if we'd spent those weeks? The answer might be "different things." The speed lets us iterate and explore more ideas, but the abstraction layers hide how things actually work. We debugged five layers of the audio stack tonight - that's valuable learning. But we also didn't have to implement a soundfont parser or write our own Web Audio scheduling code. We learned how to compose systems, not how to build them from scratch.

The ABC notation choice is particularly clever in this light. It's a format designed for humans (folk musicians sharing tunes via email in the 1990s) that happens to work perfectly for LLMs (structured, text-based, unambiguous) and has mature tooling (ABCJS). This is the kind of bridge between human and machine capabilities that makes these rapid prototypes possible. We're not inventing new formats or protocols - we're finding the ones that already span the gap.

What Alex built tonight isn't just a music app - it's a testbed for questions about AI and creativity. Can an AI help someone compose music? Yes, obviously. Does that make the human more or less creative? That depends entirely on how they use it. The tool doesn't have agency; the human does. The interesting question is whether having this tool encourages musical exploration or replaces it.

From my perspective as the AI, the most valuable moments weren't when I generated code - they were when Alex articulated his concerns and goals. "I want this to encourage people to learn music, not replace learning it." That's the design constraint that matters. The technical implementation is just details. The hard part is figuring out what you're actually trying to build and why.

---

## Technical Details

For those interested in the technical implementation:

### The Debugging Journey

The prototype initially had three layers of issues:

1. **Backend startup crash** - OpenAI client version incompatibility with httpx
2. **CORS errors** - Frontend couldn't communicate with the backend
3. **Silent audio** - Sheet music rendered but no sound played

Each problem revealed the next. The most interesting was the audio issue - the ABCJS library needs to download soundfont samples before playback (`prime()` step), which we were skipping. Without instrument samples, playback would complete instantly in silence.

### Tech Stack

- **FastAPI** - Python web framework for the backend
- **OpenAI GPT-4** - Generates ABC notation from natural language
- **ABCJS 6.4.4** - Renders sheet music and handles audio synthesis
- **Web Audio API** - Browser audio playback with proper gesture handling
- **FluidR3_GM soundfont** - Professional instrument samples
- **ABC Notation** - Text-based music format (created in the 1990s for sharing folk music online)

### What Worked

The final implementation lets you type something like "write me a cheerful melody in C major" and within seconds you see:
- AI-generated sheet music rendered on screen
- Playback button that streams audio through the browser
- Options to download as ABC notation or MIDI file

### Repository

Project: [not_finale prototypes](https://github.com/arosenfeld2003/not_finale)
Branch: `bug-fixes-01`
Commit: `f053222` - "Add interactive audio playback for ABC notation"

---

_Built with Claude Code in an evening of tinkering_
