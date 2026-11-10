"""Load LittleLemon_Data.xlsx into the Little Lemon analytics star schema.
Install: pip install pandas openpyxl mysql-connector-python
Run: python load_analytics.py --file ../data/LittleLemon_Data.xlsx
The script expects the schema in ../sql/little_lemon.sql to have been executed first.
"""
import argparse, os
import pandas as pd
import mysql.connector
from datetime import date

def connect():
    return mysql.connector.connect(
        host=os.getenv("MYSQL_HOST","localhost"),
        port=int(os.getenv("MYSQL_PORT","3306")),
        user=os.getenv("MYSQL_USER","root"),
        password=os.getenv("MYSQL_PASSWORD",""),
        database=os.getenv("MYSQL_DATABASE","little_lemon"),
    )

def date_key(value):
    d = pd.Timestamp(value).date()
    return int(d.strftime("%Y%m%d")), d

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--file",default="../data/LittleLemon_Data.xlsx")
    args=parser.parse_args()
    df=pd.read_excel(args.file)
    df.columns=[c.strip().lower().replace(" ","_").replace("-","_") for c in df.columns]
    df=df.rename(columns={"desert_name":"dessert_name"})
    df["country_code"]=df["country_code"].fillna("UNK")
    df["gross_profit"]=df["sales"]-df["cost"]-df["delivery_cost"]
    cnx=connect(); cur=cnx.cursor()
    try:
        for _,r in df.iterrows():
            cur.execute("""INSERT INTO DimCustomer(source_customer_id,customer_name)
                VALUES(%s,%s) ON DUPLICATE KEY UPDATE customer_name=VALUES(customer_name)""",
                (str(r.customer_id),str(r.customer_name)))
            cur.execute("SELECT customer_key FROM DimCustomer WHERE source_customer_id=%s",(str(r.customer_id),))
            customer_key=cur.fetchone()[0]

            cur.execute("""INSERT INTO DimGeography(city,country,postal_code,country_code)
                VALUES(%s,%s,%s,%s) ON DUPLICATE KEY UPDATE geography_key=LAST_INSERT_ID(geography_key)""",
                (str(r.city),str(r.country),str(r.postal_code),str(r.country_code)))
            cur.execute("""SELECT geography_key FROM DimGeography
                WHERE city=%s AND country=%s AND postal_code=%s""",(str(r.city),str(r.country),str(r.postal_code)))
            geography_key=cur.fetchone()[0]

            menu=(str(r.course_name),str(r.cuisine_name),str(r.starter_name),
                  str(r.dessert_name),str(r.drink),str(r.sides))
            cur.execute("""INSERT INTO DimMenu(course_name,cuisine_name,starter_name,dessert_name,drink,sides)
                VALUES(%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE menu_key=LAST_INSERT_ID(menu_key)""",menu)
            cur.execute("""SELECT menu_key FROM DimMenu WHERE course_name=%s AND cuisine_name=%s
                AND starter_name=%s AND dessert_name=%s AND drink=%s AND sides=%s""",menu)
            menu_key=cur.fetchone()[0]

            order_key,od=date_key(r.order_date); delivery_key,dd=date_key(r.delivery_date)
            for k,d in [(order_key,od),(delivery_key,dd)]:
                cur.execute("""INSERT IGNORE INTO DimDate(date_key,full_date,year_num,quarter_num,month_num,month_name,day_num)
                    VALUES(%s,%s,%s,%s,%s,%s,%s)""",
                    (k,d,d.year,(d.month-1)//3+1,d.month,d.strftime("%B"),d.day))
            cur.execute("""INSERT INTO FactSales
                (source_row_number,order_id,customer_key,geography_key,menu_key,order_date_key,delivery_date_key,
                 cost,sales,quantity,discount,delivery_cost,gross_profit)
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON DUPLICATE KEY UPDATE order_id=VALUES(order_id),sales=VALUES(sales)""",
                (int(r.row_number),str(r.order_id),customer_key,geography_key,menu_key,order_key,delivery_key,
                 float(r.cost),float(r.sales),int(r.quantity),float(r.discount),float(r.delivery_cost),float(r.gross_profit)))
        cnx.commit()
        print(f"Loaded {len(df):,} source rows into FactSales.")
    except Exception:
        cnx.rollback(); raise
    finally:
        cur.close(); cnx.close()

if __name__=="__main__": main()
