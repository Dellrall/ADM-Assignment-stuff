-- ============================================================================
-- MODULE 3: ORDER, PAYMENT & FULFILLMENT MANAGEMENT
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 3
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 3: ORDER, PAYMENT & FULFILLMENT - MANAGEMENT REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_order_tax_invoice
-- CLASSIFICATION: On-Demand Customer Tax Invoice
-- COMPLEXITY: Parameterized Nested Cursors (Order Header -> Line Items)
-- SCENARIO: Generates an official, enterprise-formatted Tax Invoice / Receipt
--   displaying line items, discounts absorbed, logistics fees, and points awarded.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_order_tax_invoice (
    p_order_id IN NUMBER
) AS
    -- 1. Parent Cursor: Order, Customer, Fulfillment and Settlement Details
    CURSOR c_order IS
        SELECT 
            co.OrderID,
            co.OrderDate,
            co.OrderStatus,
            m.MemberID,
            m.Name AS CustomerName,
            m.Email,
            m.PhoneNo,
            m.MembershipType,
            b.BranchName,
            p.PaymentMethod,
            p.AmountPaid,
            p.TransactionNo,
            p.PaymentStatus,
            pk.PickupCode,
            d.TrackingNumber,
            ds.CompanyName AS CourierName,
            ds.DeliveryCharge
        FROM CustomerOrder co
        JOIN Member m ON co.MemberID = m.MemberID
        JOIN Branch b ON co.BranchID = b.BranchID
        LEFT JOIN Payment p ON co.OrderID = p.OrderID
        LEFT JOIN Pickup pk ON co.OrderID = pk.OrderID
        LEFT JOIN Delivery d ON co.OrderID = d.OrderID
        LEFT JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
        WHERE co.OrderID = p_order_id;

    -- 2. Parameterized Child Cursor: Itemized Lines
    CURSOR c_lines(p_oid NUMBER) IS
        SELECT 
            od.ItemID,
            i.ItemName,
            i.Brand,
            od.Quantity,
            od.UnitPrice,
            od.Discount,
            (od.Quantity * (od.UnitPrice - od.Discount)) AS NetLineTotal,
            od.LineStatus
        FROM OrderDetail od
        JOIN Item i ON od.ItemID = i.ItemID
        WHERE od.OrderID = p_oid;

    v_ord c_order%ROWTYPE;
    v_item_subtotal NUMBER := 0;
    v_discount_total NUMBER := 0;
    v_freight NUMBER := 0;
    v_grand_total NUMBER := 0;
    v_item_count NUMBER := 0;
