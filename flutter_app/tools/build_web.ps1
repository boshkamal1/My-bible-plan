$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
  node tools/split_chapters.cjs
  if ($LASTEXITCODE -ne 0) { throw 'Chapter generation failed' }
  flutter build web --release --no-wasm-dry-run
  if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
} finally {
  Pop-Location
}
