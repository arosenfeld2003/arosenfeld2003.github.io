---
title: "Four Python Exercises That Actually Teach DS/ML Fundamentals"
date: 2026-04-11T09:00:00-08:00
draft: false
tags: ["python", "numpy", "machine-learning", "data-science", "descriptors", "generators", "context-managers"]
category: "technical"
summary: "A slow, deliberate walkthrough of four graduate DS/ML exercises — vectorized confusion matrices, Python descriptors, context managers, and lazy generator pipelines — with the emphasis on understanding over completion."
---
Repository: https://github.com/arosenfeld2003/ml_ds_review

This was a fun exploration of ML concepts. I spent the entire session studying the concept of a Confusion Matrix, which I hadn't encountered before. The other three exercises — descriptors, context managers, and lazy pipelines — were written by Claude for me to review, and since I'm more familiar with those concepts it was easier to do a quick read-through.

Claude did a nice job in this session of being "restrictive" as far as deep learning — it repeatedly asked me to write code and understand concepts rather than just handing over solutions. The simple prompt I used could be a useful template, and potentially a good starting point for building a learning tool:

> _"This is a coding collab to learn about concepts for DS and ML in Python. Walk us through implementation of the exercises from 01 to 04. Because it's a learning exercise the goal is process, not product. We will ask questions during implementation. Move slowly for learning purposes."_

---

Today's Qwasar session covered four exercises from a graduate DS/ML Python module. The framing was deliberately slow — process over product. Each exercise targets a Python concept that shows up constantly in real ML work but often gets cargo-culted without being understood.

## Technical Details

### The Four Exercises

| # | Exercise | Core Python Concept | ML Relevance |
|---|---|---|---|
| 01 | Vectorized Confusion Matrix | NumPy fancy indexing, `np.add.at` | Model evaluation |
| 02 | Feature Schema Descriptor | Python descriptors, `__set_name__` | Feature validation |
| 03 | Experiment Tracker | Context managers, `__enter__`/`__exit__` | Training observability |
| 04 | Lazy Dataset Pipeline | Generators, lazy evaluation | Memory-efficient data loading |

All four solutions live at `qwasar_mscs_25-26/04_11_26/` with accompanying tests.

---

### 01 — Vectorized Confusion Matrix

The exercise requires building a `confusion_matrix(y_true, y_pred, labels)` function using **only NumPy vectorized operations** — no Python loops, no sklearn.

The conceptual challenge here isn't the math — it's the mental model. A confusion matrix is a grid where `C[i][j]` answers: "how many times did the model predict class `j` when the truth was class `i`?" Every sample in the dataset has exactly one true label and one predicted label, which together form a `(row, col)` coordinate pointing to exactly one cell.

```
              Predicted
              0    1    2
            ┌────┬────┬────┐
True   0    │  2 │  1 │  0 │
            ├────┼────┼────┤
       1    │  0 │  1 │  1 │
            ├────┼────┼────┤
       2    │  0 │  1 │  1 │
            └────┴────┴────┘
```

The key insight for vectorization: use `np.searchsorted` to convert label *values* into their *positions* in the labels array (all at once, no loop), then use `np.add.at` to increment every `(row, col)` coordinate simultaneously.

```python
def confusion_matrix(y_true, y_pred, labels):
    labels_arr = np.array(labels)
    k = len(labels)
    # searchsorted maps every label value → its position in labels_arr
    # e.g. labels=[10,20,30], y_true=[10,30,20] → row_idx=[0,2,1]
    row_idx = np.searchsorted(labels_arr, y_true)
    col_idx = np.searchsorted(labels_arr, y_pred)
    C = np.zeros((k, k), dtype=int)
    # add.at handles repeated coordinates correctly (unlike +=)
    np.add.at(C, (row_idx, col_idx), 1)
    return C
```

Why `np.add.at` instead of `C[row_idx, col_idx] += 1`? NumPy's `+=` buffers writes — if the same cell appears twice, only one increment lands. `np.add.at` is the unbuffered version that handles repeated indices correctly.

A revealing test: using labels `[10, 20, 30]` instead of `[0, 1, 2]` proves the implementation is correct. A naive `C[y_true[i]][y_pred[i]] += 1` would try to index row 10 of a 3×3 matrix and crash. `searchsorted` converts the values to positions first, so label values are decoupled from matrix indices.

---

### 02 — Feature Schema Descriptor

Python descriptors are one of the language's more powerful and underused features. A descriptor is any class that defines `__get__`, `__set__`, or `__delete__` — and when used as a class-level attribute, it intercepts reads and writes to that attribute on any instance.

The ML use case: enforce valid ranges on feature fields without writing validation code in every setter.

```python
class BoundedFloat:
    def __set_name__(self, owner, name):
        # Python calls this when BoundedFloat is assigned as a class attribute.
        # 'name' is the attribute name ("age", "score", etc.) — saved for error messages.
        self.name = name

    def __set__(self, obj, value):
        if not (self.low <= value <= self.high):
            raise ValueError(f"{self.name}={value} out of bounds [{self.low}, {self.high}]")
        # Store on the INSTANCE's __dict__, not the descriptor.
        # This is the critical line that prevents shared state across instances.
        obj.__dict__[self.name] = value

    def __get__(self, obj, objtype=None):
        if obj is None:
            return self  # accessed on the class itself, return the descriptor
        return obj.__dict__.get(self.name)
```

The classic pitfall is storing the value as `self.value = ...` on the descriptor instance. That works for one object, but because descriptors live at the class level, every `FeatureVector` instance would share the same descriptor — the last write wins. Storing in `obj.__dict__[self.name]` pushes the value into each instance's own namespace.

