# Fix for Azure PowerShell Module Version Conflict

## Problem
The deployment script was failing with the following error:
```
Microsoft.PowerShell.Commands.WriteErrorException: This module requires Az.Accounts version 5.1.1. An earlier version of Az.Accounts is imported in the current PowerShell session. Please open a new session before importing this module. This error could indicate that multiple incompatible versions of the Azure PowerShell cmdlets are installed on your system.
```

## Root Cause
- Multiple versions of Azure PowerShell modules were installed
- Module version conflicts between Az.Accounts and Az.Purview
- Azure Deployment Scripts environment had pre-loaded modules causing conflicts

## Solutions Implemented

### Solution 1: Enhanced Module Management (script.ps1)
**Location**: `scripts/script.ps1`

**Changes Made**:
1. **Cleanup existing modules**: Remove all loaded Az modules from the session
2. **Uninstall conflicting versions**: Remove old module versions to prevent conflicts
3. **Update PowerShellGet**: Ensure latest package management capabilities
4. **Install specific versions**: Install compatible versions of required modules
5. **Proper import order**: Import modules in dependency order (Az.Accounts first)
6. **Enhanced error handling**: Better diagnostics and retry logic
7. **Verification steps**: Confirm modules are properly loaded and commands are available

**Key Features**:
- Removes all existing Az modules from session
- Installs specific compatible versions
- Includes retry logic for operations
- Provides detailed logging and diagnostics
- Verifies Azure context and authentication

### Solution 2: REST API Alternative (script-rest-api.ps1)
**Location**: `scripts/script-rest-api.ps1`

**Changes Made**:
1. **Minimal module dependencies**: Only installs essential modules (Az.Accounts, Az.Storage, Az.DataFactory)
2. **REST API calls**: Uses Azure Management REST API for Purview operations instead of PowerShell cmdlets
3. **Avoids Az.Purview module**: Completely bypasses the problematic Az.Purview module
4. **Direct HTTP calls**: Uses Invoke-RestMethod for all Purview-specific operations

**Key Features**:
- Eliminates Az.Purview module dependency
- Uses REST APIs for root collection admin assignment
- Maintains all original functionality
- Reduces module conflict potential

### Solution 3: Bicep Template Updates (template.bicep)
**Location**: `templates/template.bicep`

**Changes Made**:
1. **Updated PowerShell version**: Changed from 7.2 to 9.0 for better compatibility
2. **Extended timeout**: Increased to 30 minutes for module installation
3. **Enhanced dependencies**: Added proper dependency chain
4. **Environment variables**: Added configuration options
5. **Script URI options**: Provided both original and REST API script options

## Deployment Options

### Option 1: Use Enhanced Module Management
Update your repository to use the improved `script.ps1` and deploy with the updated Bicep template:

```bash
# Deploy using the enhanced script
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file templates/template.bicep \
  --parameters sqlServerAdminPassword=<your-password>
```

### Option 2: Use REST API Version
Change the Bicep template to use the REST API version:

```bicep
primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/purviewdemo/main/scripts/script-rest-api.ps1'
```

### Option 3: Local Testing
Test the scripts locally before deployment:

```powershell
# Test the enhanced version
.\scripts\script.ps1 -accountName "test" -resourceGroupName "test" # ... other parameters

# Test the REST API version
.\scripts\script-rest-api.ps1 -accountName "test" -resourceGroupName "test" # ... other parameters
```

## Recommended Approach

**For immediate resolution**: Use the REST API version (`script-rest-api.ps1`) as it completely avoids PowerShell module conflicts.

**For long-term maintenance**: Use the enhanced module management version (`script.ps1`) with proper testing.

## Additional Recommendations

1. **Test in staging environment** before production deployment
2. **Monitor deployment logs** for any remaining issues
3. **Consider pinning module versions** in your CI/CD pipeline
4. **Use Azure Cloud Shell** for consistent PowerShell environment
5. **Keep scripts in version control** for easy rollback

## Troubleshooting

If you still encounter issues:

1. Check the deployment script logs in Azure Portal
2. Verify managed identity permissions
3. Ensure all required Azure resources are properly created
4. Test individual API calls manually
5. Check Azure PowerShell version compatibility matrix

## Files Modified

- `scripts/script.ps1` - Enhanced with better module management
- `scripts/script-rest-api.ps1` - New REST API-based version
- `templates/template.bicep` - Updated deployment script configuration

## Testing

Both versions have been designed to:
- Handle module conflicts gracefully
- Provide detailed error messages
- Include retry logic for transient failures
- Verify successful operations before proceeding