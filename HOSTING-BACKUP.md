# Hosting backup

Primary: https://mybibleplan.web.app/
Backup: https://bible-plan-boshkamal-20261101.web.app/

The backup is an explicit Hosting snapshot, copied with Firebase hosting:clone.
Ordinary `firebase deploy --only hosting` updates only the primary, preserving
the backup until it is deliberately refreshed. Both sites use the same Firebase
project, Authentication and Firestore; this is not a separate database backup
or protection against a project-wide Firebase outage. Local browser progress
and login sessions belong to each site's origin; signing in uses the same account.

Backup domain was verified present in live Authentication authorizedDomains.

Refresh after verifying a stable primary release:

```powershell
firebase hosting:clone mybibleplan:live bible-plan-boshkamal-20261101:live --project bible-plan-boshkamal-20261101 --non-interactive
```

Restore the snapshot to primary when needed (this replaces its published files):

```powershell
firebase hosting:clone bible-plan-boshkamal-20261101:live mybibleplan:live --project bible-plan-boshkamal-20261101 --non-interactive
```

## Latest refresh — 2026-11-05

Copied `mybibleplan:live` to `bible-plan-boshkamal-20261101:live` successfully with Firebase Hosting clone. Snapshot release: `20261105-26`, including book selection, per-group toggles, custom drag-and-drop order, reserve-aware plan duration, RTL references and repaired WEB assets. Source commits: `866af75` and `bd43801` on GitHub main.

The clone copies the full published Hosting release. Authentication and Firestore remain shared; it is not an independent user-data backup.

## Release 27 refresh — 2026-11-05

After all 38 Flutter tests and 8 Node tests passed and the primary release was verified live, the entire primary Hosting release `20261105-27` was cloned to the backup. Both sites now include personal JSON backup/restore, bilingual comparison and small chapter assets. This refresh contains source commit `c8aca0e`. Backend Authentication and Firestore remain shared.

## Release 28 refresh — 2026-11-05

After the paired-row comparison scroll tests and release web build passed, release `20261105-28` (source `bb05d5a`) was deployed to primary and cloned successfully to the backup. Both sites now use one scrolling page for Arabic/English comparison.

## Release 29 refresh — 2026-11-05

Source commit `05f177e` was pushed to GitHub main and release `20261105-29` deployed successfully. Following the installed `bible-plan-backup` skill and the user's standing authorization, the verified primary live release was cloned automatically to the secondary live site. Both pages returned HTTP 200, contained release 29 and had identical HTML. The backup's GNA Genesis 1 chapter asset returned HTTP 200 with 31 verses. Authentication and Firestore remain shared; this is a Hosting snapshot.

## Release 30 refresh — 2026-11-05

Source commit `8eaddf0` was pushed to GitHub main. After 45 Flutter tests, 14 Node checks, planner assertions, visual mobile review and the production build passed, release `20261105-30` was deployed to primary. Live HTML/bootstrap/worker release markers were verified; the published main.dart.js SHA-256 matched the tested local build. The primary live release was then cloned automatically to the secondary site under the backup skill. Both sites returned HTTP 200 with identical release HTML; the secondary main.dart.js SHA-256 also matched the tested build. Existing account and synchronization findings are recorded in REVIEW-20261105.md; the backup remains Hosting-only with shared backend data.

## الإصدار 31 — 2026-11-05

التعديلات في commit `19c168d` اترفعت على GitHub، والبناء و18 اختبار Flutter و6 فحوص Node نجحوا. الإصدار `20261105-31` اتنشر على الرئيسي، واتراجع رقم الإصدار وبصمة ملف التطبيق مقابل البناء المحلي. بعدها اتنسخ تلقائيًا للثانوي حسب الـSkill. الموقعين رجعوا HTTP 200 بنفس HTML، وبصمة JavaScript على الثانوي مطابقة للبناء المتختبر. النسخة دي شالت اختيار اليسوعية الجزئي، مع الحفاظ على المكملات وتحويل الإعدادات القديمة. الحسابات وFirestore لسه مشتركين.


## 2026-11-06 — release 20261105-32

Published security rules, guarded private-group migration and the optimized Wasm web release. Verified primary reader/comparison, strict CSP, Wasm MIME type and real App Check issuance in monitoring mode. Cloned `mybibleplan:live` to `bible-plan-boshkamal-20261101:live` after primary verification.

Both sites: HTTP 200; release marker `20261105-32`; identical HTML, changed JavaScript and CSP. Verification: `2026-11-06T10:20:36Z`; evidence in `security-audit/hosting-backup-verification.json`.

An independent encrypted Firestore/Auth snapshot was also taken and Firestore restore-tested before migration. It is stored outside the repository and OneDrive; see `DATA-RECOVERY.md`. Hosting still shares Auth/Firestore across the two sites. No billing attachment, paid upgrade or Functions deployment occurred; Firestore App Check remains UNENFORCED.


## 2026-11-06 — release 20261106-33

Published the typed Firestore metadata fix after 68 native Flutter tests and a real Wasm-app sync integration on isolated Auth/Firestore emulators (initial sync, remote pull and subsequent local edit; final revision 3; zero production data API requests). Live reader/comparison and plain/encrypted backup round trips passed without CSP violations or runtime errors.

Refreshed the secondary site again using `hosting:clone`. Both sites serve release 33 with identical HTML, JavaScript, WebAssembly and CSP. The exact verification timestamp and hashes are in `security-audit/hosting-backup-verification.json`. This supersedes the release 32 snapshot; the independent encrypted pre-migration data backup remains outside the repository and OneDrive.

## 2026-11-06 — release 20261106-34

Fixed progress-image downloads: prepare the complete PNG after the screen entrance, preserve the user's tap activation and download binary PNG through a Blob URL. Image preparation failures offer a retry. The captured image is refreshed when its progress, language, date or layout changes.

Verified real pointer downloads at 575x532 in Wasm and JavaScript fallback, including a live primary download: valid complete 960x1281 PNG, no runtime errors or CSP violations. All 18 existing UI regression tests and 8 JavaScript checks passed. Analyzer has only the existing 64 informational notices.

Cloned the verified primary release to the secondary Hosting site. Both return HTTP 200 and identical release-34 HTML/CSP, with downloads.js, JavaScript and Wasm hashes matching the tested local build. Evidence: security-audit/progress-save-*.json and hosting-backup-verification.json. No database, account, billing or security-rule changes.
