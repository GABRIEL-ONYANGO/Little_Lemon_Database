# Little Lemon Project — README

## Project overview
This repository implements an integrated Little Lemon booking database and sales analytics solution based on the supplied project brief and `LittleLemon_Data.xlsx`.

**Important source distinction:** the supplied Excel workbook is an order/sales dataset (21,000 line records), not a reservation/booking dataset. The operational booking database is therefore designed from the booking-system requirements in the brief, while the Excel rows populate a separate analytical star schema.

## Deliverables
- `sql/little_lemon.sql` — MySQL 8 schema, operational tables, analytics star schema, five required stored procedures and reference records.
- `python/booking_client.py` — Python client demonstrating calls to all five stored procedures.
- `python/load_analytics.py` — ETL loader from the supplied Excel workbook into `Dim*` and `FactSales`.
- `data/little_lemon_orders_clean.csv` — cleaned Tableau-ready extract.
- `diagrams/little_lemon_erd.png` — relational + dimensional model overview.
- `reports/` — analysis charts and project report.
- `tableau/` — Tableau starter workbook and build instructions.

## Setup
1. Install MySQL Server 8.0 and MySQL Workbench.
2. Open `sql/little_lemon.sql` in Workbench and execute the complete script.
3. Create a Python virtual environment and install dependencies:
   ```bash
   python -m venv .venv
   # Windows: .venv\Scripts\activate
   # macOS/Linux: source .venv/bin/activate
   pip install -r python/requirements.txt
   ```
4. Set environment variables using `python/.env.example` as a guide. Do not commit real passwords.
5. Load the Excel data into the star schema:
   ```bash
   python python/load_analytics.py --file "LittleLemon_Data.xlsx"
   ```
6. Run the interactive booking client:
   ```bash
   python python/booking_client.py
   ```

## MySQL Workbench
- Run the SQL script and refresh the Schemas panel.
- Use Database > Reverse Engineer to generate an EER diagram from `little_lemon`.
- The supplied PNG is a logical overview; the Workbench reverse-engineered model is the authoritative editable model after import.
- To test booking procedures, ensure customer/table reference rows exist. The SQL file inserts example customers and tables.

## Required stored procedures
| Procedure | Purpose |
|---|---|
| `GetMaxQuantity()` | Returns the maximum guest count in a booking |
| `ManageBooking(booking_id)` | Checks whether a booking exists and its status |
| `UpdateBooking(booking_id, date, table_id, guests)` | Updates a confirmed booking |
| `AddBooking(customer_id, date, table_id, guests)` | Validates and creates a booking |
| `CancelBooking(booking_id)` | Cancels a confirmed booking |

Example calls:
```sql
CALL GetMaxQuantity();
CALL ManageBooking(1);
CALL AddBooking(1, '2026-12-01 18:00:00', 2, 3);
CALL UpdateBooking(1, '2026-12-01 19:00:00', 2, 3);
CALL CancelBooking(1);
```

## Tableau analysis
Connect Tableau Desktop to `data/little_lemon_orders_clean.csv` (Text File) or to MySQL using the `FactSales` table joined to its dimensions. Recommended worksheets:
1. KPI cards: SUM(Sales), SUM(Quantity), SUM(Gross Profit), COUNTD(Order ID), COUNTD(Customer ID).
2. Monthly Sales Trend: `Order Month` vs `SUM(Sales)`.
3. Sales by Cuisine: `Cuisine Name` vs `SUM(Sales)`.
4. Top 10 Countries: `Country` vs `SUM(Sales)`, sorted descending and filtered to Top 10.
5. Quantity by Course: `Course Name` vs `SUM(Quantity)`.
6. Discount vs Sales: `Discount` vs `SUM(Sales)` (use bins or a scatter plot).

Dashboard suggestion: place KPI cards across the top; monthly trend in the center; cuisine and country charts below; add filters for Order Year, Country, Cuisine Name and Course Name. Use a consistent currency format only after confirming the currency represented by the source data.

## Data quality and interpretation notes
- 21,000 source rows and 1,000 distinct Order IDs; each order identifier appears on multiple detail rows.
- 1,000 distinct customers; the workbook has no missing values except 42 missing Country Code values.
- Country Code nulls are filled with `UNK` in the cleaned file; original workbook is not modified.
- 9,366 rows have Delivery Date earlier than Order Date. This is retained as supplied and flagged as a data-quality issue; verify source dates before using delivery-time KPIs.
- The workbook does not state a currency, so monetary values are labelled as source currency units.
- `Gross Profit` is a derived analytical measure: `Sales - Cost - Delivery Cost`. Discount is preserved as provided and is not subtracted again because the source does not specify whether Sales is pre- or post-discount.
- The Excel data is not inserted into operational `Bookings`; it is loaded into `FactSales`.

## Suggested GitHub repository structure
Keep this folder structure when committing. Exclude `.env`, database passwords, local virtual environments and large private data where required by your course rules.
