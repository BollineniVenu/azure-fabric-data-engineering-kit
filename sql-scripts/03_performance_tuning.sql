-- PERFORMANCE TUNING - Index, Stats, Partitioning
-- Use on Azure SQL DB, Synapse Dedicated Pool, Fabric SQL Endpoint

-- 1. Find missing indexes (top 20 by impact)
SELECT TOP 20
    ROUND(s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans), 0) AS improvement_measure,
    d.statement AS table_name,
    d.equality_columns, d.inequality_columns, d.included_columns,
    s.user_seeks, s.user_scans, s.last_user_seek
FROM sys.dm_db_missing_index_details       d
JOIN sys.dm_db_missing_index_groups        g ON d.index_handle  = g.index_handle
JOIN sys.dm_db_missing_index_group_stats   s ON g.index_group_handle = s.group_handle
WHERE d.database_id = DB_ID()
ORDER BY improvement_measure DESC;
GO

-- 2. Find duplicate/redundant indexes
SELECT t.name AS table_name, i1.name AS index1, i2.name AS index2,
    'Consider dropping ' + i2.name AS recommendation
FROM sys.indexes i1
JOIN sys.indexes i2 ON i1.object_id = i2.object_id AND i1.index_id < i2.index_id AND i1.type_desc = i2.type_desc
JOIN sys.tables  t  ON i1.object_id = t.object_id
WHERE i1.type > 0 AND i2.type > 0;
GO

-- 3. Top 20 most expensive queries
SELECT TOP 20
    qs.total_elapsed_time / qs.execution_count / 1000 AS avg_ms,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count       AS avg_logical_reads,
    qs.total_worker_time   / qs.execution_count / 1000 AS avg_cpu_ms,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats  qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_ms DESC;
GO

-- 4. Table sizes
SELECT s.name AS schema_name, t.name AS table_name, p.rows AS row_count,
    CAST(ROUND((SUM(a.total_pages) * 8) / 1024.0 / 1024.0, 2) AS DECIMAL(18,2)) AS total_gb
FROM sys.tables          t
JOIN sys.schemas         s ON t.schema_id  = s.schema_id
JOIN sys.indexes         i ON t.object_id  = i.object_id
JOIN sys.partitions      p ON i.object_id  = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
GROUP BY s.name, t.name, p.rows
ORDER BY total_gb DESC;
GO

-- 5. Partition fact table (Fabric / Synapse)
CREATE TABLE gold.fact_sales_partitioned
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX,
    PARTITION (year RANGE RIGHT FOR VALUES (2020,2021,2022,2023,2024,2025))
)
AS SELECT * FROM gold.fact_sales;
GO
