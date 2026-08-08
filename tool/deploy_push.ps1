# Deploys the send-push Edge Function and secrets to Supabase.
#
# Usage (from the repo root):
#   .\tool\deploy_push.ps1 -FcmJsonPath C:\Users\Rohit\Desktop\firebase-adminsdk.json
#
# Prerequisites:
#   1. Firebase service account JSON (Firebase console > Project settings >
#      Service accounts > Generate new private key).
#   2. supabase_setup.sql already run in the Dashboard SQL editor (adds the
#      device_tokens table).
param(
  [Parameter(Mandatory = $true)]
  [string]$FcmJsonPath,
  [string]$PushSecret = 'studenthub-dev-push-secret'
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath $FcmJsonPath)) {
  throw "Service account file not found: $FcmJsonPath"
}

Write-Host 'Step 1/4: login (opens a browser / use an access token)' -ForegroundColor Cyan
supabase login
if ($LASTEXITCODE -ne 0) { throw 'supabase login failed' }

Write-Host 'Step 2/4: link this project'
supabase link --project-ref pdcfjkqermynsmezsyyt
if ($LASTEXITCODE -ne 0) { throw 'supabase link failed' }

Write-Host 'Step 3/4: set secrets'
$serviceAccountJson = Get-Content -LiteralPath $FcmJsonPath -Raw
supabase secrets set "FCM_SERVICE_ACCOUNT_JSON=$serviceAccountJson" "PUSH_SECRET=$PushSecret"
if ($LASTEXITCODE -ne 0) { throw 'secrets could not be set' }

Write-Host 'Step 4/4: deploy send-push (verify_jwt is off for this function)'
supabase functions deploy send-push
if ($LASTEXITCODE -ne 0) { throw 'deploy failed' }

Write-Host ''
Write-Host 'Done. Test with:'
Write-Host '  supabase functions logs send-push'