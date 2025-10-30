# Microsoft Fabric Integration Guide

This guide provides detailed steps to complete the Fabric integration after the automated deployment.

## Overview

The deployment creates:
- Microsoft Fabric Capacity (F2 SKU)
- Fabric Workspace
- Lakehouse for storing SQL data

## Architecture

```
┌─────────────────┐
│ Azure SQL DB    │
│ (AdventureWorks)│
└────────┬────────┘
         │
         │ Data Factory Pipeline
         ▼
┌─────────────────┐
│ Fabric Lakehouse│
│ (Delta Tables)  │
└────────┬────────┘
         │
         │ Direct Lake
         ▼
┌─────────────────┐     ┌──────────────────┐
│ Power BI Report │────▶│ Microsoft Purview│
│                 │     │ (Governance)     │
└─────────────────┘     └──────────────────┘
```

## Step 1: Access Your Fabric Workspace

1. Navigate to [Power BI Portal](https://app.powerbi.com)
2. Sign in with your Azure credentials
3. Click on **Workspaces** in the left navigation
4. Find your workspace: `PurviewDemoWorkspace-[suffix]`
5. Open the workspace

## Step 2: Verify Lakehouse Creation

1. In your Fabric workspace, you should see a Lakehouse named: `SalesLakehouse`
2. Click on the Lakehouse to open it
3. Verify the **Tables** and **Files** sections are visible

## Step 3: Create Data Pipeline (SQL to Lakehouse)

### Option A: Using Dataflow Gen2 (Recommended)

1. In Fabric workspace, click **+ New** → **Dataflow Gen2**
2. Click **Get data** → **Azure SQL Database**
3. Enter connection details:
   - Server: `[your-sql-server].database.windows.net`
   - Database: `[your-database-name]`
   - Authentication: SQL Server
   - Username: `sqladmin` (or your custom admin)
   - Password: Retrieve from Key Vault (`sql-secret`)
4. Select tables to import (e.g., `SalesLT.Customer`, `SalesLT.Product`, `SalesLT.SalesOrderHeader`)
5. For each query, set the destination:
   - Click **...** → **Data destination**
   - Select **Lakehouse**
   - Choose `SalesLakehouse`
   - Set **Update method**: Replace
   - Choose **Table name**: Use source name
6. Click **Publish** to save the dataflow
7. Click **Refresh now** to load the data

### Option B: Using Data Pipeline

1. In Fabric workspace, click **+ New** → **Data pipeline**
2. Name it: `SQL-to-Lakehouse-Pipeline`
3. Add **Copy data** activity
4. Configure Source:
   - **Source type**: Azure SQL Database
   - Create connection to your SQL database
   - Select tables to copy
5. Configure Sink:
   - **Sink type**: Lakehouse
   - Select `SalesLakehouse`
   - Choose **Tables** folder
   - **File format**: Delta
6. Map columns and configure any transformations
7. Save and **Run** the pipeline

## Step 4: Create Power BI Report

1. In the Lakehouse, go to the **Tables** section
2. Click **New semantic model**
3. Select the tables you want to include (e.g., Customer, Product, SalesOrderHeader)
4. Click **Create**
5. Once created, click **New report** or **Analyze in Excel**
6. Build your report with:
   - Sales by Product
   - Customer distribution
   - Revenue trends
   - Top customers
7. Save and publish the report to the workspace

### Sample DAX Measures

```dax
Total Sales = SUM(SalesOrderHeader[TotalDue])

Total Orders = COUNTROWS(SalesOrderHeader)

Average Order Value = DIVIDE([Total Sales], [Total Orders])

YTD Sales = TOTALYTD([Total Sales], SalesOrderHeader[OrderDate])
```

## Step 5: Register Fabric in Purview

### Register the Lakehouse

1. Navigate to [Microsoft Purview Portal](https://purview.azure.com)
2. Go to **Data Map** → **Sources**
3. Click **Register** → **Microsoft Fabric**
4. Enter details:
   - **Name**: Fabric-SalesLakehouse
   - **Workspace ID**: [From Fabric deployment output]
   - **Lakehouse ID**: [From Fabric deployment output]
5. Click **Register**

### Create Scan

1. On the registered source, click **New Scan**
2. Configure scan:
   - **Name**: Lakehouse-Initial-Scan
   - **Credential**: Use managed identity
   - **Scope**: Select all tables
3. Set scan trigger:
   - **Once** for initial scan
   - **Recurring** for ongoing governance
4. Review and **Run scan**

### Enable Lineage

1. In Purview, navigate to **Data Catalog**
2. Search for your Lakehouse tables
3. Click on a table → **Lineage** tab
4. Verify lineage showing:
   - SQL Database → Data Factory → Lakehouse → Power BI Report

## Step 6: Configure Governance Policies

### Classification

1. In Purview, go to **Data Map** → **Classifications**
2. Apply automatic classifications:
   - PII (Personal Identifiable Information)
   - Financial data
   - Customer data
3. Review classifications on Lakehouse tables

### Sensitivity Labels

1. Go to **Management** → **Sensitivity labels**
2. Apply labels to sensitive columns:
   - Customer email → Confidential
   - Order details → Internal
3. Labels will flow to Power BI reports

### Access Policies

1. Go to **Data policy** → **Data access policies**
2. Create policies for Lakehouse access:
   - Who can read tables
   - Who can modify data
   - Data retention rules

## Monitoring & Validation

### Check Data Flow

1. **SQL Database**: Verify data exists
   ```sql
   SELECT COUNT(*) FROM SalesLT.Customer
   SELECT COUNT(*) FROM SalesLT.Product
   ```

2. **Lakehouse**: Verify tables were created
   - Open Lakehouse in Fabric
   - Check row counts match SQL database

3. **Power BI**: Verify report displays data
   - Open published report
   - Refresh data
   - Verify visuals populate

### Check Purview Governance

1. **Data Map**: Verify Lakehouse appears as source
2. **Data Catalog**: Search for Lakehouse tables
3. **Lineage**: Verify end-to-end lineage
4. **Insights**: Check scan statistics

## Troubleshooting

### Lakehouse Connection Issues

**Problem**: Can't connect to Lakehouse from Data Factory

**Solution**:
- Verify Fabric capacity is running
- Check managed identity has permissions
- Ensure workspace ID is correct

### Purview Scan Failures

**Problem**: Purview can't scan Lakehouse

**Solution**:
- Grant Purview managed identity "Fabric Lakehouse Contributor" role
- Verify network connectivity
- Check if Fabric workspace allows external connections

### Power BI Report Not Refreshing

**Problem**: Report shows old data

**Solution**:
- Manually run the data pipeline
- Check pipeline execution history
- Verify Direct Lake mode is enabled
- Refresh semantic model

## Cost Optimization

### Fabric Capacity (F2 SKU)
- **Cost**: ~$262/month
- **Optimization**: Pause capacity when not in use
- **Auto-pause**: Configure in Fabric capacity settings

### Recommended Schedule
- **Business Hours**: 8 AM - 6 PM weekdays
- **Auto-pause**: After 30 minutes of inactivity
- **Estimated savings**: 60-70% cost reduction

## Next Steps

1. ✅ Create scheduled refresh for data pipeline (daily/hourly)
2. ✅ Set up alerts in Purview for data quality issues
3. ✅ Create additional Power BI reports
4. ✅ Configure row-level security in Power BI
5. ✅ Set up change data capture (CDC) for incremental loads

## Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/en-us/fabric/)
- [Lakehouse Tutorial](https://learn.microsoft.com/en-us/fabric/data-engineering/tutorial-lakehouse-introduction)
- [Power BI Direct Lake](https://learn.microsoft.com/en-us/power-bi/enterprise/directlake-overview)
- [Purview Fabric Integration](https://learn.microsoft.com/en-us/purview/register-scan-fabric-tenant)
