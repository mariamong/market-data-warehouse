# Query Performance Analysis

## Rolling 30 Day Average Query

### EXPLAIN ANALYZE Output
- **Execution time**: ~34ms
- **Join strategy**: Hash Join on ticker and date_key
- **Scan type**: Sequential scan (expected at current scale of 4,390 rows)
- **Window function**: WindowAgg applied after sort

### Notes
At 4,390 rows, Postgres's query planner correctly chooses sequential scans over 
index scans — the overhead of index lookup exceeds the cost of scanning a small 
table. The indexes on ticker and date_key become critical at millions of rows 
where sequential scans would be prohibitively slow.

### Index Usage at Scale
- `idx_fact_prices_ticker` — would activate for single-ticker queries
- `idx_fact_prices_date` — would activate for narrow date range queries
- `idx_dim_company_ticker` — activates on current record lookups