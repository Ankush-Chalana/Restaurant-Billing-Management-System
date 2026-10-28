/*
PROJECT: Restaurant Billing and Management System
PLATFORM: Oracle SQL / PL/SQL (SQL Developer or SQL*Plus)
PURPOSE: College mini-project demonstrating tables, constraints, sequences,
         procedures, functions, triggers, exception handling and reporting.

SETUP:
1. Connect to your own Oracle schema in SQL Developer.
2. Open this file and run it using F5 (Run Script), not Ctrl+Enter.
3. If you already ran it, remove the existing project tables/sequences first
   (see RESET section at the end), then run again.
4. Keep DBMS Output enabled to see invoice/report output.

NOTE:
- The script assumes a fresh schema.
- Tax rate and discount threshold/rate are illustrative project rules, not
  legal tax advice. Adjust them to your assignment's requirements.
*/

SET SERVEROUTPUT ON;

PROMPT === 1. TABLES ===

CREATE TABLE customers (
    customer_id    NUMBER PRIMARY KEY,
    customer_name  VARCHAR2(100) NOT NULL,
    phone          VARCHAR2(20),
    email          VARCHAR2(120),
    created_at     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_customers_phone UNIQUE (phone),
    CONSTRAINT uq_customers_email UNIQUE (email)
);

CREATE TABLE menu_items (
    menu_item_id   NUMBER PRIMARY KEY,
    item_name      VARCHAR2(100) NOT NULL,
    category       VARCHAR2(50) NOT NULL,
    price          NUMBER(10,2) NOT NULL,
    is_available   CHAR(1) DEFAULT 'Y' NOT NULL,
    CONSTRAINT uq_menu_item_name UNIQUE (item_name),
    CONSTRAINT ck_menu_price CHECK (price >= 0),
    CONSTRAINT ck_menu_available CHECK (is_available IN ('Y','N'))
);

CREATE TABLE restaurant_orders (
    order_id        NUMBER PRIMARY KEY,
    customer_id     NUMBER NOT NULL,
    order_date      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    order_status    VARCHAR2(20) DEFAULT 'OPEN' NOT NULL,
    subtotal        NUMBER(12,2) DEFAULT 0 NOT NULL,
    discount_amount NUMBER(12,2) DEFAULT 0 NOT NULL,
    tax_amount      NUMBER(12,2) DEFAULT 0 NOT NULL,
    total_amount    NUMBER(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),
    CONSTRAINT ck_order_status CHECK
        (order_status IN ('OPEN','PARTIALLY_PAID','PAID','CANCELLED')),
    CONSTRAINT ck_order_amounts CHECK
        (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0)
);

CREATE TABLE order_items (
    order_item_id NUMBER PRIMARY KEY,
    order_id      NUMBER NOT NULL,
    menu_item_id  NUMBER NOT NULL,
    quantity      NUMBER(5) NOT NULL,
    unit_price    NUMBER(10,2) NOT NULL,
    line_total    NUMBER(12,2) NOT NULL,
    CONSTRAINT fk_item_order FOREIGN KEY (order_id)
        REFERENCES restaurant_orders(order_id),
    CONSTRAINT fk_item_menu FOREIGN KEY (menu_item_id)
        REFERENCES menu_items(menu_item_id),
    CONSTRAINT ck_item_quantity CHECK (quantity > 0),
    CONSTRAINT ck_item_price CHECK (unit_price >= 0 AND line_total >= 0)
);

CREATE TABLE payments (
    payment_id     NUMBER PRIMARY KEY,
    order_id       NUMBER NOT NULL,
    payment_date   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    amount         NUMBER(12,2) NOT NULL,
    payment_method VARCHAR2(20) NOT NULL,
    reference_no   VARCHAR2(60),
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id)
        REFERENCES restaurant_orders(order_id),
    CONSTRAINT ck_payment_amount CHECK (amount > 0),
    CONSTRAINT ck_payment_method CHECK
        (payment_method IN ('CASH','CARD','UPI','BANK_TRANSFER'))
);

PROMPT === 2. SEQUENCES ===

CREATE SEQUENCE seq_customers START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_menu_items START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_orders START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_order_items START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_payments START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT === 3. TRIGGERS ===

