---
title: "Building an AI Music Composition App: Speed, Creativity, and What Gets Lost"
date: 2025-11-12T22:00:00-08:00
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
