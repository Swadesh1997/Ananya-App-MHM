# Exporting Probahini questions

Every question asked of Probahini is recorded in Firestore, anonymously: the
question text, her age, her district, the language, and when. No name, no phone
number, no user id — nothing that identifies who asked.

This folder holds a script that pulls those records into a CSV you can open in
Excel or Google Sheets.

## One-time setup

You need a **service account key** — a file that lets the script read Firestore
directly. The app itself cannot read this collection; the security rules block
every client, so analysts go through a service account instead.

1. Open the [Firebase console](https://console.firebase.google.com) and pick
   the Ananya project
2. Click the gear icon → **Project settings** → **Service accounts**
3. Click **Generate new private key**, then **Generate key**
4. A `.json` file downloads. Rename it to **`service-account.json`** and put it
   in this folder

Then install the one dependency:

```bash
cd tools
npm install firebase-admin
```

> **That JSON file is a master key to your database.** It bypasses every
> security rule. It is git-ignored so it cannot be committed by accident —
> don't email it, don't put it in Drive, and delete it if the laptop changes
> hands. If it ever leaks, revoke it from the same Service accounts page.

## Running it

```bash
cd tools
node export_questions.js
```

Writes `probahini_questions.csv` beside the script.

Only want a date range, or a different filename:

```bash
node export_questions.js --since 2026-01-01 --out q1-2026.csv
```

## What you get

| Column | Meaning |
|---|---|
| `asked_at` | when, in UTC |
| `age` | her age in whole years, or blank if unknown |
| `district` | the district she chose at sign-up |
| `language` | `bn` or `en` — which language the app was in |
| `source` | `typed` = she wrote it herself; `article` = she tapped "ask this" on a knowledge-hub article |
| `answered` | `yes` / `no` — did Probahini reply with anything |
| `failure` | blank when answered. `empty` = the service replied with no text; `timeout` = it never replied; `error` = anything else |
| `question` | what she asked |
| `answer` | what Probahini replied, blank when it failed |

## The two questions this file answers

**"What do girls ask about?"** — filter `source = typed`, then read the
`question` column or pivot it by district and age.

**"Where does Probahini fall short?"** — filter `answered = no`. Those are
questions the chatbot could not handle at all, and they are the shortlist for
what to add to its source document.

Worth reading too: rows where `answered = yes` but the `answer` is short or
generic. Nothing flags those automatically, but skimming a few dozen tells you
more about quality than any metric.

Note the `answer` column is Probahini's own text only. When it fails, the app
shows her an apology of its own — that message is never stored, so a failed
exchange cannot be mistaken for an answered one.

**Filter `source` before counting.** The `article` rows are pre-written
questions repeated by many girls, so leaving them in makes the same few strings
dominate the totals and hides what girls actually ask unprompted. Both are
useful — just not added together.

## Reading it responsibly

The records carry no identity, but the **question text is free text** and a girl
could have typed her own name or village into it. Treat the file as sensitive:
keep it off shared drives, and strip or aggregate before putting anything in a
report or presentation.

A question like *"I am 13 and live in [village] and I have had bleeding for 10
days"* identifies someone in a small community even though the record itself
does not.
