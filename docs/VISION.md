# Vision & Goals

## Problem

Personal health information is scattered. Medical history sits in paper folders and patient portals, workouts in one app, food logs in another, habits in a third. Most of these apps are cloud-first, need an account, monetize data, and lock it behind proprietary formats. Nothing gives a single, private, long-term record of *your* body that you fully control.

## Vision

A lifelong, private health booklet that you carry on your own device. It should be as easy to log a meal or a workout as it is to look up a vaccination date from ten years ago, and it should be able to connect the two.

## Goals

1. **Unify health data.** Medical records, fitness, nutrition and habits share one model and one timeline.
2. **Local-first and offline.** Every feature works without a network. Startup and logging are instant.
3. **Data ownership.** Open storage format; lossless export and import; no lock-in.
4. **Privacy.** No account, no telemetry. Optional encryption at rest. Optional E2E-encrypted sync between your own devices.
5. **Fast daily logging.** Common entries (meal, workout set, habit check-in, weight) take seconds: templates, recents, quick-add.
6. **Insight across domains.** Trends, correlations and summaries that span categories (sleep vs. training, nutrition vs. weight, habits vs. mood).
7. **Long-term durability.** Built to hold decades of records. Schema migrations are versioned and never lose data.
8. **Shareable on your terms.** Generate a summary (e.g. a PDF for a doctor) that you choose to hand over.

## Non-goals (for now)

- Not a medical device. No diagnosis or treatment advice.
- Not a social network. No feeds, followers or leaderboards.
- No mandatory cloud backend or user accounts.
- Not a provider/EHR system for clinicians.
- No AI coaching in the initial scope (could come later as an opt-in, local-only feature).

## Principles

- **Device is the source of truth**; any server is a dumb relay or backup.
- **Plain, inspectable data**: a user (or a script) can read their data without the app.
- **Append-friendly history**: edits are tracked; nothing is silently overwritten.
- **Progressive depth**: simple by default (log "ran 5k"), detailed when wanted (splits, HR zones).
- **Units and locales respected**: metric/imperial, time zones and date formats handled correctly from day one.
