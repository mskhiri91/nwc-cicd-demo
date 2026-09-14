#!/usr/bin/env python3
"""Generate full load and delta load Parquet files for the CI/CD demo.

Full load : the historical snapshot, loaded once.
Delta load: one day of changes, containing inserts, updates and deletes,
            which is what the MERGE logic has to handle correctly.
"""
import datetime as dt
import os
import random

import pandas as pd

random.seed(42)

OUT       = "sampledata"
N_CUST    = 1000
N_SALES   = 20000
CITIES    = ["Riyadh", "Jeddah", "Dammam", "Mecca", "Medina", "Tabuk"]
SEGMENTS  = ["Residential", "Commercial", "Government", "Industrial"]
BASE_TS   = dt.datetime(2026, 1, 1, 0, 0, 0)
DELTA_DAY = dt.date(2026, 9, 13)

os.makedirs(f"{OUT}/full/customer",  exist_ok=True)
os.makedirs(f"{OUT}/full/sales",     exist_ok=True)
os.makedirs(f"{OUT}/delta/customer", exist_ok=True)
os.makedirs(f"{OUT}/delta/sales",    exist_ok=True)

# ---------- full load ----------

customers = pd.DataFrame({
    "customer_id":      range(1, N_CUST + 1),
    "customer_name":    [f"Customer {i:04d}" for i in range(1, N_CUST + 1)],
    "city":             [random.choice(CITIES) for _ in range(N_CUST)],
    "segment":          [random.choice(SEGMENTS) for _ in range(N_CUST)],
    "last_modified_ts": [BASE_TS for _ in range(N_CUST)],
    "is_deleted":       [False] * N_CUST,
})
customers.to_parquet(f"{OUT}/full/customer/customer_full.parquet", index=False)

sales = pd.DataFrame({
    "sale_id":          range(1, N_SALES + 1),
    "customer_id":      [random.randint(1, N_CUST) for _ in range(N_SALES)],
    "sale_date":        [dt.date(2026, random.randint(1, 8), random.randint(1, 28))
                         for _ in range(N_SALES)],
    "amount":           [round(random.uniform(50, 9000), 2) for _ in range(N_SALES)],
    "quantity":         [random.randint(1, 40) for _ in range(N_SALES)],
    "last_modified_ts": [BASE_TS for _ in range(N_SALES)],
    "is_deleted":       [False] * N_SALES,
})
sales.to_parquet(f"{OUT}/full/sales/sales_full.parquet", index=False)

# ---------- delta load ----------
# 30 updates, 15 new customers, 5 deletes, plus one duplicate key
# on purpose so the deduplication step in the MERGE is actually exercised

delta_ts = dt.datetime.combine(DELTA_DAY, dt.time(6, 0, 0))
rows = []

for cid in random.sample(range(1, N_CUST + 1), 30):          # updates
    rows.append({
        "customer_id": cid,
        "customer_name": f"Customer {cid:04d} UPDATED",
        "city": random.choice(CITIES),
        "segment": random.choice(SEGMENTS),
        "last_modified_ts": delta_ts,
        "is_deleted": False,
    })

for cid in range(N_CUST + 1, N_CUST + 16):                    # inserts
    rows.append({
        "customer_id": cid,
        "customer_name": f"Customer {cid:04d} NEW",
        "city": random.choice(CITIES),
        "segment": random.choice(SEGMENTS),
        "last_modified_ts": delta_ts,
        "is_deleted": False,
    })

for cid in random.sample(range(1, N_CUST + 1), 5):            # soft deletes
    rows.append({
        "customer_id": cid,
        "customer_name": None,
        "city": None,
        "segment": None,
        "last_modified_ts": delta_ts,
        "is_deleted": True,
    })

# same key changed twice inside one batch, the classic MERGE trap
rows.append({
    "customer_id": rows[0]["customer_id"],
    "customer_name": rows[0]["customer_name"] + " AGAIN",
    "city": "Riyadh",
    "segment": "Government",
    "last_modified_ts": delta_ts + dt.timedelta(minutes=5),
    "is_deleted": False,
})

pd.DataFrame(rows).to_parquet(
    f"{OUT}/delta/customer/customer_delta_{DELTA_DAY:%Y%m%d}.parquet", index=False)

sales_rows = []
for sid in random.sample(range(1, N_SALES + 1), 200):         # updates
    sales_rows.append({
        "sale_id": sid,
        "customer_id": random.randint(1, N_CUST),
        "sale_date": dt.date(2026, 9, 12),
        "amount": round(random.uniform(50, 9000), 2),
        "quantity": random.randint(1, 40),
        "last_modified_ts": delta_ts,
        "is_deleted": False,
    })
for sid in range(N_SALES + 1, N_SALES + 101):                 # inserts
    sales_rows.append({
        "sale_id": sid,
        "customer_id": random.randint(1, N_CUST + 15),
        "sale_date": DELTA_DAY,
        "amount": round(random.uniform(50, 9000), 2),
        "quantity": random.randint(1, 40),
        "last_modified_ts": delta_ts,
        "is_deleted": False,
    })

pd.DataFrame(sales_rows).to_parquet(
    f"{OUT}/delta/sales/sales_delta_{DELTA_DAY:%Y%m%d}.parquet", index=False)

print("Generated:")
for root, _, files in os.walk(OUT):
    for f in files:
        print("  ", os.path.join(root, f))
