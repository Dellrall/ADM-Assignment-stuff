-- =============================================================================
-- MODULE 3: ORDER, PAYMENT & FULFILLMENT MANAGEMENT
-- BMCS3183 Advanced Database Management | 88 Speedmart System
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- -----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES, VIEWS, CUSTOM EXCEPTIONS)
-- -----------------------------------------------------------------------------


-- Drop existing sequences & indexes for clean re-execution
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_order_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_payment_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_order_date_status';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_payment_method_stat';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. Sequences for Order Processing and Billing
CREATE SEQUENCE seq_order_id
    START WITH 600
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_payment_id
    START WITH 800
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes
CREATE INDEX idx_order_date_status ON CustomerOrder (OrderDate, OrderStatus, BranchID);
CREATE INDEX idx_payment_method_stat ON Payment (PaymentMethod, PaymentStatus, OrderID);

-- 3. View 1: Omnichannel Order Fulfillment Master (Strategic View)
CREATE OR REPLACE VIEW v_order_fulfillment_summary AS
SELECT 
    o.OrderID,
    o.OrderDate,
    o.OrderStatus,
    m.MemberID,
    m.Name AS CustomerName,
    b.BranchID,
    b.BranchName,
    CASE 
        WHEN d.DeliveryID IS NOT NULL THEN 'Delivery'
        WHEN pk.PickupID IS NOT NULL THEN 'In-Store Pickup'
        ELSE 'Walk-In / Unknown'
    END AS FulfillmentType,
    ds.CompanyName AS CourierPartner,
    d.TrackingNumber,
    pk.PickupCode,
    NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) + NVL(ds.DeliveryCharge, 0) AS OrderGrandTotal,
    p.PaymentMethod,
    p.PaymentStatus
FROM CustomerOrder o
JOIN Member m ON o.MemberID = m.MemberID
JOIN Branch b ON o.BranchID = b.BranchID
LEFT JOIN OrderDetail od ON o.OrderID = od.OrderID
LEFT JOIN Delivery d ON o.OrderID = d.OrderID
LEFT JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
LEFT JOIN Pickup pk ON o.OrderID = pk.OrderID
LEFT JOIN Payment p ON o.OrderID = p.OrderID
GROUP BY 
    o.OrderID, o.OrderDate, o.OrderStatus, m.MemberID, m.Name, 
    b.BranchID, b.BranchName, d.DeliveryID, pk.PickupID, ds.CompanyName, 
    d.TrackingNumber, pk.PickupCode, ds.DeliveryCharge, p.PaymentMethod, p.PaymentStatus;

-- 4. View 2: Third-Party Courier Performance & Revenue (Tactical View)
CREATE OR REPLACE VIEW v_courier_delivery_efficiency AS
SELECT 
    ds.DeliveryServiceID,
    ds.CompanyName,
    ds.CompanyStatus,
    ds.DeliveryCharge AS BaseRate,
    COUNT(d.DeliveryID) AS TotalDispatches,
    SUM(CASE WHEN d.DeliveryStatus = 'Delivered' THEN 1 ELSE 0 END) AS SuccessfulDeliveries,
    SUM(CASE WHEN d.DeliveryStatus = 'In Transit' THEN 1 ELSE 0 END) AS ActiveDeliveries,
    SUM(CASE WHEN d.DeliveryStatus = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledDeliveries,
    NVL(SUM(ds.DeliveryCharge), 0) AS CumulativeFreightRevenue
FROM DeliveryService ds
LEFT JOIN Delivery d ON ds.DeliveryServiceID = d.DeliveryServiceID
GROUP BY ds.DeliveryServiceID, ds.CompanyName, ds.CompanyStatus, ds.DeliveryCharge;

-- -----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL & OPERATIONAL QUERIES (2 QUERIES)
-- -----------------------------------------------------------------------------

-- Query 1 (Strategic): Omnichannel Sales Distribution & Revenue by Fulfillment Method
-- Analyzes sales split between Pickup and Delivery per retail branch.
SELECT 
    b.BranchID,
    RPAD(b.BranchName, 22) AS "Branch Location",
    COUNT(DISTINCT o.OrderID) AS "Total Orders",
    COUNT(DISTINCT CASE WHEN d.DeliveryID IS NOT NULL THEN o.OrderID END) AS "Delivery Orders",
    COUNT(DISTINCT CASE WHEN pk.PickupID IS NOT NULL THEN o.OrderID END) AS "Pickup Orders",
    TO_CHAR(NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0), 'FM99,990.00') AS "Net Sales Revenue",
    TO_CHAR(NVL(AVG(od.Quantity * (od.UnitPrice - od.Discount)), 0), 'FM90.00') AS "Avg Line Value"
