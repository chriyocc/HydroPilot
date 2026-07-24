$ErrorActionPreference = 'Stop'

$nodeBin = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin'
$pnpm = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\pnpm.cmd'

$env:CI = 'true'
$env:PATH = "$nodeBin;$env:PATH"

& $pnpm exec remotion studio --port 3005