BEGIN
    OPEN c_order;
    FETCH c_order INTO v_ord;

    IF c_order%NOTFOUND THEN
        CLOSE c_order;
        DBMS_OUTPUT.PUT_LINE('Error: Order ID #' || p_order_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_order;

    -- Print Invoice Header
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE('                    88 SPEEDMART - OFFICIAL TAX INVOICE');
    DBMS_OUTPUT.PUT_LINE('                             TRN: W10-2026-88888888');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE(' Invoice No    : INV-' || LPAD(v_ord.OrderID, 8, '0') || 
                         '   Date/Time   : ' || TO_CHAR(v_ord.OrderDate, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE(' Customer Name : ' || RPAD(v_ord.CustomerName || ' (#' || v_ord.MemberID || ')', 35) || 
                         '   Tier        : ' || v_ord.MembershipType);
    DBMS_OUTPUT.PUT_LINE(' Retail Outlet : ' || RPAD(v_ord.BranchName, 35) || 
                         '   Order Status: ' || v_ord.OrderStatus);
    
    -- Fulfillment Channel Display
    IF v_ord.PickupCode IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE(' Fulfillment   : IN-STORE PICKUP [Code: ' || v_ord.PickupCode || ']');
    ELSIF v_ord.TrackingNumber IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE(' Fulfillment   : COURIER DELIVERY [' || v_ord.CourierName || ' | Trk: ' || v_ord.TrackingNumber || ']');
    ELSE
        DBMS_OUTPUT.PUT_LINE(' Fulfillment   : DIRECT COUNTER PURCHASE');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Item Description', 30) || 
        LPAD('Qty', 6) || 
        LPAD('Unit(RM)', 14) || 
        LPAD('Disc(RM)', 14) || 
        LPAD('Net Total(RM)', 18) || 
        RPAD('   Status', 13)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));

    FOR line IN c_lines(v_ord.OrderID) LOOP
        v_item_count := v_item_count + 1;
        v_item_subtotal := v_item_subtotal + (line.Quantity * line.UnitPrice);
        v_discount_total := v_discount_total + (line.Quantity * line.Discount);
        v_grand_total := v_grand_total + line.NetLineTotal;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(SUBSTR(line.ItemName, 1, 28), 30) || 
            LPAD(line.Quantity, 6) || 
            LPAD(TO_CHAR(line.UnitPrice, 'FM990.00'), 14) || 
            LPAD(TO_CHAR(line.Discount, 'FM990.00'), 14) || 
            LPAD(TO_CHAR(line.NetLineTotal, 'FM999,990.00'), 18) || 
            '   ' || RPAD(line.LineStatus, 10)
        );
    END LOOP;

    IF v_item_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No itemized lines attached to this order.');
    END IF;

    v_freight := NVL(v_ord.DeliveryCharge, 0);
    v_grand_total := v_grand_total + v_freight;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(LPAD('Gross Items Subtotal : RM ', 75) || LPAD(TO_CHAR(v_item_subtotal, 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(LPAD('Promotional Discounts: -RM ', 75) || LPAD(TO_CHAR(v_discount_total, 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(LPAD('Delivery Freight Fee : RM ', 75) || LPAD(TO_CHAR(v_freight, 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(LPAD('NET GRAND TOTAL      : RM ', 75) || LPAD(TO_CHAR(v_grand_total, 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE(' Settlement Mode: ' || RPAD(NVL(v_ord.PaymentMethod, 'UNPAID'), 18) || 
                         ' Txn Ref: ' || RPAD(NVL(v_ord.TransactionNo, 'N/A'), 28) || 
                         ' Payment State: ' || NVL(v_ord.PaymentStatus, 'Pending'));
    DBMS_OUTPUT.PUT_LINE(' Loyalty Points Earned: ' || TRUNC(v_grand_total) || ' pts (Rate: RM 1.00 = 1 Point)');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_order_tax_invoice;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_branch_daily_manifest
-- CLASSIFICATION: Daily Operational Dispatch & Pickup Manifest
-- COMPLEXITY: Parameterized Nested Cursors (Branch -> Pickup Queue -> Courier Dispatches)
-- SCENARIO: Store managers print this manifest each morning to coordinate 
--   in-store customer collection desks and courier outbound parcel handoffs.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_branch_daily_manifest (
    p_branch_id   IN NUMBER,
    p_target_date IN DATE DEFAULT SYSDATE
) AS
    -- 1. Parent Cursor: Branch Information
    CURSOR c_branch IS
        SELECT BranchID, BranchName, Address, City, State, BranchPhoneNo
        FROM Branch
        WHERE BranchID = p_branch_id;

    -- 2. Parameterized Child Cursor 1: In-Store Pickup Claims
    CURSOR c_pickups(p_bid NUMBER, p_dt DATE) IS
        SELECT 
            co.OrderID,
            pk.PickupID,
            pk.PickupCode,
            m.Name AS CustomerName,
            m.PhoneNo,
            pk.PickupStatus,
            NVL(p.AmountPaid, 0) AS AmountPaid
        FROM CustomerOrder co
        JOIN Pickup pk ON co.OrderID = pk.OrderID
        JOIN Member m ON co.MemberID = m.MemberID
        LEFT JOIN Payment p ON co.OrderID = p.OrderID
        WHERE co.BranchID = p_bid
        ORDER BY co.OrderID ASC;

    -- 3. Parameterized Child Cursor 2: Courier Deliveries
    CURSOR c_deliveries(p_bid NUMBER, p_dt DATE) IS
        SELECT 
            co.OrderID,
            d.DeliveryID,
            ds.CompanyName AS CourierPartner,
            d.TrackingNumber,
            m.Name AS CustomerName,
            m.DeliveryAddress,
            d.DeliveryStatus
        FROM CustomerOrder co
        JOIN Delivery d ON co.OrderID = d.OrderID
        JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
        JOIN Member m ON co.MemberID = m.MemberID
        WHERE co.BranchID = p_bid
        ORDER BY ds.CompanyName, co.OrderID;

    v_br c_branch%ROWTYPE;
    v_pickup_count NUMBER := 0;
    v_delivery_count NUMBER := 0;
BEGIN
    OPEN c_branch;
    FETCH c_branch INTO v_br;

    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID #' || p_branch_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_branch;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('                 88 SPEEDMART - DAILY OUTBOUND DISPATCH & PICKUP MANIFEST');
    DBMS_OUTPUT.PUT_LINE('                             Target Manifest Date: ' || TO_CHAR(p_target_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Branch Outlet : [' || v_br.BranchID || '] ' || v_br.BranchName);
    DBMS_OUTPUT.PUT_LINE(' Address       : ' || v_br.Address || ', ' || v_br.City);
    DBMS_OUTPUT.PUT_LINE(' Contact Phone : ' || NVL(v_br.BranchPhoneNo, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    -- Child Section 1: In-Store Pickups
    DBMS_OUTPUT.PUT_LINE(' SECTION 1: IN-STORE SELF-PICKUP COLLECTION QUEUE');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Order ID', 10) || 
        RPAD('Claim Code', 14) || 
        RPAD('Customer Name', 30) || 
        RPAD('Contact No', 16) || 
        RPAD('Paid(RM)', 15) || 
        RPAD('Pickup Status', 16)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR pk IN c_pickups(v_br.BranchID, p_target_date) LOOP
        v_pickup_count := v_pickup_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(pk.OrderID, 10) || 
            RPAD(NVL(pk.PickupCode, 'PENDING'), 14) || 
            RPAD(SUBSTR(pk.CustomerName, 1, 28), 30) || 
            RPAD(NVL(pk.PhoneNo, 'N/A'), 16) || 
            RPAD('RM ' || TO_CHAR(pk.AmountPaid, 'FM990.00'), 15) || 
            RPAD(pk.PickupStatus, 16)
        );
    END LOOP;

    IF v_pickup_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No pickup orders scheduled for this branch today.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(' Total Self-Pickup Orders: ' || v_pickup_count);
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));

    -- Child Section 2: Outbound Courier Dispatches
    DBMS_OUTPUT.PUT_LINE(' SECTION 2: 3PL OUTBOUND COURIER DISPATCH MANIFEST');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Order ID', 10) || 
        RPAD('Courier Partner', 22) || 
        RPAD('Tracking Number', 20) || 
        RPAD('Customer Name', 24) || 
        RPAD('Delivery Status', 18)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR dl IN c_deliveries(v_br.BranchID, p_target_date) LOOP
        v_delivery_count := v_delivery_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(dl.OrderID, 10) || 
            RPAD(SUBSTR(dl.CourierPartner, 1, 20), 22) || 
            RPAD(NVL(dl.TrackingNumber, 'PENDING'), 20) || 
            RPAD(SUBSTR(dl.CustomerName, 1, 22), 24) || 
            RPAD(dl.DeliveryStatus, 18)
        );
    END LOOP;

    IF v_delivery_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No courier dispatches scheduled for this branch today.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(' Total Courier Dispatches: ' || v_delivery_count);
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' [END OF DAILY FULFILLMENT MANIFEST]');
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_branch_daily_manifest;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_order_tax_invoice (Order ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_order_tax_invoice(1);

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_branch_daily_manifest (Branch ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_branch_daily_manifest(1);
