param(
    [string]$accountName,
    [string]$adfName,
    [string]$adfPipelineName,
    [string]$adfPrincipalId,
    [string]$location,
    [string]$objectId,
    [string]$resourceGroupName,
    [string]$sqlDatabaseName,
    [string]$sqlSecretName,
    [string]$sqlServerAdminLogin,
    [string]$sqlServerName,
    [string]$storageAccountName,
    [string]$subscriptionId,
    [string]$vaultUri
)

# Handle Azure PowerShell module version conflicts
Write-Host "Setting up Azure PowerShell modules..."

try {
    # Set PowerShell execution policy and security protocol
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Remove any existing Az modules from the session to prevent conflicts
    Write-Host "Cleaning up existing Azure PowerShell modules from current session..."
    Get-Module -Name Az.* | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Uninstall conflicting versions if they exist
    $conflictingModules = @('Az.Accounts', 'Az.Purview', 'Az.Storage', 'Az.DataFactory')
    foreach ($moduleName in $conflictingModules) {
        $installedVersions = Get-Module -Name $moduleName -ListAvailable
        if ($installedVersions) {
            Write-Host "Found existing versions of $moduleName, removing old versions..."
            $installedVersions | ForEach-Object {
                try {
                    Uninstall-Module -Name $moduleName -RequiredVersion $_.Version -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Warning "Could not uninstall $moduleName version $($_.Version): $($_.Exception.Message)"
                }
            }
        }
    }

    # Install PowerShellGet if needed (ensures we have latest package management)
    $psGet = Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $psGet -or $psGet.Version -lt [Version]'2.2.5') {
        Write-Host "Installing/updating PowerShellGet..."
        Install-Module -Name PowerShellGet -Force -AllowClobber -Scope CurrentUser
        Import-Module -Name PowerShellGet -Force
    }

    # Install required modules with compatible versions
    Write-Host "Installing compatible Azure PowerShell modules..."
    
    # Install Az.Accounts first (base module required by others)
    Write-Host "Installing Az.Accounts..."
    Install-Module -Name Az.Accounts -RequiredVersion 3.0.2 -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
    Import-Module -Name Az.Accounts -RequiredVersion 3.0.2 -Force
    
    # Install compatible versions of other modules
    Write-Host "Installing Az.Purview..."
    Install-Module -Name Az.Purview -Force -AllowClobber -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck
    
    Write-Host "Installing Az.Storage..."
    Install-Module -Name Az.Storage -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
    
    Write-Host "Installing Az.DataFactory..."
    Install-Module -Name Az.DataFactory -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
    
    # Import modules in the correct order (dependencies first)
    Write-Host "Importing Azure PowerShell modules..."
    Import-Module -Name Az.Accounts -Force
    Import-Module -Name Az.Storage -Force
    Import-Module -Name Az.DataFactory -Force
    Import-Module -Name Az.Purview -Force
    
    # Verify modules are loaded
    $loadedModules = Get-Module -Name Az.*
    Write-Host "Successfully loaded Azure PowerShell modules:"
    $loadedModules | ForEach-Object { Write-Host "  - $($_.Name) v$($_.Version)" }
    
    # Verify specific commands are available
    $purviewCommands = Get-Command -Module Az.Purview -Name "Add-AzPurviewAccountRootCollectionAdmin" -ErrorAction SilentlyContinue
    if (-not $purviewCommands) {
        throw "Az.Purview module loaded but Add-AzPurviewAccountRootCollectionAdmin command not available"
    }
    
    Write-Host "Azure PowerShell modules setup completed successfully."
}
catch {
    Write-Error "Failed to set up Azure PowerShell modules: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
    throw
}

# Variables
$pv_endpoint = "https://${accountName}.purview.azure.com"

function invokeWeb([string]$uri, [string]$access_token, [string]$method, [string]$body) { 
    $retryCount = 0
    $response = $null
    while (($null -eq $response) -and ($retryCount -lt 3)) {
        try {
            $response = Invoke-WebRequest -Uri $uri -Headers @{Authorization="Bearer $access_token"} -ContentType "application/json" -Method $method -Body $body
        }
        catch {
            Write-Host "[Error]"
            Write-Host "Token: ${access_token}"
            Write-Host "URI: ${uri}"
            Write-Host "Method: ${method}"
            Write-Host "Body: ${body}"
            Write-Host "Response:" $_.Exception.Response
            Write-Host "Exception:" $_.Exception
            $retryCount += 1
            $response = $null
            Start-Sleep 3
        }
    }
    Return $response.Content | ConvertFrom-Json -Depth 10
}

