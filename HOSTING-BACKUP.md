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
