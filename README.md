# Microsoft Purview Demo Setup

This repository provides an automated deployment for a pre-populated Microsoft Purview demo environment. This version includes **fixes for Azure PowerShell module version conflicts** that prevent deployment failures.

## Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/)
* Azure CLI installed and authenticated (`az login`)
* Sufficient permissions to create resources and assign RBAC roles
* No Azure Policies blocking Storage accounts or Event Hub namespace creation

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/navintkr/purview-demo.git
   cd purview-demo
   ```

2. **Create a resource group**:
   ```bash
   az group create --name "rg-purview-demo" --location "East US"
   ```

3. **Deploy the template**:
   ```bash
   az deployment group create \
     --resource-group "rg-purview-demo" \
     --template-file "templates/template.bicep" \
     --parameters sqlServerAdminPassword="<<your-sql-admin-password-here>>"
   ```

##  Deployed Resources

The deployment creates a complete Purview demo environment including:

- **Microsoft Purview Account** - Data governance and catalog service
- **Azure SQL Database** - With AdventureWorksLT sample data
- **Azure Data Lake Storage Gen2** - With sample datasets
- **Azure Data Factory** - Pre-configured pipelines and datasets
- **Azure Synapse Analytics** - Analytics workspace
- **Microsoft Fabric Capacity (F2 SKU)** - Fabric workspace with Lakehouse
- **Azure Key Vault** - Secure credential storage
- **Managed Identity** - For secure service-to-service authentication

## 🎯 Microsoft Fabric Integration

This deployment includes Microsoft Fabric integration with:

### Fabric Workspace & Lakehouse
- **F2 SKU Capacity** - Lowest cost tier for dev/test (2 capacity units)
- **Lakehouse** - For storing SQL data in Delta format
- **OneLake Integration** - Unified data lake storage

### Data Pipeline Flow
1. **SQL Database** → Azure Data Factory → **Fabric Lakehouse**
2. **Lakehouse Tables** → Power BI → **Reports & Dashboards**
3. **All assets governed** by Microsoft Purview

### Post-Deployment Configuration

After the automated deployment, complete these manual steps for full Fabric integration:

**📚 See detailed step-by-step guide**: [FABRIC_INTEGRATION.md](./FABRIC_INTEGRATION.md)

**Quick Steps**:

1. **Access Fabric Workspace**:
   - Navigate to [Power BI Portal](https://app.powerbi.com)
   - Find the workspace: `PurviewDemoWorkspace-[suffix]`

2. **Create Data Pipeline to Lakehouse**:
   ```
   - In Fabric workspace, create a new Data pipeline
   - Add Copy activity: SQL Database → Lakehouse
   - Use the SQL credentials from Key Vault
   - Map tables to Lakehouse Tables folder
   ```

3. **Create Power BI Report**:
   ```
   - Connect to Lakehouse using Direct Lake mode
   - Build report on AdventureWorksLT tables
   - Publish report to workspace
   ```

4. **Register Fabric in Purview**:
   ```
   - In Purview, add Fabric workspace as a data source
   - Configure scanning for Lakehouse assets
   - Enable lineage tracking from SQL → Lakehouse → Power BI
   ```

### Why Manual Steps?
Fabric workspace and lakehouse creation via REST API requires:
- Power BI Premium/Fabric capacity licenses
- Specific API permissions that may require tenant admin consent
- Power BI service principal authentication

The deployment script initiates the Fabric setup, but you may need to complete configuration manually through the Power BI/Fabric portal.

## 🔐 Security Features

- **Managed Identity Authentication** - No hardcoded credentials
- **Key Vault Integration** - Secure credential management
- **RBAC Assignments** - Least privilege access controls
- **Network Security** - Proper firewall configurations

## ⏱️ Deployment Time

- **Infrastructure**: ~5-10 minutes
- **Post-deployment scripts**: ~10-15 minutes
- **Data scanning & pipeline**: Additional 10-15 minutes

## 🔍 Validation

After deployment, verify the setup by:

1. Navigate to your Purview account: `https://[your-purview-account].purview.azure.com`
2. Check **Data Map** for collections and data sources
3. Verify **Data Catalog** for discovered assets
4. Review **Management** > **Role assignments** for proper permissions

## 🐛 Troubleshooting

If you encounter issues:

1. **Check deployment logs** in the Azure Portal under Resource Group > Deployments
2. **Review script execution** logs in the deployment script resource
3. **Verify permissions** - ensure your account has Owner or Contributor + User Access Administrator roles
4. **Check service availability** in your selected region


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.