/* Always use the current menu price when an order line is created/updated.
   Reject an unavailable menu item. */
CREATE OR REPLACE TRIGGER trg_order_item_price
BEFORE INSERT OR UPDATE OF menu_item_id, quantity ON order_items
FOR EACH ROW
DECLARE
    v_price menu_items.price%TYPE;
    v_available menu_items.is_available%TYPE;
BEGIN
    IF :NEW.quantity IS NULL OR :NEW.quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Quantity must be greater than zero.');
    END IF;

    SELECT price, is_available
      INTO v_price, v_available
      FROM menu_items
     WHERE menu_item_id = :NEW.menu_item_id;

    IF v_available <> 'Y' THEN
        RAISE_APPLICATION_ERROR(-20002, 'This menu item is currently unavailable.');
    END IF;

    :NEW.unit_price := v_price;
    :NEW.line_total := ROUND(v_price * :NEW.quantity, 2);
END;
/

/* Add a default payment timestamp and validate the payment value at the
   database boundary, even if someone inserts directly rather than using
   the package procedure. */
CREATE OR REPLACE TRIGGER trg_payment_validate
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    IF :NEW.amount IS NULL OR :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Payment amount must be greater than zero.');
    END IF;

    IF :NEW.payment_method NOT IN ('CASH','CARD','UPI','BANK_TRANSFER') THEN
        RAISE_APPLICATION_ERROR(-20004, 'Unsupported payment method.');
    END IF;

    IF :NEW.payment_date IS NULL THEN
        :NEW.payment_date := SYSTIMESTAMP;
    END IF;
END;
/

PROMPT === 4. PACKAGE SPECIFICATION ===

