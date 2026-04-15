# Azure Fabric Data Engineering Kit

A production-ready toolkit for **Microsoft Fabric** and **Azure Data Factory** covering the full Medallion Architecture pipeline from raw ingestion to Power BI reporting.

Built by [@BollineniVenu](https://github.com/BollineniVenu)

## What's Inside

| Folder | Contents |
|---|---|
| fabric-notebooks/ | Bronze, Silver, Gold medallion notebooks (PySpark + Delta Lake) |
| adf-pipelines/templates/ | Incremental load and full load ADF pipeline JSON templates |
| sql-scripts/ | Data quality checks, incremental load pattern, performance tuning |
| powerbi/dax-measures/ | 20+ production DAX measures (YoY, MTD, QTD, YTD, Rankings, RAG) |
| powerbi/deployment/ | PowerShell CI/CD deploy script via Service Principal |
| powerbi/best-practices/ | Star schema, DirectLake setup, RLS, and report design guide |
| .github/workflows/ | GitHub Actions: SQL lint, notebook validation, Power BI deploy |

## Architecture

Sources (Azure SQL / REST API / ADLS) -> ADF Pipelines -> Fabric Lakehouse (Bronze -> Silver -> Gold) -> Power BI DirectLake

## Quick Start

1. Import ADF templates into your Azure Data Factory
2. Upload Fabric notebooks to your Lakehouse in order 01 then 02 then 03
3. Run SQL scripts against your Azure SQL or Fabric SQL Endpoint
4. Connect Power BI Desktop: Get Data -> Microsoft Fabric -> Lakehouse
5. Import DAX measures from powerbi/dax-measures/sales_kpis.dax

## Related Repos

- covid19 (https://github.com/BollineniVenu/covid19) - Azure Data Factory project
- Fabric (https://github.com/BollineniVenu/Fabric) - Microsoft Fabric notebooks
- top-5-things-advanced-sql - Advanced SQL patterns

## License

MIT - free to use and adapt.