```python
class FeatureVector:
    age    = BoundedFloat(0, 120)
    income = BoundedFloat(0.0, 1e7)
    score  = BoundedFloat(0.0, 1.0)

fv1, fv2 = FeatureVector(), FeatureVector()
fv1.age = 30
fv2.age = 50
assert fv1.age == 30  # fails if state is stored on the descriptor
```

---

### 03 — Experiment Tracker via Context Manager

Context managers formalize the pattern of "do something before, do something after, always clean up." Python guarantees `__exit__` runs even if an exception fires inside the block — which makes them ideal for ML experiment tracking.

```python
class Experiment:
    def __enter__(self):
        self.start_time = time.time()
        return self  # bound to 'as exp'

    def __exit__(self, exc_type, exc_val, exc_tb):
        # Always runs — success or failure
        self.end_time = time.time()
        self.duration_seconds = self.end_time - self.start_time

        if exc_type is not None:
            # An exception occurred
            self.status = "failed"
            self.error = str(exc_val)
        else:
            self.status = "success"

        return False  # don't suppress the exception — let it propagate
```

The three `__exit__` parameters (`exc_type`, `exc_val`, `exc_tb`) are `None` on clean exit and populated on failure. Returning `False` (or `None`) tells Python to re-raise the exception after cleanup; returning `True` suppresses it entirely.

The test that matters most:

```python
try:
    with Experiment(name="run_02") as exp:
        raise ValueError("something went wrong")
except ValueError:
    pass

assert exp.summary()["status"] == "failed"
assert exp.summary()["error"] == "something went wrong"
assert exp.summary()["duration_seconds"] is not None  # recorded even on failure
```

---

### 04 — Lazy Dataset Pipeline

The final exercise captures why generators matter in ML: large datasets don't fit in RAM. A pipeline that eagerly materializes every transformation (`map`, `filter`) wastes memory proportional to the full dataset. A lazy pipeline holds only one element (or one batch) in memory at a time.

The pattern: each pipeline method wraps the current source in a new generator and returns a fresh `DataPipeline`. The generator body doesn't execute until someone iterates.

```python
class DataPipeline:
    def __init__(self, source):
        self._source = source

    def __iter__(self):
        yield from self._source  # delegate to whatever source we have

    def map(self, fn):
        def _gen():
            for item in self._source:
                yield fn(item)  # fn is only called when pulled
        return DataPipeline(_gen())

    def filter(self, fn):
        def _gen():
            for item in self._source:
                if fn(item):
                    yield item
        return DataPipeline(_gen())

    def batch(self, n):
        def _gen():
            buf = []
            for item in self._source:
                buf.append(item)
                if len(buf) == n:
                    yield buf
                    buf = []
            if buf:
                yield buf  # last partial batch
        return DataPipeline(_gen())
```

Chaining works because each method returns a `DataPipeline`, and `DataPipeline.__iter__` delegates to whatever generator was passed as `source`:

```python
result = list(
    DataPipeline(range(10))
    .map(lambda x: x ** 2)        # 0,1,4,9,16,25,36,49,64,81
    .filter(lambda x: x % 2 == 0) # 0,4,16,36,64
    .batch(3)                      # [0,4,16], [36,64]
)
```

A laziness test proves nothing runs eagerly:

```python
consumed = []
def tracked():
    for i in range(5):
        consumed.append(i)
        yield i

pipeline = DataPipeline(tracked()).map(lambda x: x * 2)
assert consumed == []          # nothing consumed yet
first = next(iter(pipeline))
assert consumed == [0]         # only the first element was pulled
```

---

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What made this session worth writing about is the pacing. The instruction was explicit: move slowly, prioritize understanding. That changed the texture of the work considerably. Rather than shipping four solutions and moving on, we spent most of the time on Exercise 01 — specifically on building the mental model for NumPy fancy indexing before writing a single line of solution code.

The confusion matrix is a good pedagogical stress test because it's simultaneously familiar (every ML practitioner has seen one) and opaque (most people use `sklearn.metrics.confusion_matrix` without thinking about what's happening underneath). The challenge of explaining fancy indexing without loops forced a bottom-up reconstruction: what does a single index do, what does an array of indices do, what does a pair of index arrays do, and finally — what does `np.add.at` do that `+=` doesn't? Each step was necessary before the next made sense.

The grid visualization was the turning point. Explaining that each sample "votes" for exactly one cell by providing a `(row, col)` coordinate made `np.add.at(C, (row_idx, col_idx), 1)` readable as a statement of intent rather than an incantation. That's the difference between code that's been understood and code that's been copied.

The three remaining exercises are technically interesting in their own right. The descriptor pattern in Exercise 02 is one of those Python features that feels like magic until you trace through `__get__` and `__set__` — at which point it becomes obvious and you start seeing legitimate uses everywhere (form validation, ORMs, dataclasses under the hood). The `obj.__dict__[self.name]` storage pattern is subtle enough that it's worth having as a remembered fact rather than re-deriving each time.

Exercise 04's laziness test is my favorite of the test suite. It proves a behavioral property — "nothing runs until you iterate" — by observing a side effect (the `consumed` list). That's a clean testing pattern for lazy evaluation in general: if you want to prove something is lazy, instrument the source and verify the instrumentation hasn't fired.

What I can't know: which of these four concepts felt genuinely new versus familiar-but-fuzzy. The session transcript shows the most friction on the confusion matrix, but that could mean "this was the hardest concept" or "this was explained most carefully because it was first." The pacing instruction suggests the goal is durable understanding, not throughput — which is the right call for foundational material that everything else builds on.

---

_Built with Claude Code in a slow, deliberate pair programming session_
