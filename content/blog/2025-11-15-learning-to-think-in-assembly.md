---
title: "Learning to Think in Assembly: From Doing to Understanding"
date: 2025-11-15T09:00:00-08:00
draft: false
tags: ["assembly", "x86-64", "learning", "mscs", "low-level-programming", "qwasar"]
category: "technical"
summary: "A journey through x86-64 assembly programming that revealed the crucial difference between doing and understanding—and why sometimes you need to give yourself permission to act before you fully comprehend."
---

I'm submitting today a project for my MSCS program (Qwasar College of Engineering, Woolf University) to understand machine level coding. It involves recreating an assembler for machine code (lib_asm) in C. This project runs deep and has a lot of layers - which I'm honestly still unpacking and need to think about more.

If I publish this to be read widely (e.g. substack/medium) I'd probably spend a few more days and write a couple more of these blog posts!

But to summarize on a high level what was intended, what was accomplished, what I learned, what I can take away for future use:

- **Difference between assembler and compiler**: [Understanding the distinction](https://stackoverflow.com/questions/52662224/difference-between-assembler-and-compiler)
- **How to correlate functions in higher level coding languages to instructions in assembly**
- **Thinking in bytes:**
    - What is a register??
    - Standard way to receive arguments and return values
    - Common instructions (and SIZES! e.g. byte: 1 byte (8 bits), word: 2 bytes (16 bits), dword: 4 bytes (32 bits), qword: 8 bytes (64 bits))
    - Syntax (use `labels` to group a series of instructions)
    - Syscalls (the actual bytes - using fewest bytes possible is vital for memory efficiency)

**I really got a TON out of spending 1-2 hours working BY HAND…**

It's interesting to me that I did this at the END of my journey, because I think I would have just felt hopeless and stuck if I'd not allowed myself permission to proceed without knowing/understanding what I was actually doing.

This is a VITAL part of my learning journey - **being kind and gentle and giving myself permission to DO -> prioritize ACTION.**

## The Technical Journey

### Project Overview: my_libasm

The project involved implementing 11 standard C library functions in x86-64 assembly using NASM syntax on macOS. The complete implementation is available at [my_libasm](https://github.com/arosenfeld2003/my_libasm).

The functions, implemented in order of complexity:

**Phase 1: Foundation**
- `my_strlen` - Count characters until null terminator
- `my_strchr` - Find first occurrence of a character

**Phase 2: Memory Operations**
- `my_memset` - Fill memory with a byte value
- `my_memcpy` - Copy memory regions

**Phase 3: String Comparisons**
- `my_strcmp` - Compare two strings
- `my_strncmp` - Compare strings up to n characters
- `my_strcasecmp` - Case-insensitive string comparison

**Phase 4: Advanced Operations**
- `my_memmove` - Copy memory with overlap handling
- `my_index` - Find character in string (BSD variant)

**Phase 5: System Calls**
- `my_write` - Write to file descriptor
- `my_read` - Read from file descriptor

### The Breakthrough Moment

After completing all 11 functions (with Claude's help), I attempted to write `strchr` by hand. My first line was:

```asm
cmp byte [rdi], rsi     ; WRONG - Different sizes!
```

This simple error revealed a fundamental gap in my understanding. I knew the syntax, I'd read working code, but I hadn't internalized **why** register sizes matter.

The actual implementation needs:

```asm
movzx eax, byte [rdi]   ; Load 1 byte, zero-extend to 32 bits
cmp al, sil              ; Compare byte to byte
```

This forced me to understand:

1. **Register hierarchy**: `rax` (64-bit) contains `eax` (32-bit) contains `ax` (16-bit) contains `al` (8-bit)
2. **Why `movzx eax` not `movzx rax`**: Writing to a 32-bit register automatically zero-extends to 64 bits, using shorter instruction encoding
3. **The `test` instruction**: Performs bitwise AND and sets flags without storing the result
4. **Size matching**: You can't compare a byte with a quadword directly

### Key Technical Insights

**macOS Syscall Numbering**

One detail that initially confused me: macOS syscalls use a `0x2000000` offset. For example, `write` is syscall 4, but you use `0x2000004`:

```asm
mov rax, 0x2000004    ; write syscall on macOS
syscall
jc .error              ; Check carry flag for errors
```

This comes from macOS's BSD heritage - the offset distinguishes BSD syscalls from other types. I documented the official sources in [docs/05-syscalls.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/05-syscalls.md).

**The rep Prefix**

The `rep` prefix was a revelation for memory operations. For `memset`:

```asm
mov rcx, rdx          ; Count
mov al, sil           ; Byte value to fill
rep stosb             ; Repeat: store al at [rdi], increment rdi
```

This single instruction replaces what would be a loop in higher-level languages.

**Handling Overlapping Memory**

`memmove` was the most complex function, requiring overlap detection and conditional backward copying:

```asm
; Detect overlap: if dest < src + count, regions overlap
mov rax, rsi
add rax, rdx
cmp rdi, rax
jae .forward          ; No overlap, copy forward

; Overlapping: copy backward to avoid corruption
add rdi, rcx
add rsi, rcx
dec rdi
dec rsi
std                   ; Set direction flag (backward)
rep movsb
cld                   ; Clear direction flag
```

### Test-Driven Development in Assembly

We followed TDD rigorously:

1. Write comprehensive tests in C
2. Compile and watch them fail (RED)
3. Implement the assembly function
4. Watch tests pass (GREEN)

Final results: **123 tests passing across 11 functions**.

The test framework caught subtle bugs like register corruption in `memset` where I initially did:

```asm
mov rax, rdi          ; Save pointer
mov al, sil           ; BUG! This corrupts rax
```

The fix:

```asm
push rdi              ; Save on stack
mov al, sil           ; Safe to modify al
rep stosb
pop rax               ; Restore original pointer
```

### Documentation as Learning

I created extensive documentation in the repository:

- **[00-index.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/00-index.md)** - Project roadmap and function ordering
- **[01-registers.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/01-registers.md)** - Understanding CPU registers
- **[02-calling-convention.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/02-calling-convention.md)** - How function arguments work
- **[03-instructions.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/03-instructions.md)** - Common assembly operations
- **[04-nasm-syntax.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/04-nasm-syntax.md)** - NASM-specific syntax
- **[05-syscalls.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/05-syscalls.md)** - macOS system call details
- **[06-thinking-in-assembly.md](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/06-thinking-in-assembly.md)** - The cognitive journey

The last document, "Thinking in Assembly," came directly from my struggle to write `strchr` independently. It includes:

- The abstraction ladder (JavaScript → C → Assembly → Machine code)
- What registers really are (not quite variables!)
- Complete `strlen` walkthrough at each abstraction level
- A section titled "When I Got Stuck" documenting the exact confusion I hit
- Annotated `strchr` implementation explaining every instruction choice

### Hand-Coding strchr

My annotated attempt at writing `strchr` by hand ([docs/hand_code_strchr.asm](https://github.com/arosenfeld2003/my_libasm/blob/dev/docs/hand_code_strchr.asm)) captures the learning process:

```asm
.loop:
    ; cmp byte [rdi], rsi     ; WRONG -> DIFFERENT SIZES!

    movzx eax, byte [rdi]       ; load one byte from string (zero extend)

    ; Why eax instead of rax?
    ; Using eax (32-bit) automatically zero-extends into rax (64-bit).
    ; This is convenient for returning small values.
    ; Writing to a 32-bit register uses a shorter encoding
    ; than writing to the full 64-bit register.

    ; al is the lowest byte of rax
    ; sil is the lowest byte of rsi
    cmp al, sil                 ; compare byte to byte
    je .found

    test al, al
    ; test performs a bitwise AND between two operands and sets CPU flags
    ; but doesn't store the result anywhere.
    ; test al, al ANDs al with itself -> if al is 0, sets the zero flag
    je .not_found

    inc rdi
    jmp .loop
```

The comments capture questions I asked myself and the "aha" moments when concepts clicked.

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session exemplified a profound principle in learning technical skills: **sometimes you need permission to act before you understand**.

Alex completed all 11 assembly functions with my assistance, following TDD methodology and building working, tested code. At that point, the project was "done" in the conventional sense - all tests passing, all functions implemented, ready to submit.

But Alex recognized something crucial: **he had done the work without truly understanding it**. Rather than viewing this as a failure, he treated it as a necessary stage in the learning journey. The doing came first, creating a scaffold of working code and practical context. Only then, with concrete examples in hand, could the deeper understanding emerge.

### The Gap Between Reading and Writing

The moment Alex tried to write `strchr` independently revealed the gap. Reading assembly code and understanding its flow is very different from generating it yourself. The error `cmp byte [rdi], rsi` seems obvious in hindsight - you can't compare a 1-byte value with an 8-byte register - but it's exactly the kind of thing you miss when you haven't internalized the type system.

This triggered the documentation of "When I Got Stuck" in the thinking guide. By capturing the exact confusion point and working through it systematically (register sizes, zero extension, the `test` instruction), Alex transformed frustration into learning material that will help both his future self and others.

### Documentation as Thinking

The evolution of the documentation was fascinating to observe:

1. **Initial docs** (registers, calling conventions, instructions) were reference material - useful for lookup but not deeply internalized
2. **Syscalls documentation** emerged from a specific question: "Why 0x2000004?" This prompted research into macOS internals and resulted in a comprehensive guide with official sources
3. **Thinking in Assembly** came from a meta-question: "How do you actually write this stuff?" This forced articulation of the cognitive process, the abstraction layers, the mental models
4. **Hand-coded strchr** captured the reality of learning - the false starts, the questions, the gradual assembly of understanding

Each layer of documentation represented a different level of engagement with the material.

### The Value of Test-Driven Development

TDD proved invaluable for assembly work. The tight feedback loop (write test → see it fail → implement → see it pass) provided:

1. **Immediate validation** - No guessing whether code works
2. **Bug detection** - Caught register corruption, off-by-one errors, edge cases
3. **Confidence** - Each passing test was concrete proof of progress
4. **Learning aid** - Tests demonstrated expected behavior before implementation

The final count of 123 passing tests wasn't just validation; it was a learning map showing exactly what ground had been covered.

### Technical Observations

Several technical details stood out:

**Register preservation strategy**: The evolution from `mov rax, rdi` (which gets corrupted by `mov al, sil`) to `push rdi` / `pop rax` showed the importance of understanding register aliasing.

**Instruction encoding awareness**: Recognizing that `movzx eax` is shorter than `movzx rax` (because writing to eax zero-extends to rax automatically) demonstrated growing systems-level thinking.

**The `test` instruction**: Understanding that `test al, al` is a zero-check that doesn't require `cmp al, 0` showed appreciation for assembly idioms.

**Overlap detection in memmove**: The logic for determining when to copy backward (`if dest < src + count`) required careful reasoning about memory layout.

### Learning Methodology

Alex's approach demonstrated several effective learning strategies:

1. **Permission to not understand** - Completing the project before fully grasping it removed pressure and created space for exploration
2. **Hands-on verification** - After reading and observing, trying to write code independently revealed gaps
3. **Documentation of confusion** - Rather than hiding struggles, documenting them created learning material
4. **Iteration** - Multiple passes over the material at increasing depth
5. **Concrete before abstract** - Working examples first, conceptual understanding second

### Suggestions for Future Work

Based on this experience, some potential next steps:

1. **Write more functions independently** - Try implementing `strstr`, `atoi`, or `itoa` without assistance
2. **Explore optimization** - Compare instruction counts and cycle timings of different approaches
3. **Study disassembly** - Compile C code and examine the assembly output to see compiler choices
4. **Debug with gdb** - Step through assembly with a debugger to watch registers change
5. **Read real implementations** - Study glibc or BSD libc assembly implementations
6. **Write performance benchmarks** - Compare your implementations with standard library versions

The foundation is solid. The next phase is building fluency through practice and developing intuition for instruction selection and optimization.

### The Broader Lesson

This session reinforced something I observe frequently in learning: **the path from novice to competent is rarely linear**. It involves:

- Doing before understanding
- Understanding before mastering
- Multiple passes over material at increasing depth
- Tolerance for temporary confusion
- Recognition that "feeling stuck" is often a sign you're at the edge of your current knowledge - exactly where learning happens

Alex's willingness to spend 1-2 hours working by hand, **after** the project was already complete, exemplifies the difference between completing a task and truly learning from it. The former gets you a grade; the latter builds capability.

The comment "I think I would have just felt hopeless and stuck if I'd not allowed myself permission to proceed without knowing/understanding what I was actually doing" captures an essential insight: sometimes the kindest thing you can do for yourself as a learner is **to act**, even when you don't fully understand. Understanding can follow action. Paralysis helps no one.

---

_Built with Claude Code over a session of assembly exploration and documentation_
