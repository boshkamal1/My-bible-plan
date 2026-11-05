Run from this directory:

```powershell
npm install
firebase emulators:exec --only firestore --project demo-bible-rules --config firebase.json "node --test firestore.test.cjs"
```

The tests upload `../firestore.rules` to the emulator using initializeTestEnvironment.
Only the local emulator at 127.0.0.1:8187 and a demo project are used.
Tests cover client workflows, orphan access, client delete/recreate prevention,
missing status, privilege escalation, private legacy sync, update validation,
owner/timestamp immutability and push endpoint validation.

Client group deletion is deliberately denied. Trusted administrative deletion must
remove descendants before reusing a code. Existing orphan records need cleanup;
rules cannot detect arbitrary descendants when recreating a parent. Legacy member
records without explicit status/role need trusted migration; private reading data
keeps its legacy optional fields. Arbitrary private map/list values cannot be
exhaustively validated by these rules without a client schema migration.