FROM Branch b
JOIN CustomerOrder o ON b.BranchID = o.BranchID
LEFT JOIN OrderDetail od ON o.OrderID = od.OrderID
LEFT JOIN Delivery d ON o.OrderID = d.OrderID
LEFT JOIN Pickup pk ON o.OrderID = pk.OrderID
WHERE o.OrderStatus = 'Completed'
GROUP BY b.BranchID, b.BranchName
ORDER BY SUM(od.Quantity * (od.UnitPrice - od.Discount)) DESC;

-- Query 2 (Tactical): Courier Partner SLA & Delivery Success Rate Analysis
-- Evaluates logistics partner reliability and pending delivery backlogs.
SELECT 
    ds.DeliveryServiceID AS "Courier ID",
    RPAD(ds.CompanyName, 24) AS "Courier Name",
    ds.TotalDispatches AS "Total Handled",
    ds.SuccessfulDeliveries AS "Completed",
    ds.ActiveDeliveries AS "In-Transit Backlog",
    ROUND((ds.SuccessfulDeliveries / NULLIF(ds.TotalDispatches, 0)) * 100, 2) || '%' AS "Success Rate",
    TO_CHAR(ds.CumulativeFreightRevenue, 'FM99,990.00') AS "Total Freight (MYR)"
FROM v_courier_delivery_efficiency ds
WHERE ds.TotalDispatches > 0
ORDER BY ds.TotalDispatches DESC;

-- -----------------------------------------------------------------------------
-- TASK 5: STORED PROCEDURES WITH EXCEPTION HANDLING (2 PROCEDURES)
-- -----------------------------------------------------------------------------

-- Procedure 1: Create In-Store Pickup Order with Unique Pickup Code
-- Enforces customer active validation, generates 6-digit pickup code, and records order.
CREATE OR REPLACE PROCEDURE sp_create_pickup_order (
    p_member_id   IN  Member.MemberID%TYPE,
    p_branch_id   IN  Branch.BranchID%TYPE,
    p_new_order_id OUT CustomerOrder.OrderID%TYPE,
    p_pickup_code OUT Pickup.PickupCode%TYPE
) AS
    -- Custom Exceptions
    e_inactive_customer EXCEPTION;
    e_inactive_branch   EXCEPTION;

    v_mem_status Member.MemberStatus%TYPE;
    v_br_status  Branch.BranchStatus%TYPE;
    v_br_addr    Branch.Address%TYPE;
    v_pickup_id  NUMBER;
BEGIN
    -- 1. Validate Member
    SELECT MemberStatus INTO v_mem_status FROM Member WHERE MemberID = p_member_id;
    IF v_mem_status <> 'Active' THEN
        RAISE e_inactive_customer;
    END IF;

    -- 2. Validate Branch
    SELECT BranchStatus, Address INTO v_br_status, v_br_addr FROM Branch WHERE BranchID = p_branch_id;
    IF v_br_status <> 'Active' THEN
        RAISE e_inactive_branch;
    END IF;

    -- 3. Create Order
    p_new_order_id := seq_order_id.NEXTVAL;

    INSERT INTO CustomerOrder (
        OrderID, OrderDate, OrderTime, OrderStatus, MemberID, BranchID
    ) VALUES (
        p_new_order_id, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), 'Pending', p_member_id, p_branch_id
    );

    -- 4. Generate 6-Digit Pickup Code and Create Pickup Record
    p_pickup_code := LPAD(TRUNC(DBMS_RANDOM.VALUE(100000, 999999)), 6, '0');
    SELECT NVL(MAX(PickupID), 0) + 1 INTO v_pickup_id FROM Pickup;

    INSERT INTO Pickup (
        PickupID, PickupDate, PickupTime, PickupCode, PickupAddress, PickupStatus, Remarks, OrderID
    ) VALUES (
        v_pickup_id, SYSDATE + 1, '18:00:00', p_pickup_code, v_br_addr, 'Pending',
        'Self collection at branch counter', p_new_order_id
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: Order #' || p_new_order_id || ' booked. Pickup Code: ' || p_pickup_code);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20201, 'Lookup Error: Member #' || p_member_id || ' or Branch #' || p_branch_id || ' does not exist.');
    WHEN e_inactive_customer THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20202, 'Eligibility Error: Inactive members cannot place new pickup orders.');
    WHEN e_inactive_branch THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20203, 'Branch Error: Selected branch is inactive.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20200, 'System Error in sp_create_pickup_order: ' || SQLERRM);
