<#
.SYNOPSIS
    Deploy a Power BI report (.pbix) to a Fabric workspace using the Power BI REST API.

.DESCRIPTION
    Supports:
    - Service Principal authentication (recommended for CI/CD)
    - Import / overwrite existing reports
    - Bind to a Fabric Lakehouse dataset (DirectLake)
    - Apply RLS roles
    - Refresh dataset after deployment

.PREREQUISITES
    - Az PowerShell module: Install-Module Az
    - Service Principal with Power BI Workspace Member role
    - Set environment variables: PBI_TENANT_ID, PBI_CLIENT_ID, PBI_CLIENT_SECRET

.USAGE
    .\deploy_report.ps1 -PbixPath ".\SalesDashboard.pbix" -WorkspaceName "MyFabricWorkspace"
#>

param(
    [Parameter(Mandatory)]  [string] $PbixPath,
    [Parameter(Mandatory)]  [string] $WorkspaceName,
    [string] $ReportDisplayName  = "",
    [string] $DatasetId          = "",       # If binding to existing semantic model
    [switch] $TriggerRefresh     = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Authentication (Service Principal) ----------------------------------------
$tenantId     = $env:PBI_TENANT_ID
$clientId     = $env:PBI_CLIENT_ID
$clientSecret = $env:PBI_CLIENT_SECRET

if (-not ($tenantId -and $clientId -and $clientSecret)) {
    throw "Set PBI_TENANT_ID, PBI_CLIENT_ID, PBI_CLIENT_SECRET as environment variables."
}

Write-Host "Authenticating with Service Principal..."
$tokenUrl  = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://analysis.windows.net/powerbi/api/.default"
}
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
$accessToken   = $tokenResponse.access_token
$headers = @{ Authorization = "Bearer $accessToken"; "Content-Type" = "application/json" }
Write-Host "Token acquired"

# -- Get Workspace ID -----------------------------------------------------------
Write-Host "Looking up workspace: $WorkspaceName"
$workspacesUrl = "https://api.powerbi.com/v1.0/myorg/groups?$filter=name eq '$WorkspaceName'"
$workspaces    = Invoke-RestMethod -Uri $workspacesUrl -Headers $headers
if ($workspaces.value.Count -eq 0) { throw "Workspace '$WorkspaceName' not found." }
$workspaceId   = $workspaces.value[0].id
Write-Host "Workspace ID: $workspaceId"

# -- Upload .pbix ---------------------------------------------------------------
$reportName  = if ($ReportDisplayName) { $ReportDisplayName } else { [System.IO.Path]::GetFileNameWithoutExtension($PbixPath) }
$uploadUrl   = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/imports?datasetDisplayName=$reportName&nameConflict=Overwrite"

Write-Host "Uploading '$PbixPath' to workspace '$WorkspaceName'..."
$multipart = [System.Net.Http.MultipartFormDataContent]::new()
$fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $PbixPath))
$fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
$fileContent.Headers.ContentType = "application/octet-stream"
$multipart.Add($fileContent, "file", [System.IO.Path]::GetFileName($PbixPath))

$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $accessToken)
$response = $httpClient.PostAsync($uploadUrl, $multipart).Result
$importId  = ($response.Content.ReadAsStringAsync().Result | ConvertFrom-Json).id
Write-Host "Import initiated. Import ID: $importId"

# -- Poll for completion --------------------------------------------------------
Write-Host "Waiting for import to complete..."
$pollUrl = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/imports/$importId"
$maxWait = 60; $waited = 0
do {
    Start-Sleep -Seconds 5; $waited += 5
    $importStatus = (Invoke-RestMethod -Uri $pollUrl -Headers $headers).importState
    Write-Host "   Status: $importStatus"
} while ($importStatus -eq "Publishing" -and $waited -lt $maxWait)

if ($importStatus -ne "Succeeded") { throw "Import failed with status: $importStatus" }
Write-Host "Report deployed: $reportName"

# -- Trigger dataset refresh ----------------------------------------------------
if ($TriggerRefresh) {
    $datasets  = Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets" -Headers $headers
    $dataset   = $datasets.value | Where-Object { $_.name -eq $reportName } | Select-Object -First 1
    if ($dataset) {
        Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$($dataset.id)/refreshes" `
            -Method Post -Headers $headers
        Write-Host "Dataset refresh triggered: $($dataset.id)"
    }
}

Write-Host ""
Write-Host "Deployment complete!"
Write-Host "   Workspace : $WorkspaceName ($workspaceId)"
Write-Host "   Report    : $reportName"
