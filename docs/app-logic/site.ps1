# Serves the repo over HTTP on port 5180 (all interfaces, so reachable over Tailscale). / redirects to the app.
# Registered as the "easyday-logic-site" scheduled task (runs at logon). Run by hand: powershell -File docs/app-logic/site.ps1
$env:HOME_PATH = "/app/"
$env:PORT = "5180"
Set-Location (Resolve-Path "$PSScriptRoot\..\..")
& "C:\Program Files\nodejs\node.exe" serve.mjs
