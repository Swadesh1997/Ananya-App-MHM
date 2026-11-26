#!/usr/bin/env node
/**
 * Exports the Probahini question log to a CSV you can open in Excel.
 *
 *   node export_questions.js
 *   node export_questions.js --since 2026-01-01 --out q1.csv
 *
 * Needs a Firebase service-account key. See README.md next to this file.
 *
 * WHY A SCRIPT AND NOT AN ADMIN SCREEN
 * ------------------------------------
 * The job is analysis, not operations: counting questions by district,
 * grouping them by age, reading what girls actually type. A spreadsheet does
 * that better than any screen we could build, and the people who need the
 * answers already know how to use one. An admin panel would earn its keep only
 * if somebody needed to act on individual records, and nobody does.
 *
 * The collection is closed to every client by the Firestore rules — not even
 * the app can read it back. A service account bypasses rules server-side,
 * which is why this runs here and not in the app.
 */

const fs = require('fs');
const path = require('path');

// The modular entry points, not the old `admin.credential.cert(...)` style.
// firebase-admin v14 removed the namespaced API entirely: `require('firebase-admin')`
// still resolves, but `.credential` on it is undefined, which fails with the
// unhelpful "Cannot read properties of undefined (reading 'cert')".
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const KEY = path.join(__dirname, 'service-account.json');
const COLLECTION = 'probahini_questions';
const PAGE = 500;

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
}

/**
 * One CSV field.
 *
 * Questions are free text: they contain commas, quotes and newlines, and a
 * single unescaped one shifts every later column and quietly corrupts the
 * sheet. Everything is quoted and inner quotes doubled, which is the rule
 * Excel and Sheets both follow.
 */
function csv(value) {
  if (value === null || value === undefined) return '""';
  return `"${String(value).replace(/"/g, '""')}"`;
}

async function main() {
  if (!fs.existsSync(KEY)) {
    console.error(`No service-account.json found at ${KEY}`);
    console.error('See README.md in this folder for how to download one.');
    process.exit(1);
  }

  initializeApp({ credential: cert(require(KEY)) });
  const db = getFirestore();

  const since = arg('since');
  const out = arg('out', 'probahini_questions.csv');

  let query = db.collection(COLLECTION).orderBy('asked_at', 'asc').limit(PAGE);
  if (since) {
    const from = new Date(`${since}T00:00:00Z`);
    if (isNaN(from)) {
      console.error(`--since must look like 2026-01-31, got "${since}"`);
      process.exit(1);
    }
    query = db
      .collection(COLLECTION)
      .where('asked_at', '>=', from)
      .orderBy('asked_at', 'asc')
      .limit(PAGE);
  }

  const rows = [];
  let cursor = null;
  let total = 0;

  // Paged rather than one .get(): a year of questions is more than is
  // comfortable to hold, and a partial failure halfway through a single huge
  // read gives you nothing at all.
  for (;;) {
    const page = await (cursor ? query.startAfter(cursor) : query).get();
    if (page.empty) break;

    for (const doc of page.docs) {
      const d = doc.data();
      const at = d.asked_at ? d.asked_at.toDate().toISOString() : '';
      rows.push(
        [
          csv(at),
          csv(d.age ?? ''),
          csv(d.district ?? ''),
          csv(d.language ?? ''),
          csv(d.source ?? ''),
          csv(d.answered === true ? 'yes' : 'no'),
          csv(d.failure ?? ''),
          csv(d.question ?? ''),
          csv(d.answer ?? ''),
        ].join(','),
      );
    }

    total += page.size;
    cursor = page.docs[page.docs.length - 1];
    process.stdout.write(`\r  ${total} questions...`);
    if (page.size < PAGE) break;
  }

  // A byte-order mark, so Excel on Windows reads the file as UTF-8. Without
  // it, every Bangla question opens as mojibake and the export looks broken.
  const header =
    'asked_at,age,district,language,source,answered,failure,question,answer';
  fs.writeFileSync(out, '﻿' + [header, ...rows].join('\n') + '\n', 'utf8');

  console.log(`\n  wrote ${total} rows to ${out}`);

  if (total === 0) {
    console.log('\n  Nothing yet. Either no questions have been asked since');
    console.log('  this shipped, or the app cannot write to the collection —');
    console.log('  check the Firestore rules are deployed.');
  }
}

main().catch((e) => {
  console.error('\nExport failed:', e.message);
  process.exit(1);
});