CREATE OR REPLACE PACKAGE restaurant_pkg AS
    PROCEDURE add_customer(
        p_name  IN VARCHAR2,
        p_phone IN VARCHAR2,
        p_email IN VARCHAR2,
        p_customer_id OUT NUMBER
    );

    PROCEDURE add_menu_item(
        p_name IN VARCHAR2,
        p_category IN VARCHAR2,
        p_price IN NUMBER,
        p_menu_item_id OUT NUMBER
    );

    PROCEDURE set_menu_availability(
        p_menu_item_id IN NUMBER,
        p_available IN CHAR
    );

    PROCEDURE create_order(
        p_customer_id IN NUMBER,
        p_order_id OUT NUMBER
    );

    PROCEDURE add_order_item(
        p_order_id IN NUMBER,
        p_menu_item_id IN NUMBER,
        p_quantity IN NUMBER
    );

    FUNCTION calculate_bill(p_order_id IN NUMBER) RETURN NUMBER;

    PROCEDURE record_payment(
        p_order_id IN NUMBER,
        p_amount IN NUMBER,
        p_method IN VARCHAR2,
        p_reference IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE print_invoice(p_order_id IN NUMBER);
    PROCEDURE daily_sales_report(p_report_date IN DATE DEFAULT TRUNC(SYSDATE));
END restaurant_pkg;
/

PROMPT === 5. PACKAGE BODY ===

CREATE OR REPLACE PACKAGE BODY restaurant_pkg AS
    c_tax_rate CONSTANT NUMBER := 0.05;       -- 5% demonstration tax
    c_discount_threshold CONSTANT NUMBER := 2000;
    c_discount_rate CONSTANT NUMBER := 0.10; -- 10% when subtotal >= 2000

    PROCEDURE recalculate_order(p_order_id IN NUMBER) IS
        v_subtotal NUMBER(12,2);
        v_discount NUMBER(12,2);
        v_tax NUMBER(12,2);
        v_total NUMBER(12,2);
        v_status restaurant_orders.order_status%TYPE;
    BEGIN
        SELECT order_status
          INTO v_status
          FROM restaurant_orders
         WHERE order_id = p_order_id
         FOR UPDATE;

        IF v_status <> 'OPEN' THEN
            RAISE_APPLICATION_ERROR(-20005, 'Only OPEN orders can be changed.');
        END IF;

        SELECT NVL(SUM(line_total),0)
          INTO v_subtotal
          FROM order_items
         WHERE order_id = p_order_id;

        IF v_subtotal >= c_discount_threshold THEN
            v_discount := ROUND(v_subtotal * c_discount_rate, 2);
        ELSE
            v_discount := 0;
        END IF;

        v_tax := ROUND((v_subtotal - v_discount) * c_tax_rate, 2);
        v_total := v_subtotal - v_discount + v_tax;

        UPDATE restaurant_orders
           SET subtotal = v_subtotal,
               discount_amount = v_discount,
               tax_amount = v_tax,
               total_amount = v_total
         WHERE order_id = p_order_id;
    END recalculate_order;


    PROCEDURE add_customer(
        p_name IN VARCHAR2,
        p_phone IN VARCHAR2,
        p_email IN VARCHAR2,
        p_customer_id OUT NUMBER
    ) IS
    BEGIN
        IF TRIM(p_name) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20006, 'Customer name is required.');
        END IF;

        p_customer_id := seq_customers.NEXTVAL;
        INSERT INTO customers(customer_id, customer_name, phone, email)
        VALUES (p_customer_id, TRIM(p_name), TRIM(p_phone), TRIM(p_email));
    END add_customer;


    PROCEDURE add_menu_item(
        p_name IN VARCHAR2,
        p_category IN VARCHAR2,
        p_price IN NUMBER,
        p_menu_item_id OUT NUMBER
    ) IS
    BEGIN
        IF TRIM(p_name) IS NULL OR TRIM(p_category) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20007, 'Item name and category are required.');
        END IF;

        IF p_price IS NULL OR p_price < 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Price must be zero or greater.');
        END IF;

        p_menu_item_id := seq_menu_items.NEXTVAL;
        INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
        VALUES (p_menu_item_id, TRIM(p_name), TRIM(p_category), p_price, 'Y');
    END add_menu_item;


    PROCEDURE set_menu_availability(
        p_menu_item_id IN NUMBER,
        p_available IN CHAR
    ) IS
    BEGIN
        IF p_available NOT IN ('Y','N') THEN
            RAISE_APPLICATION_ERROR(-20009, 'Availability must be Y or N.');
        END IF;

        UPDATE menu_items
           SET is_available = p_available
         WHERE menu_item_id = p_menu_item_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Menu item not found.');
        END IF;
    END set_menu_availability;


    PROCEDURE create_order(
        p_customer_id IN NUMBER,
        p_order_id OUT NUMBER
    ) IS
        v_customer_count NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_customer_count
          FROM customers
         WHERE customer_id = p_customer_id;

        IF v_customer_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Customer not found.');
        END IF;

        p_order_id := seq_orders.NEXTVAL;
        INSERT INTO restaurant_orders(
            order_id, customer_id, order_status, subtotal,
            discount_amount, tax_amount, total_amount
        ) VALUES (p_order_id, p_customer_id, 'OPEN', 0, 0, 0, 0);
    END create_order;


    PROCEDURE add_order_item(
        p_order_id IN NUMBER,
        p_menu_item_id IN NUMBER,
        p_quantity IN NUMBER
    ) IS
        v_status restaurant_orders.order_status%TYPE;
    BEGIN
        IF p_quantity IS NULL OR p_quantity <= 0 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Quantity must be greater than zero.');
        END IF;

        SELECT order_status
          INTO v_status
          FROM restaurant_orders
         WHERE order_id = p_order_id
         FOR UPDATE;

        IF v_status <> 'OPEN' THEN
            RAISE_APPLICATION_ERROR(-20013, 'Items can only be added to an OPEN order.');
        END IF;

        INSERT INTO order_items(
            order_item_id, order_id, menu_item_id, quantity, unit_price, line_total
        ) VALUES (
            seq_order_items.NEXTVAL, p_order_id, p_menu_item_id, p_quantity, 0, 0
        );

        recalculate_order(p_order_id);
    END add_order_item;


    FUNCTION calculate_bill(p_order_id IN NUMBER) RETURN NUMBER IS
        v_total restaurant_orders.total_amount%TYPE;
    BEGIN
        SELECT total_amount
          INTO v_total
          FROM restaurant_orders
         WHERE order_id = p_order_id;

        RETURN v_total;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20014, 'Order not found.');
    END calculate_bill;


    PROCEDURE record_payment(
        p_order_id IN NUMBER,
        p_amount IN NUMBER,
        p_method IN VARCHAR2,
        p_reference IN VARCHAR2 DEFAULT NULL
    ) IS
        v_total restaurant_orders.total_amount%TYPE;
        v_status restaurant_orders.order_status%TYPE;
        v_paid NUMBER(12,2);
        v_balance NUMBER(12,2);
    BEGIN
        IF p_amount IS NULL OR p_amount <= 0 THEN
            RAISE_APPLICATION_ERROR(-20015, 'Payment must be greater than zero.');
        END IF;

        IF p_method NOT IN ('CASH','CARD','UPI','BANK_TRANSFER') THEN
            RAISE_APPLICATION_ERROR(-20016, 'Method must be CASH, CARD, UPI, or BANK_TRANSFER.');
        END IF;

        SELECT total_amount, order_status
          INTO v_total, v_status
          FROM restaurant_orders
         WHERE order_id = p_order_id
         FOR UPDATE;

        IF v_status = 'CANCELLED' THEN
            RAISE_APPLICATION_ERROR(-20017, 'Cannot pay a cancelled order.');
        END IF;

        SELECT NVL(SUM(amount),0)
          INTO v_paid
          FROM payments
         WHERE order_id = p_order_id;

        v_balance := ROUND(v_total - v_paid, 2);

        IF v_balance <= 0 THEN
            RAISE_APPLICATION_ERROR(-20018, 'This order is already fully paid.');
        END IF;

        IF p_amount > v_balance THEN
            RAISE_APPLICATION_ERROR(-20019, 'Payment exceeds the outstanding balance of ' ||
                                    TO_CHAR(v_balance, 'FM999999990.00'));
        END IF;

        INSERT INTO payments(payment_id, order_id, amount, payment_method, reference_no)
        VALUES (seq_payments.NEXTVAL, p_order_id, p_amount, p_method, p_reference);

        v_paid := v_paid + p_amount;

        IF v_paid >= v_total THEN
            UPDATE restaurant_orders
               SET order_status = 'PAID'
             WHERE order_id = p_order_id;
        ELSE
            UPDATE restaurant_orders
               SET order_status = 'PARTIALLY_PAID'
             WHERE order_id = p_order_id;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20020, 'Order not found.');
    END record_payment;


    PROCEDURE print_invoice(p_order_id IN NUMBER) IS
        v_customer customers.customer_name%TYPE;
        v_date restaurant_orders.order_date%TYPE;
        v_status restaurant_orders.order_status%TYPE;
        v_subtotal restaurant_orders.subtotal%TYPE;
        v_discount restaurant_orders.discount_amount%TYPE;
        v_tax restaurant_orders.tax_amount%TYPE;
        v_total restaurant_orders.total_amount%TYPE;
        v_paid NUMBER(12,2);
    BEGIN
        SELECT c.customer_name, o.order_date, o.order_status,
               o.subtotal, o.discount_amount, o.tax_amount, o.total_amount
          INTO v_customer, v_date, v_status, v_subtotal, v_discount, v_tax, v_total
          FROM restaurant_orders o
          JOIN customers c ON c.customer_id = o.customer_id
         WHERE o.order_id = p_order_id;

        DBMS_OUTPUT.PUT_LINE('==============================================');
        DBMS_OUTPUT.PUT_LINE('           RESTAURANT TAX INVOICE');
        DBMS_OUTPUT.PUT_LINE('==============================================');
        DBMS_OUTPUT.PUT_LINE('Order ID : ' || p_order_id);
        DBMS_OUTPUT.PUT_LINE('Customer : ' || v_customer);
        DBMS_OUTPUT.PUT_LINE('Date     : ' || TO_CHAR(v_date, 'DD-MON-YYYY HH24:MI'));
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
        DBMS_OUTPUT.PUT_LINE(RPAD('Item',22) || LPAD('Qty',5) ||
                             LPAD('Price',10) || LPAD('Amount',12));

        FOR r IN (
            SELECT m.item_name, i.quantity, i.unit_price, i.line_total
              FROM order_items i
              JOIN menu_items m ON m.menu_item_id = i.menu_item_id
             WHERE i.order_id = p_order_id
             ORDER BY i.order_item_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(r.item_name,1,22),22) ||
                LPAD(r.quantity,5) ||
                LPAD(TO_CHAR(r.unit_price,'FM9999990.00'),10) ||
                LPAD(TO_CHAR(r.line_total,'FM9999990.00'),12)
            );
        END LOOP;

        SELECT NVL(SUM(amount),0)
          INTO v_paid
          FROM payments
         WHERE order_id = p_order_id;

        DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Subtotal : ' || TO_CHAR(v_subtotal,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('Discount : ' || TO_CHAR(v_discount,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('Tax (5%) : ' || TO_CHAR(v_tax,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('TOTAL    : ' || TO_CHAR(v_total,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('Paid     : ' || TO_CHAR(v_paid,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('Balance  : ' || TO_CHAR(v_total-v_paid,'FM9999990.00'));
        DBMS_OUTPUT.PUT_LINE('Status   : ' || v_status);
        DBMS_OUTPUT.PUT_LINE('==============================================');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20021, 'Invoice cannot be printed: order not found.');
    END print_invoice;


    PROCEDURE daily_sales_report(p_report_date IN DATE DEFAULT TRUNC(SYSDATE)) IS
        v_count NUMBER;
        v_sales NUMBER(12,2);
        v_payments NUMBER(12,2);
    BEGIN
        SELECT COUNT(*), NVL(SUM(total_amount),0)
          INTO v_count, v_sales
          FROM restaurant_orders
         WHERE order_date >= TRUNC(p_report_date)
           AND order_date < TRUNC(p_report_date) + 1
           AND order_status <> 'CANCELLED';

        SELECT NVL(SUM(p.amount),0)
          INTO v_payments
          FROM payments p
          JOIN restaurant_orders o ON o.order_id = p.order_id
         WHERE p.payment_date >= TRUNC(p_report_date)
           AND p.payment_date < TRUNC(p_report_date) + 1;

        DBMS_OUTPUT.PUT_LINE('DAILY SALES REPORT - ' ||
                             TO_CHAR(TRUNC(p_report_date),'DD-MON-YYYY'));
        DBMS_OUTPUT.PUT_LINE('Orders created : ' || v_count);
        DBMS_OUTPUT.PUT_LINE('Order value    : ' || TO_CHAR(v_sales,'FM999999990.00'));
        DBMS_OUTPUT.PUT_LINE('Payments today : ' || TO_CHAR(v_payments,'FM999999990.00'));
    END daily_sales_report;
