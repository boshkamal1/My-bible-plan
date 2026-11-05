# Security and performance checkpoint — 2026-11-04

Latest feature update prepared as 20261104-24: daily encouragement verse prefers
curated references within today's exact scheduled chapters, otherwise rotates
through curated encouragements. Local preference dailyEncouragementVerse keeps
the reference fixed throughout the day and excludes yesterday's stored choice.
Read Now selects first unread chapter across plan days in order, retaining that
day's unread queue, including overdue readings; reminder remains visible until
plan readings are complete. 10 home requirements tests passed.
Backup site is a separate stable Hosting snapshot (see HOSTING-BACKUP.md), last
cloned at 20261104-23. Ordinary Hosting deploy only changes primary.

User requires free services only. Do NOT upgrade billing or enable paid Firebase services. Hosting and Firestore rules deployed successfully as 20261104-19. Functions deploy was attempted but failed because Blaze billing is required. No billing upgrade occurred. WEB_PUSH_READY defaults false in production build; scheduled web push remains disabled. Existing mobile local notifications are independent.

Completed: daily verse share action, category renamed to الرسائل الجامعة والرؤيا, release-specific cache-first static assets with network-first bootstrap/navigation, auth helper cache exclusion, notification URL origin restriction, Hosting security headers, concurrent Bible load deduplication, lazy normalized search cache, yielding during search, stale search result protection and controller disposal, stable daily-verse future.

Firestore rules compiled, passed 8 emulator tests and deployed. Explicit member status/role, parent existence, owner immutability, validation and push provider allowlist. Read-only live inspection found 1 group/1 legacy member; migrated only its owner record to explicit approved/admin with updateTime precondition. No nonowner legacy members found. Existing orphan member subcollections were NOT exhaustively enumerated; trusted parent recreation must remove descendants first. Client group deletion denied.

Verification: 34 Functions tests passed including Node 22; 4 service-worker tests passed; 7 home/reader widget tests passed after fixing asynchronous test loading. Repository/translation tests passed before final widget-only rerun. Arabic warm full-scan timings about 37–45ms versus previous 217–252ms on this host (not device/browser startup benchmarks). Release web build passed. Analyzer reported informational lint findings only; no compile errors. Font tree-shaking emitted preexisting Cupertino font warning; no explicit CupertinoIcons references in app source.

Functions fixes are local only: SSRF allowlist, cryptographic key checks, transactional fresh data, safe cleanup and log redaction. Compatible dependency updates applied. 7 moderate dependency advisories remain, 0 high/critical at audit time; see functions/SECURITY-AUDIT.md. Major Firebase Admin migration not performed.

Live project-level IAM had no public grants. Cloud Functions/Run/Scheduler APIs were disabled, so service-level IAM could not be verified. Firebase deploy confirmed Blaze prerequisite. Future free background notifications need a separately provisioned free scheduler/push sender; do not promise closed-site reminders using a browser timer. Do not request billing upgrade again.

Workspace: C:/Users/boshk/Documents/Codex/my-bible-project/my-bible (no .git).
