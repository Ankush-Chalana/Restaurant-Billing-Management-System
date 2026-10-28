# 🍽️ Restaurant Billing and Management System

A database management mini-project developed using **Oracle SQL and PL/SQL** to manage restaurant menu items, customer information, orders, and billing calculations.

## 📌 Project Overview

The Restaurant Billing and Management System demonstrates how a relational database can help organize restaurant operations and calculate bills accurately. It uses Oracle SQL for database creation and data management, while PL/SQL implements reusable business logic through stored procedures, functions, triggers, cursors, and exception handling.

This project is intended for academic learning and demonstrates core Database Management System (DBMS) concepts.

## 🎯 Objectives

- Maintain restaurant menu items, categories, and prices.
- Store customer information.
- Record customer orders and their associated items.
- Calculate item totals, subtotals, tax, and final bills.
- Validate quantities and prices.
- Maintain relationships between database tables.
- Generate menu listings and basic sales reports.
- Demonstrate Oracle SQL and PL/SQL programming concepts.

## ✨ Features

- **Menu Management:** Insert, view, and update menu items.
- **Customer Management:** Maintain customer details.
- **Order Management:** Store orders and their associated items.
- **Automated Calculations:** Calculate line totals and bill amounts.
- **Data Validation:** Use constraints and triggers to reject invalid values.
- **Stored Procedures:** Reuse common database operations.
- **Functions:** Perform billing calculations.
- **Cursors:** Process and display menu records.
- **Exception Handling:** Handle database errors clearly.
- **Sales Reporting:** Summarize sales by menu category.

## 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| Oracle Database | Store and manage restaurant data |
| Oracle SQL | Create tables, query data, and manage records |
| PL/SQL | Implement database business logic |
| Oracle SQL Developer or SQL*Plus | Execute SQL and PL/SQL scripts |

> **Note:** This repository focuses on the database layer. Python, Tkinter, and a graphical user interface are not part of this version.

## 🗄️ Database Design

The project uses four core tables.

| Table | Description |
|---|---|
| `CUSTOMERS` | Stores customer names and contact information |
| `MENU_ITEMS` | Stores item names, categories, prices, and availability |
| `ORDERS` | Stores order IDs, dates, customer references, and statuses |
| `ORDER_DETAILS` | Stores ordered items, quantities, and sale-time prices |

### Entity Relationships

```text
CUSTOMERS
    |
    | 1-to-many
    v
  ORDERS
    |
    | 1-to-many
    v
ORDER_DETAILS
    ^
    | many-to-1
    |
MENU_ITEMS
```

- One customer can have multiple orders.
- One order can contain multiple order-detail records.
- Each order-detail record refers to one menu item.
- Primary and foreign keys help maintain data integrity.

## 🧩 SQL and PL/SQL Concepts Demonstrated

### 1. Database Tables and Constraints

The project uses `CREATE TABLE`, primary keys, foreign keys, `NOT NULL`, and `CHECK` constraints to define and validate restaurant data.

### 2. Sequences

Oracle sequences can generate unique identifiers for customers, menu items, orders, and order details.

### 3. Functions

Example functions include:

- `CALCULATE_LINE_TOTAL` — calculates quantity multiplied by unit price.
- `CALCULATE_BILL_TOTAL` — calculates an order's subtotal, tax, and final amount.

### 4. Stored Procedures

Example procedures include:

- `ADD_MENU_ITEM` — adds a menu item.
- `ADD_ORDER_DETAIL` — adds an item to an existing order after validating the quantity and menu item.

### 5. Triggers

A validation trigger checks order-detail values before insertion or update.

### 6. Cursors

A cursor retrieves available menu items and demonstrates row-by-row processing in PL/SQL.

### 7. Exception Handling

Exceptions such as `NO_DATA_FOUND` and custom application errors are used to handle invalid inputs and missing records.

## 🧾 Sample Bill