END restaurant_pkg;
/

PROMPT === 6. SAMPLE DATA ===

INSERT INTO customers(customer_id, customer_name, phone, email)
VALUES (seq_customers.NEXTVAL, 'Aarav Sharma', '9876500001', 'aarav@example.com');

INSERT INTO customers(customer_id, customer_name, phone, email)
VALUES (seq_customers.NEXTVAL, 'Meera Kaur', '9876500002', 'meera@example.com');

INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
VALUES (seq_menu_items.NEXTVAL, 'Veg Burger', 'Fast Food', 120, 'Y');

INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
VALUES (seq_menu_items.NEXTVAL, 'Paneer Pizza', 'Pizza', 350, 'Y');

INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
VALUES (seq_menu_items.NEXTVAL, 'French Fries', 'Sides', 100, 'Y');

INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
VALUES (seq_menu_items.NEXTVAL, 'Cold Coffee', 'Beverages', 150, 'Y');

INSERT INTO menu_items(menu_item_id, item_name, category, price, is_available)
VALUES (seq_menu_items.NEXTVAL, 'Masala Dosa', 'South Indian', 180, 'Y');

COMMIT;

PROMPT === 7. VIEW THE MENU AND CUSTOMERS ===
SELECT * FROM menu_items ORDER BY menu_item_id;
SELECT * FROM customers ORDER BY customer_id;