END sp_create_pickup_order;
/

-- Procedure 2: Settle Order Payment & Award Loyalty Points
-- Settles payment, updates Order status to Completed, and calculates + awards points.
CREATE OR REPLACE PROCEDURE sp_settle_order_payment (
    p_order_id       IN CustomerOrder.OrderID%TYPE,
    p_payment_method IN Payment.PaymentMethod%TYPE,
    p_amount_paid    IN Payment.AmountPaid%TYPE,
    p_transaction_no IN Payment.TransactionNo%TYPE
) AS
    -- PRAGMA Exception for Unique Key violation (-1)
    e_duplicate_transaction EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_duplicate_transaction, -1);

    -- Custom Exceptions
    e_order_not_pending EXCEPTION;
    e_invalid_amount    EXCEPTION;
    e_invalid_method    EXCEPTION;

    v_order_status CustomerOrder.OrderStatus%TYPE;
    v_member_id    CustomerOrder.MemberID%TYPE;
    v_payment_id   NUMBER;
    v_pts_earned   NUMBER;
BEGIN
    -- 1. Validate Payment Method
    IF p_payment_method NOT IN ('Cash', 'Card', 'E-Wallet', 'Online Banking') THEN
        RAISE e_invalid_method;
    END IF;

    IF p_amount_paid <= 0 THEN
        RAISE e_invalid_amount;
    END IF;

    -- 2. Validate Order Status
    SELECT OrderStatus, MemberID INTO v_order_status, v_member_id
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_order_status <> 'Pending' THEN
        RAISE e_order_not_pending;
    END IF;

    -- 3. Record Payment
    p_payment_id := seq_payment_id.NEXTVAL;

    INSERT INTO Payment (
        PaymentID, PaymentMethod, PaymentDate, AmountPaid,
        TransactionNo, PaymentStatus, OrderID
    ) VALUES (
        p_payment_id, p_payment_method, SYSDATE, p_amount_paid,
        p_transaction_no, 'Paid', p_order_id
    );

    -- 4. Mark Order as Completed
    UPDATE CustomerOrder
    SET OrderStatus = 'Completed'
    WHERE OrderID = p_order_id;

    -- 5. Award 1 Loyalty Point per RM 1.00 spent (Rule 8)
    v_pts_earned := TRUNC(p_amount_paid);
    UPDATE Member
    SET MemberPoint = MemberPoint + v_pts_earned
    WHERE MemberID = v_member_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Payment settled for Order #' || p_order_id || '. ' || v_pts_earned || ' points awarded to Member #' || v_member_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20204, 'Lookup Error: Order #' || p_order_id || ' does not exist.');
    WHEN e_order_not_pending THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20205, 'State Error: Order is not in Pending status.');
    WHEN e_invalid_amount THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20206, 'Validation Error: Payment amount must be greater than zero.');
    WHEN e_invalid_method THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20207, 'Validation Error: Invalid payment channel.');
    WHEN e_duplicate_transaction THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20208, 'Integrity Error: Duplicate Transaction Number provided.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20200, 'System Error in sp_settle_order_payment: ' || SQLERRM);
END sp_settle_order_payment;
/

-- -----------------------------------------------------------------------------
-- TASK 6: CONDITIONAL TRIGGERS (2 TRIGGERS)
-- -----------------------------------------------------------------------------

-- Trigger 1: Enforce Mutual Exclusivity between Delivery and Pickup (Rule & Assumption 2)
CREATE OR REPLACE TRIGGER trg_guard_exclusive_delivery
BEFORE INSERT ON Delivery
FOR EACH ROW
DECLARE
    v_pickup_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_pickup_count
    FROM Pickup
    WHERE OrderID = :NEW.OrderID;

    IF v_pickup_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20210, 'Trigger Violation: Order #' || :NEW.OrderID || ' is already assigned for In-Store Pickup. Cannot assign Delivery.');
    END IF;
END trg_guard_exclusive_delivery;
/

