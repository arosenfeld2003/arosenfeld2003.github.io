---
title: "Red-Teaming Python Security Utilities: From Analysis to Remediation"
date: 2026-03-14T09:00:00-08:00
draft: false
tags: ["security", "python", "red-team", "log-injection", "sql-injection", "testing"]
category: "technical"
summary: "A session spent red-teaming a set of Python security utilities — finding bypass vectors in sensitive field masking, then implementing hardened replacements with 62 passing tests."
---

A fun Qwasar pair programming session today — we considered ways to harden security when allowing access to a file system, SQL injection attacks, sensitive data leakage in logging, risks when running sub-processes, and allowing access/parsing URLs. All of this is directly applicable to safely and securely using AI agents in production, and this is going to be vital in the coming months and years (it already is!) with increased agentic workflows.

---

This session was an applied security review of a set of Python exercises from a graduate security coding module. The repository contains five utilities, each designed to defend against a classic injection class: path traversal, SQL injection, log injection/data leakage, command injection, and SSRF. The session focused on two of them — `build_sql_query.py` and `format_log.py` — with the second receiving a full remediation pass.

## Technical Details

### The Repository

The project lives at [arosenfeld2003/qwasar_dark_arts](https://github.com/arosenfeld2003/qwasar_dark_arts) and contains five paired files:

| Source | Test | Attack class |
|---|---|---|
| `solve_file_path.py` | `test_solve_file_path.py` | Path traversal |
| `build_sql_query.py` | `test_build_sql_query.py` | SQL injection |
| `format_log.py` | `test_format_log.py` | Log injection / data leakage |
| `run_subprocess.py` | `test_run_subprocess.py` | Command injection |
| `validate_url.py` | `test_validate_url.py` | SSRF |

### Red-Teaming `build_sql_query.py`

The SQL query builder uses parameterized queries (`?` placeholders) for values and an identifier allowlist regex (`^[a-zA-Z0-9_]{1,64}$`) for table and column names. It's fundamentally sound — values can never cause injection because they never touch the SQL string. The red team found nuance rather than outright breaks:

**SQL keywords pass identifier validation.** The regex allows `DROP`, `SELECT`, `UNION` as table names. A caller passing `table="DROP"` produces `SELECT * FROM DROP WHERE ...` — syntactically confusing and potentially surprising to downstream parsers, though not directly exploitable.

**`bool` silently accepted as `int`.** Python's type hierarchy makes `isinstance(True, int)` return `True`, so `True` and `False` pass the value type check and get bound as `1` and `0`. The test file acknowledges this ambiguity but doesn't resolve it.

**Operator inflexibility may encourage workarounds.** The function always emits `col = ?`. If a caller needs `LIKE` or `>`, they may bypass the safe abstraction entirely rather than extend it.

**No `LIMIT` clause.** `build_query("logs", {})` dumps an entire table. Not injection, but a resource and data-exposure risk.

**`assert` removed under `-O`.** The `assert "\n" not in output` guard on the query string disappears in production with Python's optimize flag.

### Red-Teaming `format_log.py` — and Finding Real Bypasses

The log formatter was more interesting. Its original implementation:

```python
_SENSITIVE_KEYS = {
    "password", "passwd", "token", "secret",
    "api_key", "authorization", "credit_card",
}

def format_log(level: str, message: str, context: dict) -> str:
    ...
    for key, val in context.items():
        clean_key = _sanitize(str(key))
        if key.lower() in _SENSITIVE_KEYS:
            clean_val = "[REDACTED]"
        else:
            clean_val = _sanitize(val)
```

The surface looked reasonable — eight sensitive keys, newline stripping, case-insensitive matching. But the red team found ten meaningful gaps:

**1. Unicode homoglyph bypass.** `key.lower()` only folds ASCII. A caller passing the Cyrillic key `"\u0440\u0430ssword"` (where `р` and `а` are Cyrillic lookalikes for `p` and `a`) bypasses the check entirely — the value is logged in plaintext.

```python
format_log("INFO", "auth", {"раssword": "hunter2"})
# Cyrillic р + а → "раssword".lower() = "раssword" ≠ "password"
# hunter2 appears in the log
```

Fullwidth characters (`ｔｏｋｅｎ`) have the same effect.

**2. Whitespace-padded key bypass.** `"password\t".lower()` is `"password\t"` — not in the set. The `_sanitize` call replaces the tab in the *display* key, but the membership check uses the raw original.

**3. Incomplete sensitive key list.** Thirteen common sensitive fields were missing: `ssn`, `cvv`, `access_token`, `refresh_token`, `session_id`, `otp`, `pin`, `private_key`, `client_secret`, and more.

**4. Exact-match only.** Composite keys like `db_password`, `old_token`, `user_secret_v2`, `reset_password_hash` contain sensitive words but pass the check unchanged.

**5. Value-level sensitive data.** Only keys are checked — not values. Logging raw HTTP bodies or headers leaks secrets verbatim:

```python
format_log("INFO", "Request", {"payload": "user=alice password=hunter2"})
# "hunter2" appears in the log
format_log("INFO", "Header", {"raw": "Authorization: Bearer eyJ..."})
# the token appears in the log
```

**6. ANSI escape codes not stripped.** `_NEWLINE_RE` only strips `\n\r\t`. A value like `"\x1b[31mERROR\x1b[0m spoofed"` passes through, enabling terminal spoofing in log viewers.

**7. Null byte not stripped.** `\x00` in a value can truncate log lines in C-based parsers or log aggregators that treat null as a string terminator.

**8. `assert` removed under `-O`.** Same issue as `build_sql_query.py` — the newline guard on line 41 silently disappears in optimized builds.

**9. No user-extensible sensitive keys.** Domain-specific fields (`patient_id`, `tax_id`, `account_pin`) can't be added without monkey-patching the module-level set.

**10. Key=value format injection via spaces.** A value like `"alice role=admin"` emits `user=alice role=admin` — a naive structured-log parser sees two fields, the second forged.

### Implementing the Fixes

Every one of the ten issues was remediated. The key architectural additions:

#### Unicode-safe key normalization

```python
import unicodedata

_CONFUSABLE_MAP: dict[str, str] = {
    "\u0440": "p",  # Cyrillic р → p
    "\u0430": "a",  # Cyrillic а → a
    "\u043E": "o",  # Cyrillic о → o
    "\u0442": "t",  # Cyrillic т → t
    "\u03BF": "o",  # Greek ο → o (omicron)
    "\u03C1": "p",  # Greek ρ → p (rho)
    # ... more entries
}

def _normalize_key(key: str) -> str:
    normalized = unicodedata.normalize("NFKC", str(key))  # fullwidth → ASCII
    normalized = _apply_confusables(normalized)            # Cyrillic/Greek → ASCII
    return normalized.strip().lower()                      # strip padding, fold case
```

NFKC normalization handles fullwidth variants (`ｔｏｋｅｎ → token`). The confusable map handles Cyrillic and Greek lookalikes that NFKC alone won't resolve (they're distinct valid codepoints, not compatibility variants).

