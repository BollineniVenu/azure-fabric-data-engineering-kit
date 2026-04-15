# Power BI Report Design — Best Practices Guide

## 1. Data Model (Star Schema)

Always use a star schema — one fact table surrounded by dimension tables.

```
              dim_date ─────────────────┐
              dim_customer ──────────── fact_sales ── dim_product
              dim_region  ─────────────┘
```

Rules:
- No many-to-many relationships (use bridge tables instead)
- All relationships: single direction (from dimension to fact)
- Mark your date table: dim_date → Modeling → Mark as date table
- Hide FK columns from report view — expose only descriptive columns

---

## 2. DAX Best Practices

### Variables — always use them
```dax
// Good
[Revenue YoY %] =
VAR _cur = [Total Revenue]
VAR _py  = [Revenue PY]
RETURN DIVIDE( _cur - _py, _py, BLANK() )

// Bad — calculates Revenue twice
[Revenue YoY %] = DIVIDE( [Total Revenue] - [Revenue PY], [Revenue PY] )
```

### Avoid calculated columns — use measures
- Calculated columns expand model size and don't benefit from caching
- Measures are calculated on demand with full filter context

### DIVIDE over /
```dax
// Always use DIVIDE — handles division by zero gracefully
DIVIDE( [Revenue], [Orders], BLANK() )
```

### Use ALL / ALLSELECTED carefully
| Function | Removes | Use when |
|---|---|---|
| ALL(table) | All filters on table | % of grand total |
| ALLSELECTED(col) | External filters only | % within slicer selection |
| ALLEXCEPT(t, c) | All filters except column c | % within a group |

---

## 3. DirectLake Setup (Microsoft Fabric)

DirectLake reads directly from Fabric Lakehouse Delta tables — no import, no DirectQuery overhead.

### Steps:
1. Publish Gold Delta tables to Fabric Lakehouse
2. In Power BI Desktop → Get Data → Microsoft Fabric → Lakehouse
3. Select your workspace and lakehouse
4. Choose DirectLake mode (not Import or DirectQuery)
5. Build semantic model on gold.* tables only

### Optimise for DirectLake:
```python
# In your Gold notebook — always OPTIMIZE and VACUUM
spark.sql("OPTIMIZE gold.fact_sales ZORDER BY (sale_date, region)")
spark.sql("VACUUM gold.fact_sales RETAIN 168 HOURS")
```

---

## 4. Performance Tips

| Area | Tip |
|---|---|
| Visuals | Max 8 visuals per page — each fires a DAX query |
| Slicers | Use dropdown slicers instead of list for large dimensions |
| Filters | Apply filters at model level, not visual level |
| Images | Avoid base64 images in tables — use URLs instead |
| Aggregations | Use pre-built aggregation tables for large fact tables |
| Incremental refresh | Enable for fact tables > 1M rows |

### Page-level vs Report-level filters
- Report-level filters = applied to ALL pages
- Page-level = specific to one page
- Visual-level = only affects one visual

---

## 5. Row-Level Security (RLS)

```dax
// In Power BI Desktop → Modeling → Manage Roles
// Create role: RegionManager

// Filter on dim_region table:
[region] = USERPRINCIPALNAME()

// Or for mapped access:
[region] IN
    CALCULATETABLE(
        VALUES( user_region_map[region] ),
        user_region_map[email] = USERPRINCIPALNAME()
    )
```

Testing RLS: Modeling → View As Role → select your test role.

---

## 6. Deployment Checklist

Before publishing to Production workspace:

- [ ] Remove all hardcoded sample data
- [ ] All measures documented (description field filled in)
- [ ] Date table marked as date table
- [ ] RLS roles configured and tested
- [ ] Report theme applied (company branding)
- [ ] Mobile layout configured for key pages
- [ ] Scheduled refresh configured
- [ ] Workspace lineage reviewed (source → dataset → report)
- [ ] .pbix committed to Git with deploy_report.ps1 for CI/CD
