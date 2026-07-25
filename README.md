# market-data-warehouse
A financial market data warehouse with a normalized PostgreSQL schema, slowly changing dimensions, and analytical SQL queries for period over period and sector level analysis.

## Architecture

This project follows a **star schema** design:
- `fact_prices` — central fact table storing daily OHLCV price data and pre-computed 
  daily returns for 5 tickers across 3+ years
- `dim_company` — slowly changing dimension (SCD) tracking company sector 
  classifications over time with effective/expiry dates
- `dim_date` — date dimension pre-computing year, quarter, month, and week 
  attributes for fast time-based joins

## Schema Design Decisions

**Why a slowly changing dimension for companies?**
Company sector classifications change over time. A naive schema would overwrite 
the old value, losing history. Using SCD Type 2 (effective/expiry dates + 
is_current flag) allows point-in-time queries — "what sector was AAPL in on 
January 1st 2024?" returns the historically accurate answer.

**Why pre-compute daily_return at load time?**
Daily return could be calculated on the fly using LAG(close), but storing it 
pre-computed means analytical queries run faster and the calculation logic lives 
in one place rather than being duplicated across queries.

**Why NUMERIC(12,4) instead of FLOAT?**
Financial data requires exact decimal representation. FLOAT introduces rounding 
errors that are unacceptable when tracking prices to the cent. NUMERIC is exact.

**Why three indexes?**
- `idx_fact_prices_ticker` — speeds up single-ticker filters
- `idx_fact_prices_date` — speeds up date range queries and window functions
- `idx_dim_company_ticker WHERE is_current = TRUE` — partial index on current 
  company records only, making current-record lookups faster without indexing 
  historical rows

## Analytical Queries

Four queries in `queries.sql` demonstrate warehouse analytical capabilities:

1. **30-day rolling average** — smooths daily price noise to reveal trends using 
   `AVG() OVER (ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)`
2. **Period-over-period monthly return** — compares each month to the prior month 
   using `LAG()` window function
3. **Sector-level performance rollup** — aggregates returns by sector and quarter 
   by joining fact_prices to dim_company
4. **Best/worst performing days** — ranks daily returns per ticker using `RANK()`

## SCD Demo

`scd_demo.sql` demonstrates the slowly changing dimension by simulating Apple's 
reclassification from "Technology" to "Communication Services" and proving 
point-in-time historical queries return the correct sector.

## How to Run

```bash
# Install dependencies
pip install -r requirements.txt

# Create .env file
cp .env.example .env  # add your DATABASE_URL

# Create database
createdb market_warehouse

# Create schema
psql market_warehouse -f schema.sql

# Load data
python load_data.py

# Run analytical queries
psql market_warehouse -f queries.sql

# View SCD demo
psql market_warehouse -f scd_demo.sql
```

## Tech Stack
Python, PostgreSQL, SQLAlchemy, pandas, yfinance