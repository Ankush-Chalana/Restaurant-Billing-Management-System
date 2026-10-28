RESTAURANT BILLING AND MANAGEMENT SYSTEM — Oracle SQL/PLSQL

FILES
- restaurant_billing_management.sql : schema, sample data, package, triggers, demo and reports
- Restaurant_Billing_Project_Report.docx : project report, database design, tests and viva answers

RUN
1. Open Oracle SQL Developer and connect to a schema where you can create tables, sequences, triggers and packages.
2. Open the SQL file.
3. Run with F5 (Run Script). Enable DBMS Output to see invoice/report text.
4. Inspect the query result grids from the reporting section.
5. Check compilation issues with:
   SELECT name, type, line, text FROM user_errors ORDER BY name, sequence;

IMPORTANT
- The SQL script is intended for a fresh schema.
- It creates objects without first dropping existing objects.
- If rerunning, use the optional RESET section at the bottom of the SQL file, then rerun the full script.
- Demo rule: 10% discount for subtotal >= 2000; 5% tax on subtotal after discount. These are illustrative project rules.