# [GET] Metadata Policy
function getMetadataPolicy([string]$access_token, [string]$collectionName) {
    $uri = "${pv_endpoint}/policystore/collections/${collectionName}/metadataPolicy?api-version=2021-07-01"
    $response = invokeWeb $uri $access_token "GET" $null
    Return $response
}

# Modify Metadata Policy
function addRoleAssignment([object]$policy, [string]$principalId, [string]$roleName) {
    Foreach ($attributeRule in $policy.properties.attributeRules) {
        if (($attributeRule.name).StartsWith("purviewmetadatarole_builtin_${roleName}:")) {
            Foreach ($conditionArray in $attributeRule.dnfCondition) {
                Foreach($condition in $conditionArray) {
                    if ($condition.attributeName -eq "principal.microsoft.id") {
                        $condition.attributeValueIncludedIn += $principalId
                    }
                 }
            }
        }
    }
}

# [PUT] Metadata Policy
function putMetadataPolicy([string]$access_token, [string]$metadataPolicyId, [object]$payload) {
    $uri = "${pv_endpoint}/policystore/metadataPolicies/${metadataPolicyId}?api-version=2021-07-01"
    $body = ($payload | ConvertTo-Json -Depth 10)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response

}

# [PUT] Key Vault
function putVault([string]$access_token, [hashtable]$payload) {
    $randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
    $keyVaultName = "keyVault-${randomId}"
    $uri = "${pv_endpoint}/scan/azureKeyVaults/${keyVaultName}"
    $body = ($payload | ConvertTo-Json)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response
}

# [PUT] Credential
function putCredential([string]$access_token, [hashtable]$payload) {
    $credentialName = $payload.name
    $uri = "${pv_endpoint}/proxy/credentials/${credentialName}?api-version=2020-12-01-preview"
    $body = ($payload | ConvertTo-Json -Depth 9)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response
}

# [PUT] Scan
function putScan([string]$access_token, [string]$dataSourceName, [hashtable]$payload) {
    $scanName = $payload.name
    $uri = "${pv_endpoint}/scan/datasources/${dataSourceName}/scans/${scanName}"
    $body = ($payload | ConvertTo-Json -Depth 9)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response
}

# [PUT] Run Scan
function runScan([string]$access_token, [string]$datasourceName, [string]$scanName) {
    $uri = "${pv_endpoint}/scan/datasources/${datasourceName}/scans/${scanName}/run?api-version=2018-12-01-preview"
    $payload = @{ scanLevel = "Full" }
    $body = ($payload | ConvertTo-Json)
    $response = invokeWeb $uri $access_token "POST" $body
    Return $response
}

# [POST] Create Glossary
function createGlossary([string]$access_token) {
    $uri = "${pv_endpoint}/catalog/api/atlas/v2/glossary"
    $payload = @{
        name = "Glossary"
        qualifiedName = "Glossary"
    }
    $body = ($payload | ConvertTo-Json -Depth 4)
    $response = invokeWeb $uri $access_token "POST" $body
    Return $response
}

# [POST] Import Glossary Terms
function importGlossaryTerms([string]$access_token, [string]$glossaryGuid, [string]$glossaryTermsTemplateUri) {
    $glossaryTermsFilename = "import-terms-sample.csv"
    Invoke-RestMethod -Uri $glossaryTermsTemplateUri -OutFile $glossaryTermsFilename
    $glossaryImportUri = "${pv_endpoint}/catalog/api/atlas/v2/glossary/${glossaryGuid}/terms/import?includeTermHierarchy=true&api-version=2021-05-01-preview"
    $fieldName = 'file'
    $filePath = (Get-Item $glossaryTermsFilename).FullName
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $fileStream = [System.IO.File]::OpenRead($filePath)
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $content.Add($fileContent, $fieldName, $glossaryTermsFilename)
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $access_token)
    $result = $client.PostAsync($glossaryImportUri, $content).Result
    return $result
}

