# Checkpoint: Bible translations and Arabic vowel marks

**Update 2026-11-04:** The translation changes were built and deployed to Firebase Hosting as version `20261103-14`. Arabic and WEB assets were verified on the live site. Translation and existing-plan migration tests passed. The limitations below about prayer of Manasseh and differing Esther versification remain relevant; deployment and verification items describe the previous state.

Resume when the user says “كمل”.

## User request

1. Use the old Jesuit Arabic translation for the Deuterocanonical books.
2. Add World English Bible with Deuterocanon as an English translation choice.
3. Add Arabic diacritics to all Arabic books in Van Dyck and old Jesuit texts.
4. Use the source links the user supplied from St-Takla for the Deuterocanonical text.

## Workspace

`C:\Users\boshk\Documents\Codex\my-bible-project\my-bible\flutter_app`

There is no `.git` repository in the checkout. Do not assume Git history is available.

## Work completed so far

- Downloaded St-Takla chapter pages and extracted vocalized Arabic text into `assets/bible/svd/` and `assets/bible/ar_extra/` using `tools/import_st_takla.js`.
- Added the Arabic Psalm 151 text from St-Takla to `assets/bible/ar_extra/151.json`.
- Downloaded the official public-domain WEB USFM zip into `tools/eng-web_usfm.zip`, extracted it to `tools/web_usfm/`, and generated 76 chapter JSON files in `assets/bible/web/` with `tools/import_web.js`.
- Added WEB as a translation choice in settings, reader, search, and repository loading.
- Set the old Arabic Esther addition to 7 chapters (10–16); WEB’s integrated Greek Esther is presented as 10 chapters.
- Updated the planner chapter-minute generator and ran it to refresh `lib/core/chapter_lengths.dart`.

## Important unfinished work

- Nothing has been deployed. The Flutter analyzer/build did not complete. The previous escalation attempt timed out in automatic approval review; do not treat that as a safety rejection. Retry the verification once, or run the lowest-privilege available check.
- Formatting/analyzer output is still unknown. Inspect and fix compile errors before building.
- Verify the new translation dropdown API against the repository’s Flutter version; `DropdownButtonFormField` currently uses `initialValue`, which may need `value` for Flutter 3.27 compatibility.
- Inspect and correct display/navigation for the added Esther chapters and the separate Daniel additions.
- Check WEB import versification and empty slots. The import report flags unnumbered verse slots in Sirach, Greek Esther, Luke, and Acts. Decide whether the empty slots are source numbering gaps; preserve verse numbering and do not silently shift verses.
- St-Takla import reported one extra verse for Nehemiah, 1 Timothy, and 3 John compared with bundled counts. Check those alignments.
- Prayer of Manasseh is not present in the St-Takla vocalized/old Jesuit listing; the current app may fall back to English for it. Do not label another Arabic text as old Jesuit without verifying the source.
- `tools/import_st_takla.js` has a special import for Psalm 151; rerunning the bulk importer may rewrite the JSON files and report. Confirm all expected assets remain present.
- Update all web cache/version query strings and the service-worker cache version before deploying, following the project’s prior cache-busting pattern (last known deployed version was `20261103-13`).
- Run Flutter analysis/build, deploy Firebase Hosting, and verify the live URL only after resolving the above.

## Useful source references

- St-Takla states its Arabic Bible uses Van Dyck apart from the Deuterocanonical books, which use the old Jesuit translation, and offers fully vocalized text: https://st-takla.org/Holy-Bible_.html
- User’s St-Takla Deuterocanonical links are in the chat immediately before this checkpoint.
- Official WEB USFM source: https://ebible.org/Scriptures/eng-web_usfm.zip
- WEB public-domain terms: https://ebible.org/find/details.php?id=eng-web

## Last known deployment

`https://mybibleplan.web.app/` (previous version before these translation changes).
