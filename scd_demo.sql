-- Slowly Changing Dimension Demo
-- Simulates Apple being reclassified from Technology to Communication Services

-- Step 1: Expire old record
UPDATE dim_company
SET expiry_date = '2026-07-21',
    is_current = FALSE
WHERE ticker = 'AAPL'
AND is_current = FALSE;

-- Step 2: View both historical records
SELECT ticker, sector, effective_date, expiry_date, is_current
FROM dim_company
WHERE ticker = 'AAPL'
ORDER BY effective_date;

-- Step 3: Query historical sector (before reclassification)
SELECT ticker, sector, effective_date, expiry_date
FROM dim_company
WHERE ticker = 'AAPL'
AND effective_date <= '2026-07-01'
AND (expiry_date > '2026-07-01' OR expiry_date IS NULL);

-- Step 4: Query current sector (after reclassification)
SELECT ticker, sector, effective_date, expiry_date
FROM dim_company
WHERE ticker = 'AAPL'
AND effective_date <= '2026-07-21'
AND (expiry_date > '2026-07-21' OR expiry_date IS NULL);