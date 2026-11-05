# My Bible Plan — رحلة الكتاب المقدس

Flutter reading planner and Arabic / English Bible reader. The maintained source, Firebase Hosting configuration and release notes are in this repository.

## Build and run

Validated with Flutter 3.41.6 and Node.js. Platform projects are already present; do not regenerate the customized web entry files.

```powershell
cd flutter_app
flutter pub get
node tools/split_chapters.cjs
flutter run -d chrome
```

Release build (generates small chapter files first):

```powershell
pwsh -File flutter_app/tools/build_web.ps1
firebase deploy --only hosting --project bible-plan-boshkamal-20261101 --non-interactive
```

Generated chapter JSON files are intentionally not committed. The generator reconstructs them from the committed Bible assets. If a custom/older build omits them, the reader falls back to whole-book assets. Full-text search continues using the original complete books.

## User data and comparison

- Settings → Backup & restore: download a JSON snapshot of the plan, exact daily assignments, completed chapters, history, notes, highlights, favorites, reading time, badge dates and preferences. Authentication credentials are not exported.
- Restore accepts this application's versioned backup format, up to 10 MB. It validates the data and shows a summary before replacing local data. Signed-in restored data participates in the existing cloud sync.
- The reader's column icon opens Arabic / English comparison, with independent chapter selectors and a choice of WEB or KJV. Each column scrolls independently, and editions with differing numbering have an explanation.
- Additional Arabic translation candidates and source/licensing notes: [ARABIC-TRANSLATIONS.md](ARABIC-TRANSLATIONS.md).

## Checks

```powershell
cd flutter_app
node tools/split_chapters.cjs
flutter analyze --no-fatal-infos
flutter test
node --test tools/bootstrap_test.cjs tools/backup_download_test.cjs tools/split_chapters_test.cjs tools/sw_test.cjs tools/import_web_test.cjs
```

Primary site: https://mybibleplan.web.app/

The stable secondary Hosting snapshot and restoration command are documented in [HOSTING-BACKUP.md](HOSTING-BACKUP.md). It shares Authentication and Firestore with the primary site; portable JSON backups provide a separate copy of a user's local data.
