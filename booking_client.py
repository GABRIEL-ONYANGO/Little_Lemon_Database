"""Python client examples for Little Lemon booking stored procedures."""
import os
import mysql.connector

def get_connection():
    return mysql.connector.connect(
        host=os.getenv("MYSQL_HOST","localhost"), port=int(os.getenv("MYSQL_PORT","3306")),
        user=os.getenv("MYSQL_USER","root"), password=os.getenv("MYSQL_PASSWORD",""),
        database=os.getenv("MYSQL_DATABASE","little_lemon"))

def call_procedure(name, args=()):
    # Procedure names below are fixed constants, never user-provided input.
    cnx=get_connection()
    try:
        cur=cnx.cursor()
        cur.callproc(name,args)
        for result in cur.stored_results():
            for row in result.fetchall(): print(row)
        cnx.commit()
    except Exception:
        cnx.rollback(); raise
    finally:
        cur.close(); cnx.close()

if __name__=="__main__":
    print("1 GetMaxQuantity | 2 ManageBooking | 3 AddBooking | 4 UpdateBooking | 5 CancelBooking")
    choice=input("Choose procedure: ").strip()
    if choice=="1": call_procedure("GetMaxQuantity")
    elif choice=="2": call_procedure("ManageBooking",(int(input("Booking ID: ")),))
    elif choice=="3":
        call_procedure("AddBooking",(int(input("Customer ID: ")),input("Date/time YYYY-MM-DD HH:MM:SS: "),
            int(input("Table ID: ")),int(input("Guests: "))))
    elif choice=="4":
        call_procedure("UpdateBooking",(int(input("Booking ID: ")),input("New date/time YYYY-MM-DD HH:MM:SS: "),
            int(input("New table ID: ")),int(input("Guests: "))))
    elif choice=="5": call_procedure("CancelBooking",(int(input("Booking ID: ")),))
    else: print("Invalid choice")
