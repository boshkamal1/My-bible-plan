# Functions security audit — 2026-11-04

Scope: functions/ only. No deployment, live requests to push providers, IAM changes, or Firestore rule changes were performed. Rules and client subscription code were read to establish the trust boundary. This directory has no Git repository metadata; changes could not be verified with git diff.

## Findings and fixes

- High: authenticated subscription writers could make the Admin-backed scheduled function issue HTTPS requests to arbitrary hosts (SSRF). Added a parsed-URL allowlist: exact fcm.googleapis.com, exact updates.push.services.mozilla.com, valid subdomains of push.apple.com and notify.windows.com. HTTPS and default port 443 only; credentials, fragments, whitespace and backslashes rejected. IP literals, metadata addresses and suffix-confusion domains are rejected. Only reconstructed endpoint/keys fields reach web-push. The installed web-push implementation uses https.request directly and does not follow redirects. The allowlist trusts provider-controlled DNS; it does not independently pin or filter resolved addresses.
- Medium: stale query snapshots were used for sending and calculating schedules after a claim read newer data. Validation, scheduling and subscription selection now use the same transaction snapshot. Changed subscriptions are preserved during 404/410 cleanup rather than deleted unconditionally.
- Medium: malformed subscription keys, zone values and nextAt fields could cause failures or interrupt processing. Added bounded key decoding, 16-byte auth validation, 65-byte uncompressed P-256 public-key validation including curve membership, strict enabled/time/zone/timestamp checks, and per-device error isolation. Invalid reminders lose nextAt and are not retried until a client corrects/resaves them.
- Defense in depth: collection-group results are restricted to pushSubscriptions/{uid}/devices/{device}; other device documents are neither sent nor modified. Push requests have a five-second socket inactivity timeout. Error logs no longer include raw error text or subscription URLs.

## Authentication review

The only exported function is an onSchedule trigger. Invocation authorization relies on the Firebase-managed Scheduler/Cloud Run IAM configuration; spoofable Scheduler headers are not treated as authentication. Live IAM was not inspected. Before a future deployment, verify the service does not grant invocation to allUsers/allAuthenticatedUsers and that the Scheduler service account retains its intended invoke permission. Local rules read during this audit restrict subscription writes to the matching signed-in UID; the rules agent owns rule changes. The Admin SDK bypasses those rules, which is why the function validates stored data independently.

## Dependencies

npm audit initially reported 9 moderate findings. npm audit fix --ignore-scripts applied a compatible lockfile update and reported 8 moderate findings. A subsequent explicit npm audit --omit=dev --json reported 7 moderate findings, 0 high and 0 critical. These findings trace to uuid <11.1.1 and its dependent packages; advisory responses differed between calls. The production audit proposes firebase-admin 14.5.0, a major upgrade. No forced major upgrade or transitive-version override was applied. The application does not directly invoke the vulnerable UUID APIs, but transitive reachability has not been proven absent.

Installed direct dependencies after the compatible update: firebase-admin 13.10.0, firebase-functions 6.6.0, luxon 3.7.2, web-push 3.6.7. package.json includes npm test; package-lock.json records the compatible dependency update.

## Verification

npm test: 34 tests passed. Covers metadata/loopback/IP SSRF inputs, hostname confusion, disallowed ports/credentials/fragments, allowed providers including Windows, malformed and off-curve keys, fresh transaction state, invalid-record isolation, unrelated collection paths, repeat execution, 404/410 cleanup races, redacted errors, request timeout options, and scheduled-export loading/secret metadata. Syntax checks and npm ls --depth=0 passed. Tests use an in-memory Firestore transaction double and mocked delivery, not an emulator or deployed service. Local Node is 24.21.0; deployment declares Node 22, so Node 22 and emulator/integration verification remain outstanding.

## Remaining risks and operational limits

- Outstanding moderate dependency advisories require a separately validated major SDK migration.
- Client-written nextAt and unrestricted device creation can still be abused for excessive notifications/work; rate limits, device quotas and trusted scheduling require coordinated rules/data-model work. Deleted/disabled accounts are not rechecked through Firebase Auth on each send.
- A user can update/delete a subscription after a claim commits; one in-flight notification can still be sent. Claims advance nextAt before delivery, so crashes or transient failures can skip that day's reminder. This preserves the existing delivery model.
- Processing is sequential, capped at 100 due documents. The socket timeout is not a complete wall-clock deadline, and large backlogs can delay reminders. Unrelated collection-group results may occupy query slots even though they are ignored.
- New provider hostnames require an explicit reviewed allowlist update. Official Mozilla documentation identifies the exact production updates host; no official regional wildcard requirement was found, so that wildcard remains rejected.

References:
- https://firebase.google.com/docs/functions/schedule-functions
- https://mozilla-services.github.io/autopush-rs/
- https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers
- https://learn.microsoft.com/en-us/windows/apps/develop/notifications/push-notifications/wns-overview
- https://github.com/advisories/GHSA-w5hq-g745-h8pq

## Follow-up: live IAM and Node 22 (2026-11-04)

This section supersedes the earlier unverified-IAM/Node-22 status. Used existing Firebase CLI authentication in memory; no access or refresh token was printed, persisted by the audit script, or included in command arguments. All Google Cloud resource requests were read-only; no services were enabled and nothing was deployed. Removed the temporary credential-reading inspection script after use.

Project bible-plan-boshkamal-20261101: the live project IAM policy contains no allUsers or allAuthenticatedUsers grants. Project metadata has no parent, so no organization/folder inheritance applies. Cloud Functions, Cloud Run and Cloud Scheduler API requests each returned HTTP 403 with explicit SERVICE_DISABLED reasons for cloudfunctions.googleapis.com, run.googleapis.com and cloudscheduler.googleapis.com. Therefore function/service-level invocation policy and the Scheduler OIDC identity could not be inspected; absence of public invocation at the service level is NOT verified. These disabled APIs block readiness for scheduled-function publication/verification. Enabling APIs was outside this read-only request.

Ran npx --yes --package=node@22 node --test reminders.test.js: all 34 tests passed on Node 22. Emulator/integration checks remain outstanding, as do the previously documented moderate dependency advisories and quota/scheduling risks.
