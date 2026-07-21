-- Slowly changing dimension for companies
-- Tracks sector reclassifications over time
CREATE TABLE IF NOT EXISTS dim_company (
    company_key     SERIAL PRIMARY KEY,
    ticker          VARCHAR(10) NOT NULL,
    name            VARCHAR(255),
    sector          VARCHAR(100),
    industry        VARCHAR(100),
    effective_date  DATE NOT NULL,
    expiry_date     DATE,
    is_current      BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- Index for fast current record lookups
CREATE INDEX IF NOT EXISTS idx_dim_company_ticker 
    ON dim_company(ticker) WHERE is_current = TRUE;

-- Date dimension for time based analysis
CREATE TABLE IF NOT EXISTS dim_date (
    date_key        DATE PRIMARY KEY,
    year            INT,
    quarter         INT,
    month           INT,
    week            INT,
    day_of_week     INT,
    is_weekend      BOOLEAN
);

-- Fact table for daily prices
CREATE TABLE IF NOT EXISTS fact_prices (
    price_key       SERIAL PRIMARY KEY,
    ticker          VARCHAR(10) NOT NULL,
    date_key        DATE REFERENCES dim_date(date_key),
    open            NUMERIC(12, 4),
    high            NUMERIC(12, 4),
    low             NUMERIC(12, 4),
    close           NUMERIC(12, 4),
    volume          BIGINT,
    daily_return    NUMERIC(10, 6),
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(ticker, date_key)
);

-- Index for ticker and date lookups
CREATE INDEX IF NOT EXISTS idx_fact_prices_ticker 
    ON fact_prices(ticker);
CREATE INDEX IF NOT EXISTS idx_fact_prices_date 
    ON fact_prices(date_key);