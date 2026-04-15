-- DATA QUALITY CHECKS - Silver Layer Validation
-- Run these against silver tables before promoting to Gold.

-- 1. NULL checks on key columns
SELECT 'silver.sales' AS table_name, 'sale_id NULL count' AS check_name,
    COUNT(*) AS failed_rows,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM silver.sales WHERE sale_id IS NULL
UNION ALL
SELECT 'silver.sales', 'unit_price negative', COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM silver.sales WHERE unit_price < 0
UNION ALL
-- 2. Duplicate PK check
SELECT 'silver.sales', 'Duplicate sale_id',
    COUNT(*) - COUNT(DISTINCT sale_id),
    CASE WHEN COUNT(*) = COUNT(DISTINCT sale_id) THEN 'PASS' ELSE 'FAIL' END
FROM silver.sales
UNION ALL
-- 3. Future date check
SELECT 'silver.sales', 'Future sale_date', COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM silver.sales WHERE sale_date > CAST(GETUTCDATE() AS DATE)
UNION ALL
-- 4. Orphan FK check
SELECT 'silver.sales', 'Orphan customer_id', COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM silver.sales s
LEFT JOIN silver.dim_customer c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
ORDER BY result DESC, check_name;
