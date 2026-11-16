import glob
import os
import pandas as pd

csv_files = sorted(glob.glob("seed_data/*.csv"))

if not csv_files:
    print("No CSV files found in seed_data/")
    exit(1)

for path in csv_files:
    table_name = os.path.splitext(os.path.basename(path))[0]
    df = pd.read_csv(path)
    print(f"\n{'='*60}")
    print(f"TABLE: {table_name} | ROWS: {len(df):,} | COLS: {len(df.columns)}")
    print(f"{'='*60}")
    summary = pd.DataFrame({
        "dtype": df.dtypes.astype(str),
        "nulls": df.isnull().sum(),
        "unique": df.nunique(dropna=True),
        "sample": [df[col].dropna().iloc[0] if not df[col].dropna().empty else None for col in df.columns]
    })
    print(summary.to_string())
