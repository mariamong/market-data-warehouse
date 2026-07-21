import os
import yfinance as yf
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

'''Reads .env file'''
load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

'''Initialize ticker, start, and end_date'''
TICKERS = ["AAPL", "MSFT", "GOOGL", "JPM", "GS"]
START_DATE = "2023-01-01"
END_DATE = "2026-07-07"

def load_dim_date(start, end):
    """Populate the date dimension table."""
    dates = pd.date_range(start=start, end=end, freq="D")
    rows = []
    for d in dates:
        rows.append({
            "date_key": d.date(),
            "year": d.year,
            "quarter": d.quarter,
            "month": d.month,
            "week": d.isocalendar().week,
            "day_of_week": d.dayofweek,
            "is_weekend": d.dayofweek >= 5
        })
    df = pd.DataFrame(rows)
    with engine.connect() as conn:
        for _, row in df.iterrows():
            conn.execute(text("""
                INSERT INTO dim_date (date_key, year, quarter, month, week, day_of_week, is_weekend)
                VALUES (:date_key, :year, :quarter, :month, :week, :day_of_week, :is_weekend)
                ON CONFLICT (date_key) DO NOTHING
            """), row.to_dict())
        conn.commit()
    print(f"Loaded {len(df)} dates into dim_date")

def load_dim_company():
    """Load current company records into SCD dimension."""
    with engine.connect() as conn:
        for ticker in TICKERS:
            info = yf.Ticker(ticker).info
            conn.execute(text("""
                INSERT INTO dim_company (ticker, name, sector, industry, effective_date, expiry_date, is_current)
                VALUES (:ticker, :name, :sector, :industry, CURRENT_DATE, NULL, TRUE)
                ON CONFLICT DO NOTHING
            """), {
                "ticker": ticker,
                "name": info.get("longName"),
                "sector": info.get("sector"),
                "industry": info.get("industry")
            })
        conn.commit()
    print(f"Loaded {len(TICKERS)} companies into dim_company")

def load_fact_prices():
    """Load historical price data and calculate daily returns."""
    for ticker in TICKERS:
        print(f"Loading {ticker}...")
        df = yf.download(ticker, start=START_DATE, end=END_DATE, auto_adjust=True)
        df = df.reset_index()
        df.columns = [c[0].lower() if isinstance(c, tuple) else c.lower() for c in df.columns]
        df["ticker"] = ticker
        df = df.sort_values("date")

        # Calculate daily return
        df["daily_return"] = df["close"].pct_change().round(6)
        df["date_key"] = pd.to_datetime(df["date"]).dt.date
        df = df[["ticker", "date_key", "open", "high", "low", "close", "volume", "daily_return"]]
        df = df.dropna(subset=["date_key"])

        with engine.connect() as conn:
            for _, row in df.iterrows():
                conn.execute(text("""
                    INSERT INTO fact_prices (ticker, date_key, open, high, low, close, volume, daily_return)
                    VALUES (:ticker, :date_key, :open, :high, :low, :close, :volume, :daily_return)
                    ON CONFLICT (ticker, date_key) DO NOTHING
                """), row.to_dict())
            conn.commit()
        print(f"Loaded {len(df)} rows for {ticker}")

if __name__ == "__main__":
    print("Loading dim_date...")
    load_dim_date(START_DATE, END_DATE)
    print("\nLoading dim_company...")
    load_dim_company()
    print("\nLoading fact_prices...")
    load_fact_prices()
    print("\nDone.")