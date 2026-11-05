---
name: bible-plan-backup
description: Refresh and verify the secondary Firebase Hosting snapshot automatically after completing published changes to My Bible Plan, mybibleplan.web.app, or the boshkamal1/My-bible-plan repository. Applies to this project only.
---

# My Bible Plan publication backup

The user explicitly requests an automatic backup refresh whenever completed work is published on this project. Treat this as standing authorization to refresh the secondary Hosting site after a successful primary release; do not ask for the same conversational confirmation again. Runtime approvals still apply.

- Firebase project: `bible-plan-boshkamal-20261101`
- Primary Hosting site: `mybibleplan` — https://mybibleplan.web.app/
- Backup Hosting site: `bible-plan-boshkamal-20261101` — https://bible-plan-boshkamal-20261101.web.app/
- Repository: https://github.com/boshkamal1/My-bible-plan

After the task's required checks pass, publish according to the user's existing task instructions and verify the primary's intended release. Then copy that exact live release:

```powershell
firebase hosting:clone mybibleplan:live bible-plan-boshkamal-20261101:live --project bible-plan-boshkamal-20261101 --non-interactive
```

Confirm the clone completed. Check both public URLs, the release marker when present, and one changed asset or behavior where appropriate. Record the release and refresh in `HOSTING-BACKUP.md`; include it in Git updates already authorized for the task. Report the backup outcome with the completed work.

If the primary release or its verification fails, preserve the existing backup and fix or report the failure. For a transient clone/verification failure, retry once; otherwise report the backup as incomplete with its concrete cause, never as successful.

Both sites share Authentication and Firestore. This operation copies the complete published Hosting release, not a separate database, user account, or local browser-data backup. Do not change billing, access controls or databases to refresh it.

For read-only questions or tasks with no new published release, no refresh is needed. A local-only or no-publish request takes precedence: do not deploy solely to invoke this workflow. Never apply the fixed site IDs to unrelated projects.
