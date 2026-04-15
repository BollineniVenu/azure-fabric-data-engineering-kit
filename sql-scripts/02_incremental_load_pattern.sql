-- INCREMENTAL LOAD PATTERN - Control Table + Watermark
-- Works with Azure SQL and Fabric SQL Analytics Endpoint

-- 1. Create control table
CREATE TABLE dbo.pipeline_control (
    id               INT           IDENTITY(1,1) PRIMARY KEY,
    pipeline_name    NVARCHAR(200) NOT NULL,
    source_table     NVARCHAR(200) NOT NULL,
    watermark_col    NVARCHAR(100) NOT NULL DEFAULT 'modified_date',
    last_load_time   DATETIME2     NOT NULL DEFAULT '1900-01-01',
    last_rows_copied BIGINT        NOT NULL DEFAULT 0,
    last_run_status  NVARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    updated_at       DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

INSERT INTO dbo.pipeline_control (pipeline_name, source_table, watermark_col) VALUES
    ('IncrementalLoad', 'dbo.sales',     'modified_date'),
    ('IncrementalLoad', 'dbo.orders',    'updated_at'),
    ('IncrementalLoad', 'dbo.customers', 'last_modified');
GO

-- 2. Stored proc: update watermark after successful copy
CREATE OR ALTER PROCEDURE dbo.usp_UpdateWatermark
    @pipeline_name  NVARCHAR(200),
    @last_load_time DATETIME2,
    @rows_copied    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.pipeline_control
    SET    last_load_time   = @last_load_time,
           last_rows_copied = @rows_copied,
           last_run_status  = 'SUCCESS',
           updated_at       = GETUTCDATE()
    WHERE  pipeline_name    = @pipeline_name;
END;
GO

-- 3. Pipeline run log table
CREATE TABLE dbo.pipeline_run_log (
    log_id        INT        IDENTITY(1,1) PRIMARY KEY,
    table_name    NVARCHAR(200),
    status        NVARCHAR(20),
    rows_copied   BIGINT,
    run_at        DATETIME2,
    error_message NVARCHAR(MAX) NULL
);
GO

-- 4. Log proc
CREATE OR ALTER PROCEDURE dbo.usp_LogPipelineRun
    @table_name    NVARCHAR(200),
    @status        NVARCHAR(20),
    @rows_copied   BIGINT,
    @run_at        DATETIME2,
    @error_message NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.pipeline_run_log (table_name, status, rows_copied, run_at, error_message)
    VALUES (@table_name, @status, @rows_copied, @run_at, @error_message);
END;
GO

-- 5. Monitoring view
CREATE OR ALTER VIEW dbo.vw_pipeline_health AS
SELECT
    pc.pipeline_name, pc.source_table, pc.last_load_time,
    pc.last_rows_copied, pc.last_run_status,
    DATEDIFF(HOUR, pc.last_load_time, GETUTCDATE()) AS hours_since_last_load,
    COUNT(rl.log_id)                                AS total_runs,
    SUM(CASE WHEN rl.status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN rl.status = 'FAILED'  THEN 1 ELSE 0 END) AS failed_runs
FROM      dbo.pipeline_control pc
LEFT JOIN dbo.pipeline_run_log rl ON pc.source_table = rl.table_name
GROUP BY  pc.pipeline_name, pc.source_table, pc.last_load_time,
          pc.last_rows_copied, pc.last_run_status;
GO
