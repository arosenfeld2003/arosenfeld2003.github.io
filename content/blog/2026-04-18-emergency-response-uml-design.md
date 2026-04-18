---
title: "Designing an Emergency Response System: UML, SQL, and a Working CLI"
date: 2026-04-18T09:00:00-08:00
draft: false
tags: ["uml", "sql", "python", "systems-design", "object-oriented"]
category: "technical"
summary: "Starting from a lab spec about city emergency coordination, we designed a UML class diagram in draw.io, mapped it to a SQLite schema, and built a working menu-driven CLI that demonstrates incident reporting, unit dispatch, and the availability guard."
---

This was a fun engineering lab group project focused on OOP. The working CLI was an added bonus — the real goal was talking through how to design and think about these types of systems conceptually. The flow with Claude was having an initial diagram generated, then editing it live in draw.io and reprompting based on our changes and discussion. Truly collaborative with humans and AI assistance.

---

## Technical Details

### The Lab Spec

The session started from a structured engineering prompt: design a system for a city to coordinate emergency responses. The requirements were deliberately open-ended — handle fires, medical emergencies, and crimes; dispatch appropriate units; handle multi-unit incidents; and be extensible enough that new incident or unit types could be added without redesigning the core.

That last constraint is the interesting one. It pushes you toward inheritance hierarchies and polymorphism rather than a flat table of `if incident_type == "FIRE"` branches.

### UML Design in draw.io

The diagram (`emergency_response_uml.drawio`) ended up with four conceptual layers arranged top-to-bottom to mirror data flow:

**Row 1 — Controller:** `DispatchCenter` sits at the top as the entry point. An `Incident Reporter` actor feeds into it from above; an `Auditor` actor reads from completed responses below.

**Row 2 — Abstract base classes:** `Incident` (blue) and `ResponseUnit` (green) sit side by side. Both are abstract — they define the contract but can't be instantiated directly. `DispatchCenter` reaches down to both via `categorize` and `respond` dependency edges.

**Row 3 — Concrete subclasses + coordination:** Three incident subclasses fan out left (`FireIncident`, `MedicalEmergency`, `CrimeIncident`), three unit subclasses fan out right (`PoliceUnit`, `AmbulanceUnit`, `FireUnit`), and `IncidentResponse` sits in the center as the association class that links them.

**Row 4 — Enumerations:** `IncidentStatus`, `SeverityLevel`, and `AvailabilityStatus` anchor the bottom.

The key design decisions:

- **`getRequiredUnits()` on each `Incident` subclass** — dispatch rules live close to the incident type, not scattered through the controller. A `FireIncident` knows it needs `[FIRE, AMBULANCE]`; the `DispatchCenter` just asks and acts.
- **`IncidentResponse` as an association class** — rather than a direct many-to-many between `Incident` and `ResponseUnit`, the association class holds assignment metadata: when the unit was assigned, its role, and its current response status. This enables reassignment and withdrawal without losing history, and it's what the `Auditor` reads.
- **`isAvailable()` as an explicit guard** — units in `DISPATCHED`, `OFF_DUTY`, or `MAINTENANCE` states cannot be assigned. The guard is on the unit, not the controller.

One XML hiccup along the way: draw.io's `.drawio` format is XML, and XML forbids `--` inside comments. The initial template had comments like `<!-- Incident -- IncidentResponse (1 to many) -->` which broke parsing. Fixed by replacing `--` with `to`.

### SQL Schema

The schema in `schema.sql` maps cleanly from the UML:

```sql
CREATE TABLE IF NOT EXISTS incidents (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT NOT NULL CHECK(type IN ('FIRE', 'MEDICAL', 'CRIME')),
    location    TEXT NOT NULL,
    severity    TEXT NOT NULL CHECK(severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status      TEXT NOT NULL DEFAULT 'REPORTED'
                    CHECK(status IN ('REPORTED', 'IN_PROGRESS', 'RESOLVED', 'CANCELLED')),
    reported_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS response_units (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL,
    type         TEXT NOT NULL CHECK(type IN ('FIRE', 'POLICE', 'AMBULANCE')),
    location     TEXT NOT NULL,
    availability TEXT NOT NULL DEFAULT 'AVAILABLE'
                     CHECK(availability IN ('AVAILABLE', 'DISPATCHED', 'OFF_DUTY', 'MAINTENANCE'))
);

-- Association class: links one incident to one response unit
CREATE TABLE IF NOT EXISTS incident_responses (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL REFERENCES incidents(id),
    unit_id     INTEGER NOT NULL REFERENCES response_units(id),
    role        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'ACTIVE'
                    CHECK(status IN ('ACTIVE', 'COMPLETED', 'CANCELLED')),
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

The `CHECK` constraints on `type`, `severity`, `status`, and `availability` encode the enumeration constraints from the UML directly into the database layer — the same invariants that `IncidentStatus`, `SeverityLevel`, and `AvailabilityStatus` represent in the class diagram.

The schema also seeds the fleet:

```sql
INSERT OR IGNORE INTO response_units (id, name, type, location, availability) VALUES
    (1, 'Engine 1',    'FIRE',      'Station A',      'AVAILABLE'),
    (2, 'Engine 2',    'FIRE',      'Station B',      'AVAILABLE'),
    (3, 'Patrol 1',    'POLICE',    'Precinct 1',     'AVAILABLE'),
    (4, 'Patrol 2',    'POLICE',    'Precinct 2',     'AVAILABLE'),
    (5, 'Ambulance 1', 'AMBULANCE', 'Hospital North', 'AVAILABLE'),
    (6, 'Ambulance 2', 'AMBULANCE', 'Hospital South', 'AVAILABLE');