# [PUT] Collection
function putCollection([string]$access_token, [string]$collectionFriendlyName, [string]$parentCollection) {
    $collectionName = -join ((97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
    $uri = "${pv_endpoint}/account/collections/${collectionName}?api-version=2019-11-01-preview"
    $payload = @{
        "name" = $collectionName
        "parentCollection"= @{
            "type" = "CollectionReference"
            "referenceName" = $parentCollection
        }
        "friendlyName" = $collectionFriendlyName
    }
    $body = ($payload | ConvertTo-Json -Depth 10)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response
}

# [PUT] Data Source
function putSource([string]$access_token, [hashtable]$payload) {
    $dataSourceName = $payload.name
    $uri = "${pv_endpoint}/scan/datasources/${dataSourceName}?api-version=2018-12-01-preview"
    $body = ($payload | ConvertTo-Json)
    $response = invokeWeb $uri $access_token "PUT" $body
    Return $response
}

# Verify Azure context and authentication
Write-Host "Verifying Azure authentication context..."
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "No Azure context found. Attempting to authenticate using managed identity..."
        # This should work automatically in Azure deployment scripts with managed identity
        Connect-AzAccount -Identity
        $context = Get-AzContext
    }
    
    Write-Host "Azure context verified:"
    Write-Host "  Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    Write-Host "  Account: $($context.Account.Id)"
    Write-Host "  Environment: $($context.Environment.Name)"
}
catch {
    Write-Error "Failed to establish Azure context: $($_.Exception.Message)"
    throw
}

# Add UAMI to Root Collection Admin
Write-Host "Adding User Assigned Managed Identity to Root Collection Admin..."
Write-Host "Parameters:"
Write-Host "  Account Name: $accountName"
Write-Host "  Resource Group: $resourceGroupName"
Write-Host "  Object ID: $objectId"

try {
    # Verify the Az.Purview module is properly loaded
    $purviewModule = Get-Module -Name Az.Purview
    if (-not $purviewModule) {
        throw "Az.Purview module is not loaded. Please check module installation."
    }
    
    Write-Host "Az.Purview module version: $($purviewModule.Version)"
    
    # Verify the command exists
    $command = Get-Command -Name "Add-AzPurviewAccountRootCollectionAdmin" -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Host "Available Az.Purview commands:"
        Get-Command -Module Az.Purview | Select-Object Name | Format-Table -AutoSize
        throw "Command Add-AzPurviewAccountRootCollectionAdmin not found in Az.Purview module"
    }
    
    # Add the root collection admin with retry logic
    $maxRetries = 3
    $retryCount = 0
    $success = $false
    
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Write-Host "Attempt $($retryCount + 1) to add root collection admin..."
            Add-AzPurviewAccountRootCollectionAdmin -AccountName $accountName -ResourceGroupName $resourceGroupName -ObjectId $objectId
            $success = $true
            Write-Host "Successfully added root collection admin."
        }
        catch {
            $retryCount++
            Write-Warning "Attempt $retryCount failed: $($_.Exception.Message)"
            if ($retryCount -lt $maxRetries) {
                Write-Host "Waiting 10 seconds before retry..."
                Start-Sleep -Seconds 10
            }
        }
    }
    
    if (-not $success) {
        throw "Failed to add root collection admin after $maxRetries attempts"
    }
}
catch {
    Write-Error "Failed to add root collection admin: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)"
    Write-Host "Available Az.Purview commands:"
    Get-Command -Module Az.Purview -ErrorAction SilentlyContinue | Select-Object Name | Format-Table -AutoSize
    throw
}

# Get Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

# 1. Update Root Collection Policy (Add Current User to Built-In Purview Roles)
$rootCollectionPolicy = getMetadataPolicy $access_token $accountName
addRoleAssignment $rootCollectionPolicy $objectId "data-curator"
addRoleAssignment $rootCollectionPolicy $objectId "data-source-administrator"
addRoleAssignment $rootCollectionPolicy $adfPrincipalId "data-curator"
$updatedPolicy = putMetadataPolicy $access_token $rootCollectionPolicy.id $rootCollectionPolicy

# 2. Refresh Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

# 3. Create a Key Vault Connection
$vaultPayload = @{
    properties = @{
        baseUrl = $vaultUri
        description = ""
    }
}
$vault = putVault $access_token $vaultPayload