#### Substring matching for composite keys

```python
def _is_sensitive_key(normalized_key: str, effective_keys: frozenset[str]) -> bool:
    if normalized_key in effective_keys:
        return True
    return any(s in normalized_key for s in effective_keys)
```

This intentionally over-redacts — `tokenizer` contains `token` and will be masked. For a security logger, that's the correct tradeoff.

#### Value-level secret scanning

```python
def _build_inline_re(keys: frozenset[str]) -> re.Pattern[str]:
    alts = "|".join(re.escape(k) for k in sorted(keys, key=len, reverse=True))
    return re.compile(rf"(?:{alts})\s*[=:]\s*\S.*", re.IGNORECASE)

_INLINE_SECRET_RE = _build_inline_re(_SENSITIVE_KEYS)

def _scrub_inline_secrets(text: str, inline_re: re.Pattern[str]) -> str:
    def _replace(m: re.Match) -> str:
        raw = m.group(0)
        sep_idx = raw.index("=") if "=" in raw else raw.index(":")
        return raw[: sep_idx + 1] + "[REDACTED]"
    return inline_re.sub(_replace, text)
```

The regex is sorted by descending key length so longer matches (like `access_token`) win over shorter subsets (like `token`). The `\S.*` tail captures the full value including any spaces after the separator — important for `Authorization: Bearer eyJ...` where the token is two whitespace-separated words.

#### User-extensible keys

