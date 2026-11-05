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
