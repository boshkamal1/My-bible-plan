$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
  node tools/split_chapters.cjs
  if ($LASTEXITCODE -ne 0) { throw 'Chapter generation failed' }
  flutter build web --wasm --release
  if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
  node tools/verify_web_build.cjs
  if ($LASTEXITCODE -ne 0) { throw 'Web build verification failed' }
} finally {
  Pop-Location
}
