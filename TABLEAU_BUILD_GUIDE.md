# Tableau Desktop — Workbook Build Guide

## Connect
1. Open Tableau Desktop.
2. Under Connect > To a File, select Text File.
3. Open `../data/little_lemon_orders_clean.csv` (or select it from the extracted project folder).
4. Confirm data types: Order Date and Delivery Date = Date; Cost, Sales, Discount, Delivery Cost, Gross Profit = Number (decimal); Quantity = Number (whole); identifiers and postal codes = String.

## Worksheets
Create these worksheets with the exact names below:
- **01 Executive KPIs**: create KPI text sheets for SUM(Sales), SUM(Quantity), SUM(Gross Profit), COUNTD(Order ID), COUNTD(Customer ID).
- **02 Monthly Sales Trend**: Columns = Order Month; Rows = SUM(Sales); Marks = Line; sort ascending by month.
- **03 Sales by Cuisine**: Rows = Cuisine Name; Columns = SUM(Sales); Marks = Bar; sort descending.
- **04 Top 10 Countries**: Rows = Country; Columns = SUM(Sales); Filter Country > Top > By field > Top 10 by SUM(Sales).
- **05 Quantity by Course**: Rows = Course Name; Columns = SUM(Quantity); Marks = Bar.
- **06 Discount and Sales**: Columns = Discount; Rows = SUM(Sales); use Discount bins or a scatter plot; avoid interpreting the source Discount unit as currency.

## Dashboard: Little Lemon — Sales Performance
- Size: Automatic or 1200 × 800.
- Top: five KPI tiles.
- Middle: monthly sales trend (wide).
- Bottom: sales by cuisine, top 10 countries and quantity by course.
- Add dashboard filters: Order Year, Country, Cuisine Name, Course Name.
- Apply each filter to all worksheets using the same data source.
- Add a note: “Source workbook contains 21,000 order-line records; delivery dates precede order dates on 9,366 rows and require validation.”

## MySQL alternative
Connect Tableau to MySQL Server using the `little_lemon` database. Use `FactSales` as the fact table and relate:
- `FactSales.customer_key` → `DimCustomer.customer_key`
- `FactSales.geography_key` → `DimGeography.geography_key`
- `FactSales.menu_key` → `DimMenu.menu_key`
- `FactSales.order_date_key` → `DimDate.date_key`
Use a second alias of `DimDate` for `delivery_date_key` if delivery date analysis is required.

The supplied `.twb` is a starter connection/workbook file, not a substitute for validating the data connection in the installed Tableau Desktop version. After opening it, relink the CSV if Tableau prompts for the file location, then save the completed workbook as a packaged `.twbx` from Tableau Desktop.