-- Trigger 2: Prevent Reverting Paid Payments back to Pending
CREATE OR REPLACE TRIGGER trg_guard_paid_payment_state
BEFORE UPDATE OF PaymentStatus ON Payment
FOR EACH ROW
WHEN (OLD.PaymentStatus = 'Paid' AND NEW.PaymentStatus = 'Pending')
BEGIN
    RAISE_APPLICATION_ERROR(-20211, 'Trigger Violation: Settled payment (Paid) cannot be reverted back to Pending.');
END trg_guard_paid_payment_state;
/

-- -----------------------------------------------------------------------------
-- TASK 7: REPORTS GENERATION WITH NESTED CURSORS (2 REPORTS)
-- -----------------------------------------------------------------------------

-- Report 1: Official Order Tax Invoice & Receipt (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_order_tax_invoice (
    p_order_id IN CustomerOrder.OrderID%TYPE
) AS
    -- Parent Cursor: Order, Customer, Branch & Fulfillment Header
    CURSOR c_order_hdr IS
        SELECT 
            o.OrderID, o.OrderDate, o.OrderStatus,
            m.MemberID, m.Name AS CustomerName, m.PhoneNo, m.MembershipType,
            b.BranchName, b.Address AS BranchAddress,
            p.PaymentMethod, p.AmountPaid, p.TransactionNo,
            pk.PickupCode, d.TrackingNumber, ds.CompanyName AS CourierName
        FROM CustomerOrder o
        JOIN Member m ON o.MemberID = m.MemberID
        JOIN Branch b ON o.BranchID = b.BranchID
        LEFT JOIN Payment p ON o.OrderID = p.OrderID
        LEFT JOIN Pickup pk ON o.OrderID = pk.OrderID
        LEFT JOIN Delivery d ON o.OrderID = d.OrderID
        LEFT JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
        WHERE o.OrderID = p_order_id;

    -- Child Cursor: Order Line Items
    CURSOR c_items (cp_order_id NUMBER) IS
        SELECT od.ItemID, i.ItemName, od.Quantity, od.UnitPrice, od.Discount,
               (od.Quantity * (od.UnitPrice - od.Discount)) AS LineSubtotal
        FROM OrderDetail od
        JOIN Item i ON od.ItemID = i.ItemID
        WHERE od.OrderID = cp_order_id;

    r_hdr c_order_hdr%ROWTYPE;
    v_subtotal NUMBER := 0;
    v_total_discount NUMBER := 0;
    v_item_count NUMBER := 0;
BEGIN
    OPEN c_order_hdr;
    FETCH c_order_hdr INTO r_hdr;
    IF c_order_hdr%NOTFOUND THEN
        CLOSE c_order_hdr;
        DBMS_OUTPUT.PUT_LINE('Error: Order ID #' || p_order_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_order_hdr;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                           88 SPEEDMART OFFICIAL TAX INVOICE                            ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Invoice Ref : #' || RPAD(r_hdr.OrderID, 12) || 'Date        : ' || TO_CHAR(r_hdr.OrderDate, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Branch      : ' || RPAD(r_hdr.BranchName, 26) || 'Status      : ' || r_hdr.OrderStatus);
    DBMS_OUTPUT.PUT_LINE('Customer    : ' || RPAD(r_hdr.CustomerName || ' (' || r_hdr.MembershipType || ')', 26) || 'Phone       : ' || r_hdr.PhoneNo);
    
    IF r_hdr.PickupCode IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Fulfillment : IN-STORE PICKUP (Claim Code: ' || r_hdr.PickupCode || ')');
    ELSIF r_hdr.TrackingNumber IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Fulfillment : DELIVERY by ' || r_hdr.CourierName || ' (Tracking: ' || r_hdr.TrackingNumber || ')');
    END IF;
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('Item ID', 9) || RPAD('Description', 28) || LPAD('Unit Price', 12) || LPAD('Disc', 10) || LPAD('Qty', 8) || LPAD('Total (MYR)', 16));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    -- Iterate Child Cursor
    FOR r_it IN c_items(r_hdr.OrderID) LOOP
        v_item_count := v_item_count + 1;
        v_subtotal := v_subtotal + (r_it.Quantity * r_it.UnitPrice);
        v_total_discount := v_total_discount + (r_it.Quantity * r_it.Discount);

        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_it.ItemID, 9) ||
            RPAD(SUBSTR(r_it.ItemName, 1, 26), 28) ||
            LPAD(TO_CHAR(r_it.UnitPrice, 'FM990.00'), 12) ||
            LPAD(TO_CHAR(r_it.Discount, 'FM990.00'), 10) ||
            LPAD(r_it.Quantity, 8) ||
            LPAD(TO_CHAR(r_it.LineSubtotal, 'FM999,990.00'), 16)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(LPAD('Gross Subtotal : MYR ', 65) || LPAD(TO_CHAR(v_subtotal, 'FM999,990.00'), 18));
    DBMS_OUTPUT.PUT_LINE(LPAD('Total Savings  : MYR ', 65) || LPAD(TO_CHAR(-v_total_discount, 'FM999,990.00'), 18));
    DBMS_OUTPUT.PUT_LINE(LPAD('NET AMOUNT PAID: MYR ', 65) || LPAD(TO_CHAR(NVL(r_hdr.AmountPaid, (v_subtotal - v_total_discount)), 'FM999,990.00'), 18));
    DBMS_OUTPUT.PUT_LINE('Payment Method : ' || NVL(r_hdr.PaymentMethod, 'Pending') || ' | Ref: ' || NVL(r_hdr.TransactionNo, 'N/A'));
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_order_tax_invoice;
/

