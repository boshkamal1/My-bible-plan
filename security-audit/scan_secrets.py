"""Pattern scan Git objects without printing or recording secret values."""
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
patterns = {
    'private-key-block': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'service-account-private-key': re.compile(rb'"private_key"\s*:\s*"-----BEGIN'),
    'github-token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'google-oauth-refresh-token': re.compile(rb'1//[A-Za-z0-9_-]{40,}'),
    'aws-access-key-id': re.compile(rb'AKIA[0-9A-Z]{16}'),
}
objects = subprocess.check_output(['git', 'rev-list', '--objects', '--all'], cwd=root)
meta = subprocess.check_output(
    ['git', 'cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize) %(rest)'],
    input=objects, cwd=root)
blobs = []
for line in meta.decode('utf-8', errors='replace').splitlines():
    parts = line.split(' ', 3)
    if parts[1] == 'blob':
        blobs.append((parts[0], parts[3] if len(parts) == 4 else 'unknown'))
worker = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root,
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE)
findings = []
try:
    for oid, path in blobs:
        worker.stdin.write((oid + '\n').encode('ascii'))
        worker.stdin.flush()
        header = worker.stdout.readline().split()
        size = int(header[2])
        data = worker.stdout.read(size)
        worker.stdout.read(1)
        for kind, pattern in patterns.items():
            if pattern.search(data):
                findings.append({'kind': kind, 'path': path, 'object': oid})
finally:
    worker.stdin.close()
    worker.wait()
report = {
    'commitsScanned': int(subprocess.check_output(['git', 'rev-list', '--count', '--all'], cwd=root)),
    'uniqueBlobsScanned': len(blobs),
    'findings': findings,
    'scope': 'Pattern scan only; not proof of absence of every secret. Values are never recorded.',
}
(root / 'security-audit/secret-pattern-scan.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
