param(
  [string]$Email = "admin@ruteando.cl",
  [string]$Password = "ruteando2026",
  [string]$Name = "Administrador Ruteando"
)

$ErrorActionPreference = "Stop"

$serviceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
if ([string]::IsNullOrWhiteSpace($serviceRoleKey)) {
  throw "Define SUPABASE_SERVICE_ROLE_KEY antes de ejecutar este script."
}

$projectUrl = "https://zexfyjefmomuaoamwycw.supabase.co"
$restUrl = "$projectUrl/rest/v1"
$headers = @{
  "apikey" = $serviceRoleKey
  "Authorization" = "Bearer $serviceRoleKey"
  "Content-Type" = "application/json"
}
$upsertHeaders = $headers.Clone()
$upsertHeaders["Prefer"] = "resolution=merge-duplicates,return=minimal"

$authBody = @{
  email = $Email
  password = $Password
  email_confirm = $true
  user_metadata = @{ name = $Name }
} | ConvertTo-Json -Depth 5

try {
  Invoke-RestMethod `
    -Method Post `
    -Uri "$projectUrl/auth/v1/admin/users" `
    -Headers $headers `
    -Body $authBody | Out-Null
  Write-Host "Usuario Auth creado: $Email"
} catch {
  $message = $_.ErrorDetails.Message
  if ($message -match "already registered|already been registered|User already registered") {
    Write-Host "El usuario Auth ya existe: $Email"
  } else {
    throw
  }
}

$roleBody = @{
  id = $Email
  rol = "admin"
  deshabilitado = $false
  debeCambiarContrasena = $false
  contrasenaTemporalVisible = $null
  actualizado = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri "$restUrl/roles_usuarios?on_conflict=id" `
  -Headers $upsertHeaders `
  -Body $roleBody | Out-Null

$profileBody = @{
  id = $Email
  nombre = $Name
  email = $Email
  actualizado = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri "$restUrl/perfiles_usuarios?on_conflict=id" `
  -Headers $upsertHeaders `
  -Body $profileBody | Out-Null

Write-Host "Admin base listo: $Email"