-- Report 2: Branch Daily Fulfillment Dispatch Manifest (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_branch_daily_manifest (
    p_branch_id IN Branch.BranchID%TYPE
) AS
    -- Parent Cursor: Branch Details
    CURSOR c_branch IS
        SELECT BranchID, BranchName, City, State FROM Branch WHERE BranchID = p_branch_id;

    -- Child Cursor 1: Pending & Ready Pickup Orders
    CURSOR c_pickups (cp_branch_id NUMBER) IS
        SELECT o.OrderID, m.Name AS CustomerName, m.PhoneNo, pk.PickupCode, pk.PickupStatus
        FROM CustomerOrder o
        JOIN Member m ON o.MemberID = m.MemberID
        JOIN Pickup pk ON o.OrderID = pk.OrderID
        WHERE o.BranchID = cp_branch_id
        ORDER BY o.OrderID DESC;

    -- Child Cursor 2: Active Deliveries
    CURSOR c_deliveries (cp_branch_id NUMBER) IS
        SELECT o.OrderID, m.Name AS CustomerName, ds.CompanyName, d.TrackingNumber, d.DeliveryStatus
        FROM CustomerOrder o
        JOIN Member m ON o.MemberID = m.MemberID
        JOIN Delivery d ON o.OrderID = d.OrderID
        JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
        WHERE o.BranchID = cp_branch_id
        ORDER BY o.OrderID DESC;

    r_br c_branch%ROWTYPE;
BEGIN
    OPEN c_branch;
    FETCH c_branch INTO r_br;
    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID #' || p_branch_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_branch;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                  88 SPEEDMART DAILY STORE DISPATCH & PICKUP MANIFEST                   ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Branch: #' || r_br.BranchID || ' - ' || r_br.BranchName || ' (' || r_br.City || ', ' || r_br.State || ')');
    DBMS_OUTPUT.PUT_LINE('Date  : ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('IN-STORE PICKUP QUEUE:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Order ID', 12) || RPAD('Customer Name', 24) || RPAD('Phone', 16) || RPAD('Pickup Code', 14) || RPAD('Status', 12));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_pk IN c_pickups(r_br.BranchID) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_pk.OrderID, 12) ||
            RPAD(SUBSTR(r_pk.CustomerName, 1, 22), 24) ||
            RPAD(r_pk.PhoneNo, 16) ||
            RPAD(r_pk.PickupCode, 14) ||
            RPAD(r_pk.PickupStatus, 12)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('OUTBOUND COURIER DELIVERIES:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Order ID', 12) || RPAD('Customer Name', 24) || RPAD('Courier', 18) || RPAD('Tracking #', 16) || RPAD('Status', 12));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_dl IN c_deliveries(r_br.BranchID) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_dl.OrderID, 12) ||
            RPAD(SUBSTR(r_dl.CustomerName, 1, 22), 24) ||
            RPAD(SUBSTR(r_dl.CompanyName, 1, 16), 18) ||
            RPAD(r_dl.TrackingNumber, 16) ||
            RPAD(r_dl.DeliveryStatus, 12)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_branch_daily_manifest;
/