```

### Python CLI

`cli.py` is a menu-driven Python 3 CLI backed by SQLite. The three core functions map directly to UML operations:

**`report_incident()`** — mirrors `DispatchCenter.receiveReport()`:
```python
def report_incident(con, inc_type, location, severity):
    cur = con.execute(
        "INSERT INTO incidents (type, location, severity) VALUES (?, ?, ?)",
        (inc_type, location, severity),
    )
    con.commit()
    return cur.lastrowid
```

**`dispatch_units()`** — mirrors `dispatchUnits()` + `isAvailable()` guard + `IncidentResponse` creation:
```python
for unit_type in REQUIRED_UNITS[row["type"]]:
    unit = con.execute(
        "SELECT id, name FROM response_units WHERE type = ? AND availability = 'AVAILABLE' LIMIT 1",
        (unit_type,),
    ).fetchone()

    if not unit:
        print(f"  [!] No AVAILABLE {unit_type} unit found — skipping.")
        continue

    con.execute(
        "INSERT INTO incident_responses (incident_id, unit_id, role) VALUES (?, ?, ?)",
        (incident_id, unit["id"], unit_type),
    )
    con.execute(
        "UPDATE response_units SET availability = 'DISPATCHED' WHERE id = ?",
        (unit["id"],),
    )
```

**`resolve_incident()`** — mirrors `IncidentResponse.complete()` + `ResponseUnit.withdraw()`:
```python
def resolve_incident(con, incident_id):
    con.execute(
        "UPDATE incident_responses SET status = 'COMPLETED' WHERE incident_id = ? AND status = 'ACTIVE'",
        (incident_id,),
    )
    con.execute(
        """UPDATE response_units SET availability = 'AVAILABLE'
           WHERE id IN (SELECT unit_id FROM incident_responses WHERE incident_id = ?)""",
        (incident_id,),
    )
    con.execute("UPDATE incidents SET status = 'RESOLVED' WHERE id = ?", (incident_id,))
    con.commit()
```

A quick smoke test confirmed the flow: report a FIRE at Downtown with HIGH severity, dispatch immediately, and the system assigns Engine 1 + Ambulance 1 (the two unit types a `FireIncident` requires), setting both to `DISPATCHED` and the incident to `IN_PROGRESS`.

### Repository

All artifacts are on GitHub: [arosenfeld2003/emergency-response-system](https://github.com/arosenfeld2003/emergency-response-system)

---

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

What struck me most about this session was how well the lab spec forced a layered design without prescribing one. The requirement that "the system must support new types of incidents or units in the future" is essentially a statement of the open/closed principle — and it naturally pushes toward abstract base classes and polymorphic dispatch rather than conditional logic. The UML diagram ended up expressing that cleanly: `getRequiredUnits()` is defined on `Incident` but implemented by each subclass, so adding a `HazmatSpill` type is a matter of subclassing, not editing a dispatch table.

The `IncidentResponse` association class is the most architecturally interesting part. In a naive implementation you might just add a foreign key from `response_units` to `incidents`, which breaks the moment you need many-to-many (one incident, multiple units). The association class solves that but also adds something more valuable: per-assignment state. The `Auditor` actor that appeared during the session — added directly in draw.io, not in the original spec — implies a requirement for auditability. `IncidentResponse` with `assigned_at` and `status` fields is exactly what you'd need to answer "which unit responded to this incident and when did it clear?"

The SQL `CHECK` constraints are doing real work here. Rather than relying on application-level validation, the schema enforces the same enumerations the UML diagram models. That's a healthy instinct — the database is the last line of defense, and encoding invariants there means a future CLI, API, or migration script can't accidentally create an incident with `status = 'PURPLE'`.

One thing I can't fully observe from the artifacts: the diagram went through several iterations — the user moved `IncidentResponse` down a row, added the `Incident Reporter` and `Auditor` actors, and relabeled edges from `manages`/`coordinates` to `categorize`/`respond`. These are meaningful changes. The actor additions frame the system from a use-case perspective rather than just a structural one. The edge relabeling shifts the diagram from describing what the `DispatchCenter` owns to what it does — a subtle but real improvement in expressiveness.

The one open thread is the `Capability` type referenced in `ResponseUnit.capabilities: List<Capability>`. It appears in the UML but has no corresponding table or enum in the schema or CLI. Speculating: the matching logic between `getRequiredUnits()` and actual unit capabilities is currently implicit — a `FireIncident` requests `FIRE` units and the query finds units of `type = 'FIRE'`. That works for a demo but conflates unit type with capability. A real system would want a separate `capabilities` table so a single unit could carry multiple capabilities (e.g., a combined fire/hazmat truck).

---

_Built with Claude Code during an engineering lab session_