# 4. Create a Credential
$credentialPayload = @{
    name = "sql-cred"
    properties = @{
        description = ""
        type = "SqlAuth"
        typeProperties = @{
            password = @{
                secretName = $sqlSecretName
                secretVersion = ""
                store = @{
                    referenceName = $vault.name
                    type = "LinkedServiceReference"
                }
                type = "AzureKeyVaultSecret"
            }
            user = $sqlServerAdminLogin
        }
    }
    type = "Microsoft.Purview/accounts/credentials"
}
$cred = putCredential $access_token $credentialPayload

# 5. Create Collections (Sales and Marketing)
$collectionSales = putCollection $access_token "Sales" $accountName
$collectionMarketing = putCollection $access_token "Marketing" $accountName
$collectionSalesName = $collectionSales.name
$collectionMarketingName = $collectionMarketing.name
Start-Sleep 30

# 6. Create a Source (Azure SQL Database)
$sourceSqlPayload = @{
    id = "datasources/AzureSqlDatabase"
    kind = "AzureSqlDatabase"
    name = "AzureSqlDatabase"
    properties = @{
        collection = @{
            referenceName = $collectionSalesName
            type = 'CollectionReference'
        }
        location = $location
        resourceGroup = $resourceGroupName
        resourceName = $sqlServerName
        serverEndpoint = "${sqlServerName}.database.windows.net"
        subscriptionId = $subscriptionId
    }
}
$source1 = putSource $access_token $sourceSqlPayload

# 7. Create a Scan Configuration
$randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
$scanName = "Scan-${randomId}"
$scanSqlPayload = @{
    kind = "AzureSqlDatabaseCredential"
    name = $scanName
    properties = @{
        databaseName = $sqlDatabaseName
        scanRulesetName = "AzureSqlDatabase"
        scanRulesetType = "System"
        serverEndpoint = "${sqlServerName}.database.windows.net"
        credential = @{
            credentialType = "SqlAuth"
            referenceName = $credentialPayload.name
        }
        collection = @{
            type = "CollectionReference"
            referenceName = $collectionSalesName
        }
    }
}
$scan1 = putScan $access_token $sourceSqlPayload.name $scanSqlPayload

# 8. Trigger Scan
$run1 = runScan $access_token $sourceSqlPayload.name $scanSqlPayload.name

# 9. Load Storage Account with Sample Data
$containerName = "bing"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$RepoUrl = 'https://api.github.com/repos/microsoft/BingCoronavirusQuerySet/zipball/master'
Invoke-RestMethod -Uri $RepoUrl -OutFile "${containerName}.zip"
Expand-Archive -Path "${containerName}.zip"
Set-Location -Path "${containerName}"
Get-ChildItem -File -Recurse | Set-AzStorageBlobContent -Container ${containerName} -Context $storageAccount.Context

# 10. Create a Source (ADLS Gen2)
$sourceAdlsPayload = @{
    id = "datasources/AzureDataLakeStorage"
    kind = "AdlsGen2"
    name = "AzureDataLakeStorage"
    properties = @{
        collection = @{
            referenceName = $collectionMarketingName
            type = 'CollectionReference'
        }
        location = $location
        endpoint = "https://${storageAccountName}.dfs.core.windows.net/"
        resourceGroup = $resourceGroupName
        resourceName = $storageAccountName
        subscriptionId = $subscriptionId
    }
}
$source2 = putSource $access_token $sourceAdlsPayload

# 11. Create a Scan Configuration
$randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
$scanName = "Scan-${randomId}"
$scanAdlsPayload = @{
    kind = "AdlsGen2Msi"
    name = $scanName
    properties = @{
        scanRulesetName = "AdlsGen2"
        scanRulesetType = "System"
        collection = @{
            type = "CollectionReference"
            referenceName = $collectionMarketingName
        }
    }
}
$scacn2 = putScan $access_token $sourceAdlsPayload.name $scanAdlsPayload

# 12. Trigger Scan
$run2 = runScan $access_token $sourceAdlsPayload.name $scanAdlsPayload.name

# 13. Run ADF Pipeline
Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $resourceGroupName -DataFactoryName $adfName -PipelineName $adfPipelineName

# 14. Populate Glossary
$glossaryGuid = (createGlossary $access_token).guid
$glossaryTermsTemplateUri = 'https://raw.githubusercontent.com/tayganr/purviewlab/main/assets/import-terms-sample.csv'
importGlossaryTerms $access_token $glossaryGuid $glossaryTermsTemplateUri