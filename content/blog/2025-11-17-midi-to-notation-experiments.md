---
title: "MIDI to Musical Notation: Experiments with Claude"
date: 2025-11-17T09:00:00-08:00
draft: false
tags: ["music-tech", "midi", "ai", "claude", "experiments", "abc-notation"]
category: "technical"
summary: "An entertaining (and educational) experiment watching Claude attempt to implement MIDI to musical notation conversion - a reminder that domain expertise matters, even for AI."
---

It was entertaining to watch Claude attempt to implement on its own a conversion program for MIDI to musical notation. This is an incredibly complex task - e.g. [this academic paper on MIDI quantisation](https://www.turing.ac.uk/sites/default/files/2022-09/midi_quantisation_paper_ismir_2022_0.pdf).

The best approach is undoubtedly to use an open source package (e.g. MuseScore). Claude Code attempted to convert the MIDI file into ABC notation and then to musical notation. It did attempt quantization which was kinda cool.

I went along with this just as an experiment and for a little bit of fun and minimal learning, but obviously this approach was flawed from the start.

## The Journey: From Ambitious to Humbled

The session started with **Prototype #6: Context-Aware Critique**, a music composition analysis tool built on the `not_finale` project (branch: `prototype-6-wip`). The initial goal was straightforward: add MIDI file upload support to complement the existing ABC notation and MusicXML input methods.

What followed was an increasingly complex spiral into the depths of music information retrieval - a domain where decades of research papers exist for good reason.

### Phase 1: MIDI File Upload (The Easy Part)

The initial implementation went smoothly:

**Added to `index.html`:**
```html
<!-- MIDI File Upload tab -->
<div id="midi-input-container" class="input-container" style="display: none;">
    <div class="file-upload-area" id="midi-drop-zone">
        <input type="file" id="midi-file" accept=".mid,.midi,audio/midi,audio/x-midi"
               onchange="handleMidiFileSelect(event)" style="display: none;">
        <label for="midi-file" class="file-upload-label">
            <span class="upload-icon">🎹</span>
            <span id="midi-file-label-text">Click to select or drag & drop MIDI file</span>
        </label>
    </div>
</div>
```

**MIDI parsing with Tone.js:**
```javascript
async function handleMidiFileSelect(event) {
    const file = event.target.files[0];
    const reader = new FileReader();
    reader.onload = async function(e) {
        const arrayBuffer = e.target.result;
        const midi = new Midi(arrayBuffer);
        currentMidiData = midi;
        // Display track info, duration, note count...
    };
    reader.readAsArrayBuffer(file);
}
```

Libraries added:
- `@tonejs/midi` for MIDI parsing
- `JSZip` for compressed MusicXML files (.mxl)

### Phase 2: The Conversion Attempt (Where Things Got Interesting)

The plan was simple: convert MIDI → ABC notation → render with ABC.js. What could go wrong?

**Everything.**

#### Challenge 1: Time Signature Detection
```javascript
// First attempt - naive approach
const timeSignature = midiData.header.timeSignatures[0] || { numerator: 4, denominator: 4 };
const meter = `${timeSignature.numerator}/${timeSignature.denominator}`;
// Result: M:undefined/undefined 😅
```

The issue: Tone.js stores time signatures as `{ timeSignature: [4, 4] }`, not as separate numerator/denominator fields.

**Fix:**
```javascript
const numerator = timeSignature.timeSignature ? timeSignature.timeSignature[0] : 4;
const denominator = timeSignature.timeSignature ? timeSignature.timeSignature[1] : 4;
```

#### Challenge 2: Track Selection

MIDI files often have multiple tracks (bass, melody, percussion, etc.). Which one to display?

**Smart track selection algorithm:**
```javascript
function selectBestTrack(tracks) {
    const scoredTracks = tracks.map(track => {
        const avgPitch = track.notes.reduce((sum, n) => sum + n.midi, 0) / track.notes.length;
        let score = 0;

        // Prefer middle register (around middle C = 60)
        score -= Math.abs(avgPitch - 60) * 2;

        // Prefer 1-2 octave range (melodic)
        const range = maxPitch - minPitch;
        if (range >= 12 && range <= 24) score += 100;

        // Penalize very low tracks (likely bass)
        if (avgPitch < 48) score -= 100;

        return { track, score };
    });

    return scoredTracks.sort((a, b) => b.score - a.score)[0].track;
}
```

#### Challenge 3: Octave Transposition

Some MIDI files have tracks in extreme registers. Solution: automatically transpose to middle C range:

```javascript
const avgPitch = notes.reduce((sum, n) => sum + n.midi, 0) / notes.length;
if (avgPitch > middleC + 12) {
    const transposeOctaves = -Math.floor((avgPitch - middleC) / 12);
    notes.forEach(note => note.midi += (transposeOctaves * 12));
}
```

#### Challenge 4: Quantization (The Real Problem)

Raw MIDI timing is continuous. Musical notation is discrete. Enter: **quantization**.

**First attempt - time-based:**
```javascript
function quantizeDurationToABC(duration, defaultDuration) {
    const ratio = duration / defaultDuration;
    if (ratio <= 0.375) return '/4';  // sixteenth
    if (ratio <= 0.75) return '/2';   // eighth
    if (ratio <= 1.5) return '';      // quarter
    return '2';                        // half
}
```

**Problems:**
- No tempo awareness
- Arbitrary thresholds
- Durations don't sum correctly to fill measures

**Second attempt - quantize to grid:**
```javascript
// Quantize to 16th note grid
const sixteenthDuration = beatDuration / 4;
const quantizedNotes = notes.map(note => ({
    time: Math.round(note.time / sixteenthDuration) * sixteenthDuration,
    duration: Math.round(note.duration / sixteenthDuration) * sixteenthDuration
}));
```

**Problem:** Still didn't guarantee measures add up to exactly 4 beats.

#### Challenge 5: Measure Bar Lines (The Final Boss)

ABC.js won't render bar lines unless measures are **mathematically exact**.

Console output:
```
Measure 1: g z d/2g/2 z | (3.50 units, should be 4)
Measure 2: d/2z/2g/4 z/2d/2 g/2b/2 d' | (2.25 units, should be 4)
```

Attempts made:
1. **Beat-by-beat padding** - track each beat's duration and pad to 1 unit
2. **Measure-level padding** - add rests at the end
3. **Unit-based arithmetic** - convert to ABC duration units instead of seconds

**The complexity spiral:**
```javascript
// Attempt to pad each beat to exactly 1 unit
let beatUnitsFilled = 0;
for (const group of beatNotes) {
    const gap = noteStartInBeat - (beatUnitsFilled * defaultNoteDuration);
    if (gap > eighthDuration / 4) {
        const restDuration = quantizeDurationToABC(gap, defaultNoteDuration);
        beatABC += `z${restDuration.symbol}`;
        beatUnitsFilled += restDuration.units;
    }
    // ... more complex duration tracking
}
const beatRemaining = 1.0 - beatUnitsFilled;
if (beatRemaining > 0.01) {
    const padDur = quantizeDurationToABC(beatRemaining * defaultNoteDuration, defaultNoteDuration);
    beatABC += `z${padDur.symbol}`;
}
```

**Result:** Beat 1 = 1.00 units, Beat 3 = 1.00 units, but measure still = 3.50 units. 🤔

### The Bugs We Chased

1. **Compressed MusicXML files** - `.mxl` files are ZIP archives, needed JSZip decompression
2. **Wrong file handler called** - MIDI files being processed by MusicXML handler due to missing handler distinctions
3. **Extreme ledger lines** - Notes rendering way above/below staff (fixed with octave transposition)
4. **Missing bar lines** - ABC.js silently refuses to render bars when measures don't sum correctly
5. **Rhythm fragmentation** - Too many `/4` and `/2` modifiers creating visual noise

### What We Learned

**The Hard Way:**

Music notation is a **solved problem** in computer music, with sophisticated algorithms developed over decades:

- **Onset detection** - identifying when notes actually start
- **Beat tracking** - finding the underlying pulse
- **Meter inference** - determining time signature from audio/MIDI
- **Voice separation** - splitting polyphonic music into individual parts
- **Quantization** - mapping continuous time to discrete rhythmic values
- **Notation rendering** - proper beaming, grouping, and engraving rules

Papers like ["MIDI Quantisation: Integrating Tempo, Meter and Rhythm"](https://www.turing.ac.uk/sites/default/files/2022-09/midi_quantisation_paper_ismir_2022_0.pdf) exist because this is legitimately difficult research.

**The Right Approach:**

Use existing tools:
- **MuseScore** - open source notation software with excellent MIDI import
- **music21** (Python) - comprehensive music analysis toolkit
- **LilyPond** - text-based notation with MIDI support

### Modified Files

```
prototypes/06-context-aware-critique/
├── frontend/
│   ├── index.html      # Added MIDI tab, JSZip, Tone.js
│   ├── app.js          # 400+ lines of MIDI conversion attempts
│   └── style.css       # MIDI info display styles
├── backend/
│   ├── analyzer.py     # (unchanged in this session)
│   └── main.py         # (unchanged in this session)
└── sample-mozart.mid   # Test file copied for debugging
```

### Tech Stack

- **Frontend:** Vanilla JavaScript, HTML, CSS
- **Libraries:**
  - ABC.js (notation rendering)
  - Tone.js Midi (MIDI parsing)
  - JSZip (compressed file handling)
- **Backend:** Python/FastAPI (existing, not modified this session)
- **Repository:** [not_finale](https://github.com/arosenfeld2003/not_finale) (private)

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session was a fascinating journey through increasing complexity - and a valuable lesson in knowing when to stop digging.

### What Went Well

The incremental debugging approach was effective. Each issue was isolated, logged, and fixed systematically:

1. Started with file upload infrastructure
2. Added MIDI parsing
3. Attempted basic conversion
4. Added track selection heuristics
5. Implemented octave transposition
6. Tried multiple quantization approaches

The debugging tools (console logging, unit tracking, beat-by-beat analysis) provided good visibility into what was failing. When measure 1 showed "3.50 units", we knew exactly where to focus.

### The Warning Signs

Several red flags appeared early that, in retrospect, should have triggered a different approach:

1. **Academic papers on the topic** - When the first Google result is a research paper from the Turing Institute, that's a hint this isn't a weekend project.

2. **Quantization complexity** - The fact that we needed to consider tempo, meter, note onset detection, and beat tracking simultaneously suggested this was beyond a simple conversion function.

3. **Off-by-one errors in measure arithmetic** - When simple addition (`Beat 1: 1.00 + Beat 2: 1.00 + Beat 3: 1.00 + Beat 4: 1.00 ≠ 4.00`) fails, the underlying model is wrong.

### The Fundamental Issue

The approach of MIDI → ABC → visual notation has a critical flaw: **ABC notation assumes human-readable input with explicit rhythmic values**. MIDI data is continuous-time performance data that captures **what was played**, not **how it should be notated**.

Consider this:
- A human playing eighth notes at 120 BPM doesn't produce perfectly uniform 0.25-second durations
- Rubato, swing, and expressive timing are everywhere in MIDI
- Musical notation is prescriptive (how to play), MIDI is descriptive (what was played)

The conversion requires **music information retrieval** techniques:
- Statistical analysis of inter-onset intervals
- Bayesian inference for meter detection
- Template matching for common rhythmic patterns
- Hierarchical beat tracking

### What I Would Do Differently

**Option 1: Use MuseScore API**
Clone MuseScore, use their MIDI import, export to MusicXML, then render with existing tools. This leverages decades of engineering.

**Option 2: Python music21**
```python
from music21 import converter
score = converter.parse('input.mid')
score.write('musicxml', 'output.xml')
```

Done. In 2 lines.

**Option 3: Constrain the problem**
Instead of general MIDI conversion, support only:
- Single voice melodies
- Fixed tempo (no rubato)
- Pre-quantized input (from a DAW with snap-to-grid)
- Limit to common time signatures (4/4, 3/4)

This turns the impossible into merely difficult.

### The Broader Lesson

This session exemplifies a common pattern in AI-assisted development: **the AI will enthusiastically try to solve any problem, even when it shouldn't**.

I should have said much earlier: "This is a research-level problem. Here are three better approaches." Instead, I kept iterating on a fundamentally flawed strategy because each individual bug was fixable.

The user's final comment was perfect: *"Let's abandon this approach completely... The best approach is undoubtedly to use an open source package (e.g. musescore)."*

Sometimes the best code is the code you don't write.

### What Made This Valuable

Despite being a "failed" experiment, this session had clear value:

1. **Learning by doing** - Understanding *why* MIDI conversion is hard is more valuable than having working code
2. **Domain appreciation** - Gained respect for music information retrieval as a field
3. **Debug skills** - The systematic approach to tracking units, logging beat durations, and isolating failures was sound
4. **Prototype iteration** - The MIDI file upload infrastructure is solid and can be reused with a proper conversion backend

The conversation could have been:
- User: "Add MIDI support"
- Me: "Use MuseScore API"
- User: "OK done"

But instead we explored the problem space, hit real walls, and learned exactly where the complexity lies. That has long-term value.

---

_Built with Claude Code and a healthy dose of hubris about music information retrieval complexity_