PROMPT === 8. DEMO: CREATE ORDER, ADD ITEMS, PRINT BILL ===
DECLARE
    v_customer_id NUMBER;
    v_order_id NUMBER;
BEGIN
    SELECT customer_id INTO v_customer_id
      FROM customers WHERE phone = '9876500001';

    restaurant_pkg.create_order(v_customer_id, v_order_id);

    -- Menu item IDs in a fresh setup: 1 Burger, 2 Pizza, 3 Fries, 4 Coffee, 5 Dosa
    restaurant_pkg.add_order_item(v_order_id, 2, 3); -- 3 x Paneer Pizza = 1050
    restaurant_pkg.add_order_item(v_order_id, 1, 2); -- 2 x Veg Burger = 240
    restaurant_pkg.add_order_item(v_order_id, 3, 2); -- 2 x Fries = 200

    DBMS_OUTPUT.PUT_LINE('Created demo order ID: ' || v_order_id);
    DBMS_OUTPUT.PUT_LINE('Calculated bill: ' ||
                         TO_CHAR(restaurant_pkg.calculate_bill(v_order_id),'FM9999990.00'));
    restaurant_pkg.print_invoice(v_order_id);
END;
/

PROMPT === 9. DEMO: RECORD PAYMENT FOR MOST RECENT DEMO ORDER ===
/* Fresh setup: demo order ID starts at 1001. This pays the full bill only if
   the total is 1490.00. The demo subtotal is 1490, discount is 0, tax is 74.50,
   total is 1564.50. */