The following example uses illustrative prices and a demonstration tax rate of 5%.

| Item | Quantity | Unit Price | Amount |
|---|---:|---:|---:|
| Veg Burger | 2 | ₹120.00 | ₹240.00 |
| Cold Coffee | 1 | ₹80.00 | ₹80.00 |
| **Subtotal** | | | **₹320.00** |
| Illustrative tax (5%) | | | ₹16.00 |
| **Grand Total** | | | **₹336.00** |

*The tax rate is for demonstration only. Configure actual tax calculations according to applicable requirements.*

## ⚙️ Requirements

Before running the project, install or configure:

- Oracle Database with permission to create database objects.
- Oracle SQL Developer or SQL*Plus.
- A database user/schema with the required privileges.

## 🚀 Installation and Execution

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
```

Replace the URL with your actual GitHub repository URL.

### Step 2: Open Oracle SQL Developer

Connect to your Oracle Database using your database username, password, and connection details.

### Step 3: Create the Database Tables

Execute the table-creation SQL for:

1. `CUSTOMERS`
2. `MENU_ITEMS`
3. `ORDERS`
4. `ORDER_DETAILS`

Create parent tables before tables that reference them through foreign keys.

### Step 4: Create Sequences and Indexes

Run the sequence and index definitions after creating the tables.

### Step 5: Insert Sample Data

Insert sample menu items and customer records, then commit the transaction when appropriate.

### Step 6: Create PL/SQL Objects

Create the objects in a suitable dependency order:

1. Billing functions
2. Menu and order-detail procedures
3. Validation triggers
4. Cursor and exception-handling demonstration blocks

### Step 7: Test the Project

Run the sample SQL queries and PL/SQL blocks. Enable `DBMS_OUTPUT` in SQL Developer when testing blocks that print output.

> **Important:** Use the actual SQL files available in this repository. Some example statements may use manually supplied IDs; avoid duplicate IDs when repeating the setup.

## 🧪 Testing

| Test Case | Expected Result |
|---|---|
| Insert a valid menu item | Record is inserted successfully |
| Insert a negative price | Validation rejects the value |
| Add an order detail with a positive quantity | Detail is stored successfully if references exist |
| Add an order detail with quantity zero | Validation rejects the value |
| Reference a nonexistent order | Foreign-key constraint rejects the record |
| Calculate the sample bill | Subtotal ₹320; illustrative tax ₹16; total ₹336 |
| Run the category sales query | Sales are grouped by menu category |

## 🔐 Data Integrity and Security

- Use primary and foreign keys to maintain relationships.
- Validate prices, quantities, and order statuses.
- Grant database privileges only to authorized users.
- Commit or roll back transactions deliberately.
- Avoid storing raw payment-card information in project tables.
- Back up the database and test restoration procedures.

## ⚠️ Current Limitations

This academic version focuses on basic restaurant data and billing. It does not include a live payment gateway, a graphical user interface, ingredient-level inventory management, delivery tracking, or a complete discount and refund workflow.

## 🔮 Future Enhancements

- Add inventory and ingredient stock management.
- Add payment records and payment-status tracking.
- Support discounts, coupons, and refunds.
- Configure tax rules according to business requirements.
- Generate daily, weekly, and monthly sales reports.
- Introduce database roles for administrators, cashiers, and managers.
- Integrate a web or desktop interface in a future version.

## 🎓 Academic Project

**Project Title:** Restaurant Billing and Management System  
**Database Technology:** Oracle SQL and PL/SQL  
**Project Type:** DBMS / PL/SQL Mini Project

This project demonstrates the practical use of relational database design and procedural database programming for restaurant billing and order management.

## 📚 References

- [Oracle Database Documentation](https://docs.oracle.com/en/database/)
- [Oracle SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/)
- [Oracle PL/SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/)

---

⭐ If you find this project useful for learning SQL and PL/SQL, consider starring the repository.
