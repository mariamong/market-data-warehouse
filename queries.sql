-- ── 1. 30 day rolling average close price per ticker ─────────────────────────
-- Shows smoothed price trend, filtering out daily noise
SELECT
    ticker,
    date_key,
    close,
    ROUND(AVG(close) OVER (
        PARTITION BY ticker
        ORDER BY date_key
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    )::numeric, 4) AS rolling_30d_avg
FROM fact_prices
ORDER BY ticker, date_key;


-- ── 2. Monthly return per ticker (period over period) ────────────────────────
-- Compares each month's average close to the previous month
WITH monthly_avg AS (
    SELECT
        fp.ticker,
        dd.year,
        dd.month,
        ROUND(AVG(fp.close)::numeric, 4) AS avg_close
    FROM fact_prices fp
    JOIN dim_date dd ON fp.date_key = dd.date_key
    GROUP BY fp.ticker, dd.year, dd.month
)
SELECT
    ticker,
    year,
    month,
    avg_close,
    LAG(avg_close) OVER (PARTITION BY ticker ORDER BY year, month) AS prev_month_avg,
    ROUND(
        (avg_close - LAG(avg_close) OVER (PARTITION BY ticker ORDER BY year, month))
        / LAG(avg_close) OVER (PARTITION BY ticker ORDER BY year, month) * 100
    , 2) AS mom_return_pct
FROM monthly_avg
ORDER BY ticker, year, month;


-- ── 3. Sector level performance rollup ───────────────────────────────────────
-- Aggregates price performance by sector using the SCD company dimension
SELECT
    dc.sector,
    dd.year,
    dd.quarter,
    COUNT(DISTINCT fp.ticker) AS tickers_in_sector,
    ROUND(AVG(fp.close)::numeric, 4) AS avg_close,
    ROUND(AVG(fp.daily_return)::numeric, 6) AS avg_daily_return,
    ROUND(MAX(fp.daily_return)::numeric, 6) AS best_day_return,
    ROUND(MIN(fp.daily_return)::numeric, 6) AS worst_day_return
FROM fact_prices fp
JOIN dim_company dc ON fp.ticker = dc.ticker AND dc.is_current = TRUE
JOIN dim_date dd ON fp.date_key = dd.date_key
GROUP BY dc.sector, dd.year, dd.quarter
ORDER BY dc.sector, dd.year, dd.quarter;


-- ── 4. Best and worst performing days per ticker ─────────────────────────────
-- Uses RANK() to find top 5 and bottom 5 days by daily return
WITH ranked AS (
    SELECT
        ticker,
        date_key,
        close,
        daily_return,
        RANK() OVER (PARTITION BY ticker ORDER BY daily_return DESC) AS best_rank,
        RANK() OVER (PARTITION BY ticker ORDER BY daily_return ASC) AS worst_rank
    FROM fact_prices
    WHERE daily_return IS NOT NULL
)
SELECT
    ticker,
    date_key,
    close,
    daily_return,
    CASE
        WHEN best_rank <= 5 THEN 'Top 5 Best'
        WHEN worst_rank <= 5 THEN 'Top 5 Worst'
    END AS category
FROM ranked
WHERE best_rank <= 5 OR worst_rank <= 5
ORDER BY ticker, daily_return DESC;