BEGIN
    restaurant_pkg.record_payment(1001, 1564.50, 'UPI', 'UPI-DEMO-001');
    restaurant_pkg.print_invoice(1001);
END;
/

PROMPT === 10. REPORT QUERIES ===

-- 10A. Orders and bills
SELECT order_id, customer_id, order_date, order_status,
       subtotal, discount_amount, tax_amount, total_amount
  FROM restaurant_orders
 ORDER BY order_id;

-- 10B. Detailed order lines
SELECT o.order_id, c.customer_name, m.item_name, i.quantity,
       i.unit_price, i.line_total
  FROM restaurant_orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN order_items i ON i.order_id = o.order_id
  JOIN menu_items m ON m.menu_item_id = i.menu_item_id
 ORDER BY o.order_id, i.order_item_id;

-- 10C. Payment history
SELECT payment_id, order_id, payment_date, amount, payment_method, reference_no
  FROM payments
 ORDER BY payment_id;

-- 10D. Popular menu items
SELECT m.item_name, SUM(i.quantity) AS units_sold,
       SUM(i.line_total) AS gross_item_sales
  FROM order_items i
  JOIN menu_items m ON m.menu_item_id = i.menu_item_id
  JOIN restaurant_orders o ON o.order_id = i.order_id
 WHERE o.order_status <> 'CANCELLED'
 GROUP BY m.item_name
 ORDER BY units_sold DESC;

-- 10E. Outstanding balances
SELECT o.order_id, c.customer_name, o.total_amount,
       NVL(p.paid_amount,0) AS paid_amount,
       o.total_amount - NVL(p.paid_amount,0) AS balance
  FROM restaurant_orders o
  JOIN customers c ON c.customer_id = o.customer_id
  LEFT JOIN (
      SELECT order_id, SUM(amount) paid_amount
        FROM payments GROUP BY order_id
  ) p ON p.order_id = o.order_id
 WHERE o.order_status IN ('OPEN','PARTIALLY_PAID')
 ORDER BY o.order_id;

-- 10F. Daily report output
BEGIN
    restaurant_pkg.daily_sales_report(TRUNC(SYSDATE));
END;
/

COMMIT;

PROMPT === PROJECT SETUP FINISHED ===
PROMPT If you want to run the main demo again, create a new order using the package.
PROMPT To inspect compilation issues, run: SELECT name, type, line, text FROM user_errors ORDER BY name, sequence;

/*
RESET (OPTIONAL - DESTRUCTIVE):
Run these statements manually in reverse dependency order only if you want to
remove this project and start again. They permanently drop the project objects.

DROP PACKAGE restaurant_pkg;
DROP TRIGGER trg_payment_validate;
DROP TRIGGER trg_order_item_price;
DROP TABLE payments CASCADE CONSTRAINTS PURGE;
DROP TABLE order_items CASCADE CONSTRAINTS PURGE;
DROP TABLE restaurant_orders CASCADE CONSTRAINTS PURGE;
DROP TABLE menu_items CASCADE CONSTRAINTS PURGE;
DROP TABLE customers CASCADE CONSTRAINTS PURGE;
DROP SEQUENCE seq_payments;
DROP SEQUENCE seq_order_items;
DROP SEQUENCE seq_orders;
DROP SEQUENCE seq_menu_items;
DROP SEQUENCE seq_customers;
*/
