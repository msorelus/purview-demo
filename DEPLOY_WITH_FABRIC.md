# Deploying with Fabric Integration

This guide explains how to deploy the Purview demo with Microsoft Fabric integration.

## Understanding Fabric API Permissions

Microsoft Fabric workspace creation requires **user credentials** or **service principals with Fabric Admin role**. Managed identities used by Azure Deployment Scripts cannot create Fabric workspaces because:

1. Fabric capacity admins can only be **User Principal Names (UPNs/emails)**, not managed identities
2. Fabric API requires the caller to be a Fabric capacity admin or tenant admin
3. Azure Deployment Scripts use managed identity authentication by default

## Deployment Options

### Option 1: Deploy with Manual Fabric Setup (Recommended)

This is the most reliable approach and gives you full control over the Fabric workspace configuration.

**Steps:**

1. **Deploy the infrastructure** (without Fabric workspace):
   ```powershell
   az deployment group create `
     --resource-group "rg-purview-demo" `
     --template-file "templates/template.bicep" `
     --parameters `
       sqlServerAdminPassword="<YourPassword>" `
       fabricAdminUpn="<your-email@domain.com>" `
     --mode Incremental `
     --name "template"
   ```

2. **The deployment will**:
   - ✓ Create Fabric capacity (`purviewdemofabric`)
   - ✓ Add you as a Fabric capacity admin
   - ✗ Fail to create Fabric workspace (expected)
   - ✓ Display manual setup instructions in deployment logs

3. **Manually create Fabric workspace**:
   - Open https://app.fabric.microsoft.com
   - Create new workspace: `PurviewDemoWorkspace-<accountName>`
   - Assign to `purviewdemofabric` capacity
   - Create lakehouse: `SalesLakehouse`

4. **Follow remaining steps** in [FABRIC_INTEGRATION.md](./FABRIC_INTEGRATION.md)

---

### Option 2: Deploy with Helper Script (Automated - Not Working Yet)

**Note:** This approach is included for future enhancement but currently won't succeed due to Fabric API limitations.

Use the helper script which attempts to use your user credentials:

```powershell
.\deploy-with-fabric.ps1 -SqlAdminPassword "<YourPassword>"
```

**What it does:**
- Gets your UPN automatically
- Attempts to acquire Fabric API token
- Deploys infrastructure
- Checks deployment status
- Provides next steps

**Current limitation:** Even with user credentials, the deployment script runs in an isolated container and cannot use your user token for Fabric API calls. This is a known limitation of Azure Deployment Scripts.

---

## Checking Deployment Status

After deployment, check if Fabric setup was successful:

```powershell
az deployment-scripts show-log `
  --resource-group "rg-purview-demo" `
  --name "script" `
  --query "log" -o tsv | Select-String -Pattern "Fabric|MANUAL"
```

Look for either:
- ✓ **Success**: "Fabric workspace created: <workspace-id>"
- ⚠️ **Manual Required**: "MANUAL FABRIC SETUP REQUIRED"

---

## Troubleshooting

### Error: 401 Unauthorized when creating Fabric workspace

**Cause:** Managed identity doesn't have permissions to create Fabric workspaces.

**Solution:** This is expected. Follow Option 1 (Manual Fabric Setup).

---

### Error: Fabric capacity not found

**Cause:** Deployment might not have completed successfully.

**Check:**
```powershell
az rest --method GET `
  --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/rg-purview-demo/providers/Microsoft.Fabric/capacities/purviewdemofabric?api-version=2023-11-01"
```

**Solution:** Re-run the deployment.

---

### Fabric workspace exists but not linked to capacity

**Cause:** Workspace was created manually without capacity assignment.

**Solution:**
1. Open workspace in Fabric portal
2. Go to Workspace Settings → License
3. Select "Fabric capacity"
4. Choose `purviewdemofabric`
5. Save

---

## Why Can't This Be Fully Automated?

**Technical limitations:**

1. **Fabric capacity admins accept only UPNs (emails)**
   - Azure managed identities have Object IDs, not UPNs
   - Cannot add managed identity as Fabric capacity admin

2. **Fabric API requires specific permissions**
   - User must be Fabric capacity admin or tenant admin
   - Managed identity tokens don't convey these permissions

3. **Azure Deployment Scripts isolation**
   - Runs in containerized environment
   - Cannot access user's interactive authentication session
   - Uses managed identity by default

4. **No Azure RBAC for Fabric workspaces**
   - Fabric uses its own permission model
   - Not integrated with Azure Resource Manager RBAC

**Possible future solutions:**
- Use Azure Functions with user-assigned managed identity that's granted Power BI/Fabric Service Principal permissions
- Use Azure DevOps or GitHub Actions with service principal that has Fabric tenant admin role
- Wait for Fabric to support managed identities as capacity admins

---

## Next Steps

Once Fabric workspace and lakehouse are created (manually or automatically):

1. **Configure Data Factory Pipeline**
   - Connect to Fabric lakehouse
   - Copy SQL data to lakehouse

2. **Create Power BI Report**
   - Build report on lakehouse data
   - Publish to Fabric workspace

3. **Register in Purview**
   - Scan Fabric workspace
   - Enable data governance

See [FABRIC_INTEGRATION.md](./FABRIC_INTEGRATION.md) for detailed instructions.
