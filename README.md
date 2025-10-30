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

## �📦 Deployed Resources

The deployment creates a complete Purview demo environment including:

- **Microsoft Purview Account** - Data governance and catalog service
- **Azure SQL Database** - With AdventureWorksLT sample data
- **Azure Data Lake Storage Gen2** - With sample datasets
- **Azure Data Factory** - Pre-configured pipelines and datasets
- **Azure Synapse Analytics** - Analytics workspace
- **Azure Key Vault** - Secure credential storage
- **Managed Identity** - For secure service-to-service authentication

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