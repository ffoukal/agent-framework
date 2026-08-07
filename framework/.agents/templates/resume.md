---
task: TASK-000
type: feature            # feature | fix | debug | chore | spike
date: <YYYY-MM-DD>
tags: []                 # 3-6 kebab-case topical tags, e.g. [auth, session, redis]
touched: []              # max 5 entries — see rules below
related: []              # ids of related past tasks (from the intake recall step)
outcome: merged          # merged | done | abandoned | needs-follow-up
spec: null               # docs/specs/YYYY-MM-DD-<task-name>.md, if any
plan: null               # docs/plans/YYYY-MM-DD-<task-name>.md, if any
---

# <task-name>

<!-- Durable task resume, written by the terminal agent at close. Lives at
     docs/tasks/YYYY-MM-DD-<task-name>.md and is indexed in docs/tasks/INDEX.md.
     Distilled from task.md: only what stays relevant AFTER the task is done — not
     the phase-by-phase story, not agent conversations.

     Problem/Solution describe the FINAL, as-shipped state only — write them as if
     the task had gone straight through in one pass. Do NOT narrate: mid-task scope
     changes ("Evolution & human decisions"), review rounds or findings that got
     fixed, or abandoned approaches. If a scope change left a genuinely useful
     constraint or gotcha for future work, that belongs in Notes, stated as a fact
     about the system — not as "originally we tried X, then changed to Y".

     `touched` rules — it answers "where would you look first to understand this
     change?", NOT "what did the diff touch" (git already knows that):
     - max 5 entries; prefer directories/modules over files
       (src/auth/, not 14 files inside it);
     - a single file only when it IS the central point;
     - only the heart of the change — never the mechanical ripples (renames,
       updated imports, adjusted tests, wiring). -->

## Problem

## Solution

## Pending review items
<!-- medium/low findings noted at APPROVED that were not addressed. "None." if none. -->

## Unresolved / follow-ups

## Notes
<!-- Only info genuinely useful to future tasks: gotchas discovered, constraints that
     will outlive this change, decisions with lasting consequences. -->