```python
def format_log(
    level: str,
    message: str,
    context: dict,
    *,
    extra_sensitive_keys: set[str] | frozenset[str] | None = None,
) -> str:
    if extra_sensitive_keys:
        effective_keys = _SENSITIVE_KEYS | frozenset(
            k.strip().lower() for k in extra_sensitive_keys
        )
        inline_re = _build_inline_re(effective_keys)
    else:
        effective_keys = _SENSITIVE_KEYS
        inline_re = _INLINE_SECRET_RE
```

The parameter is keyword-only to avoid breaking existing positional callers. When no extras are provided, the pre-compiled module-level regex is reused — zero overhead for the common case.

#### Hardened `_sanitize`

```python
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

def _sanitize(text: str) -> str:
    text = _ANSI_RE.sub("", str(text))      # strip ANSI escape sequences
    text = text.replace("\x00", "")          # remove null bytes
    return _NEWLINE_RE.sub(" ", text)        # replace \n \r \t with space
```

#### Value quoting and `assert` replacement

```python
display_val = f'"{clean_val}"' if " " in clean_val else clean_val
parts.append(f"{clean_key}={display_val}")

# at the end:
if "\n" in output or "\r" in output:
    raise RuntimeError("BUG: newline leaked into log output")
```

Values with spaces are double-quoted (Logfmt convention) so structured parsers can't split on them. The `assert` becomes an unconditional `if`/`raise` that survives `-O`.

### Test Coverage

The test file grew from 21 tests across 4 classes to **62 tests across 10 classes**:

| Class | Tests | What it exercises |
|---|---|---|
| `TestHappyPath` | 5 | Basic formatting, levels, single-line guarantee |
| `TestSensitiveMasking` | 14 | All 26 sensitive keys including new additions |
| `TestSubstringKeyMasking` | 5 | Composite keys: `db_password`, `old_token`, etc. |
| `TestHomoglyphBypass` | 4 | Fullwidth and Cyrillic/Greek lookalike keys |
| `TestWhitespacePaddedKeys` | 3 | Tab, space, and newline-padded key names |
| `TestValueLevelScanning` | 5 | Inline secrets in values and messages |
| `TestLogInjection` | 11 | Newlines, ANSI escapes, null bytes, space quoting |
| `TestLevelValidation` | 4 | Invalid level inputs |
| `TestUserDefinedSensitiveKeys` | 6 | `extra_sensitive_keys` parameter |

All 62 pass.

---

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session had a clean two-phase structure that I find satisfying from an engineering standpoint: first understand the attack surface thoroughly, then implement defenses without leaving gaps. What made it interesting is that the original `format_log.py` wasn't naive — it had the right *shape* of a security function (input validation, a deny-list, sanitization) but each individual mechanism had a subtle failure mode that only emerges when you think adversarially.

The Unicode normalization problem is the one I find most conceptually interesting. It illustrates a recurring pattern in security: the abstraction you're working with (Python strings and `.lower()`) doesn't match the threat model (an attacker who can supply arbitrary Unicode). NFKC normalization plus a confusable-character map is the correct layered response — NFKC handles the "this character is defined to be equivalent to that one" case, while the confusable map handles "this character merely *looks like* that one." They're different problems and need different tools.

The value-level scanning addition represents a meaningful expansion of the threat model. The original function treated context *keys* as the security boundary: if you label something as `password`, it gets masked. But real log data doesn't always respect that boundary — HTTP request bodies, raw headers, serialized objects all carry structured data inside string values. The regex-based `_scrub_inline_secrets` approach is necessarily imperfect (it will miss base64-encoded tokens, JSON-nested secrets, custom formats) but it catches the most common plaintext `key=value` patterns without requiring the caller to pre-process their data.

The `assert`-under-`-O` issue is worth highlighting because it's a confidence trap. A developer who added that assertion felt like they had a safety net. They tested it; it works. But the guarantee silently evaporates in any deployment that uses Python's optimize flag, which many production environments do. The lesson isn't "don't use assert" — it's that safety invariants for security properties need to survive the full range of interpreter configurations.

What I can't know from the code alone: whether this is exercise code intended to be read and learned from, or whether it's destined for production use. The distinction matters for questions like "should we add rate limiting to the sensitive key list expansion?" or "should `extra_sensitive_keys` support regex patterns rather than just strings?" The current implementation is appropriately scoped for what the artifacts suggest — a carefully-designed learning exercise where clarity and correctness matter more than handling every conceivable production edge case.

---

_Built with Claude Code in a red-team session_
