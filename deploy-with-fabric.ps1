# Deploy Purview Demo with Fabric Integration
# This script helps deploy the solution with proper Fabric API access

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-purview-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "./templates/template.bicep",
    
    [Parameter(Mandatory=$true)]
    [string]$SqlAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentName = "template"
)

Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host "  Purview Demo Deployment with Fabric Integration"
Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host ""

# Step 1: Get current user's UPN
Write-Host "Step 1: Getting current user information..."
$currentUser = az ad signed-in-user show | ConvertFrom-Json
$userUpn = $currentUser.userPrincipalName
Write-Host "  User UPN: $userUpn"
Write-Host ""

# Step 2: Get Fabric API access token for the current user
Write-Host "Step 2: Acquiring Fabric API access token..."
Write-Host "  Note: This requires you to have Fabric Admin permissions in your tenant"
try {
    $fabricToken = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Fabric access token"
    }
    Write-Host "  ✓ Fabric API token acquired successfully"
    Write-Host ""
}
catch {
    Write-Warning "Failed to acquire Fabric API token: $_"
    Write-Host ""
    Write-Host "This may mean:"
    Write-Host "  1. You don't have Fabric enabled in your tenant"
    Write-Host "  2. You don't have Fabric admin permissions"
    Write-Host "  3. The Fabric API resource is not available"
    Write-Host ""
    Write-Host "The deployment will continue, but Fabric workspace creation will fail."
    Write-Host "You will need to manually create the Fabric workspace and lakehouse."
    Write-Host ""
    $fabricToken = ""
}

# Step 3: Deploy the Bicep template
Write-Host "Step 3: Deploying Bicep template..."
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Template: $TemplateFile"
Write-Host "  Deployment Name: $DeploymentName"
Write-Host ""

$deploymentCommand = "az deployment group create ``
    --resource-group `"$ResourceGroupName`" ``
    --template-file `"$TemplateFile`" ``
    --parameters ``
        sqlServerAdminPassword=`"$SqlAdminPassword`" ``
        fabricAdminUpn=`"$userUpn`" ``
    --mode Incremental ``
    --name `"$DeploymentName`""

Write-Host "Executing deployment..."
Write-Host ""
Invoke-Expression $deploymentCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host "  Deployment completed successfully!"
Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host ""

# Step 4: Check deployment script logs for Fabric setup status
Write-Host "Step 4: Checking Fabric setup status..."
Write-Host ""

$scriptLogs = az deployment-scripts show-log `
    --resource-group "$ResourceGroupName" `
    --name "script" `
    --query "log" -o tsv

if ($scriptLogs -match "MANUAL FABRIC SETUP REQUIRED") {
    Write-Host "⚠️  Automated Fabric setup was not successful."
    Write-Host ""
    Write-Host "Please check the deployment script logs for manual setup instructions:"
    Write-Host ""
    Write-Host "  az deployment-scripts show-log --resource-group `"$ResourceGroupName`" --name `"script`""
    Write-Host ""
    Write-Host "Or view the logs in Azure Portal:"
    Write-Host "  Resource Group → $ResourceGroupName → Deployment Scripts → script → Logs"
    Write-Host ""
}
elseif ($scriptLogs -match "Fabric workspace created") {
    Write-Host "✓ Fabric workspace and lakehouse created successfully!"
    
    # Extract workspace and lakehouse IDs from logs
    if ($scriptLogs -match "Fabric Workspace ID: ([a-f0-9-]+)") {
        $workspaceId = $matches[1]
        Write-Host "  Workspace ID: $workspaceId"
    }
    
    if ($scriptLogs -match "Lakehouse ID: ([a-f0-9-]+)") {
        $lakehouseId = $matches[1]
        Write-Host "  Lakehouse ID: $lakehouseId"
    }
    
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Open Fabric portal: https://app.fabric.microsoft.com"
    Write-Host "  2. Navigate to your workspace to configure data pipelines"
    Write-Host "  3. Create Power BI reports on the lakehouse data"
    Write-Host ""
}
else {
    Write-Host "Unable to determine Fabric setup status from logs."
    Write-Host "Please check the deployment script logs manually."
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "For detailed Fabric integration instructions, see:"
Write-Host "  FABRIC_INTEGRATION.md"
Write-Host ""
