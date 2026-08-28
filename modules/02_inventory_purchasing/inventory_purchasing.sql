-- =============================================================================
-- MODULE 2: INVENTORY and PURCHASING MANAGEMENT
-- BMCS3183 Advanced Database Management | 88 Speedmart System
-- =============================================================================

SET LINESIZE 200;
SET PAGESIZE 50;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;

-- -----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES, VIEWS, CUSTOM EXCEPTIONS)
-- -----------------------------------------------------------------------------


-- Drop existing sequences and indexes for clean re-execution
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_po_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_stock_log_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_stock_branch_reorder';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_batch_item_expiry';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. Sequences for Purchasing and Auditing
CREATE SEQUENCE seq_po_id
    START WITH 500
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_stock_log_id
    START WITH 2000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes
CREATE INDEX idx_stock_branch_reorder ON Stock (BranchID, Quantity, ReorderLevel);
CREATE INDEX idx_batch_item_expiry ON StockBatch (ItemID, ExpiryDate, BranchID);

-- 3. View 1: Branch Inventory Health and Valuation (Strategic View)
CREATE OR REPLACE VIEW v_branch_inventory_health AS
SELECT 
    b.BranchID,
    b.BranchName,
    b.State,
    COUNT(s.ItemID) AS TotalTrackedItems,
    SUM(s.Quantity) AS TotalStockUnits,
    SUM(s.Quantity * i.Price) AS TotalInventoryValue,
    SUM(CASE WHEN s.Quantity <= s.ReorderLevel THEN 1 ELSE 0 END) AS LowStockItemCount,
    MAX(s.LastUpdated) AS LastStockAuditDate
FROM Branch b
JOIN Stock s ON b.BranchID = s.BranchID
JOIN Item i ON s.ItemID = i.ItemID
GROUP BY b.BranchID, b.BranchName, b.State;

-- 4. View 2: Supplier Procurement and Fulfillment Performance (Tactical View)
CREATE OR REPLACE VIEW v_supplier_procurement_summary AS
SELECT 
    sup.SupplierID,
    sup.CompanyName,
    sup.SupplierStatus,
    COUNT(DISTINCT po.PurchaseOrderID) AS TotalOrdersPlaced,
    SUM(CASE WHEN po.Status = 'Received' THEN 1 ELSE 0 END) AS OrdersCompleted,
    SUM(CASE WHEN po.Status = 'Pending' THEN 1 ELSE 0 END) AS OrdersPending,
    NVL(SUM(poi.Quantity * poi.CostPrice), 0) AS TotalProcurementSpend
FROM Supplier sup
LEFT JOIN PurchaseOrder po ON sup.SupplierID = po.SupplierID
LEFT JOIN PurchaseOrderItem poi ON po.PurchaseOrderID = poi.PurchaseOrderID
GROUP BY sup.SupplierID, sup.CompanyName, sup.SupplierStatus;

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL and OPERATIONAL QUERIES (2 QUERIES)
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- SQL*PLUS TERMINAL and COLUMN FORMATTING (COMPACT HALF-SCREEN ALIGNMENT)
-- -----------------------------------------------------------------------------
SET LINESIZE 120;
SET PAGESIZE 100;
SET FEEDBACK OFF;
SET RECSEP OFF;
SET DEFINE OFF;

-- Formatting for Query 1
COLUMN BranchID                FORMAT 9999       HEADING "Br";
COLUMN "Branch Name"           FORMAT A18        HEADING "Branch Location";
COLUMN ItemID                  FORMAT 9999       HEADING "Item";
COLUMN "Item Description"      FORMAT A18        HEADING "Product";
COLUMN "Current Stock"         FORMAT 99999      HEADING "Stock";
COLUMN "Reorder Threshold"     FORMAT 9999       HEADING "Min";
COLUMN "Capacity Limit"        FORMAT 9999       HEADING "Max";
COLUMN "Order Qty"             FORMAT 9999       HEADING "Need";
COLUMN "Est Cost (MYR)"        FORMAT A14        HEADING "Est Cost (MYR)";

-- Formatting for Query 1 Summary
COLUMN "Branches in Deficit"   FORMAT 999999     HEADING "Branches";
COLUMN "Deficient SKU Lines"   FORMAT 999999     HEADING "SKU Lines";
COLUMN "Total Units Needed"    FORMAT 999999     HEADING "Units Need";
COLUMN "Total Restock Budget"  FORMAT A16        HEADING "Total Budget";

-- Formatting for Query 2
COLUMN BatchID                 FORMAT 999999     HEADING "Batch";
COLUMN "Item Name"             FORMAT A18        HEADING "Product Name";
COLUMN "Warehouse Branch"      FORMAT A16        HEADING "Branch";
COLUMN "Units"                 FORMAT 9999       HEADING "Qty";
COLUMN "Received"              FORMAT A11        HEADING "Received";
COLUMN "Expiry"                FORMAT A11        HEADING "Expiry";
COLUMN "Days Left"             FORMAT 9999       HEADING "Days";
COLUMN "At-Risk (MYR)"         FORMAT A12        HEADING "At-Risk(MYR)";

-- Formatting for Query 2 Summary
COLUMN "Near-Expiry Batches"   FORMAT 999999     HEADING "Batches";
COLUMN "Total Units at Risk"   FORMAT 999999     HEADING "Units Risk";
COLUMN "Total Financial Exposure" FORMAT A16     HEADING "Total Loss Exp";
COLUMN "Avg Shelf Life Left"   FORMAT A14        HEADING "Avg Shelf Life";


PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 1] STRATEGIC: STOCK REPLENISHMENT DEFICIENCY AND REORDER FORECAST
PROMPT Purpose: Flags critical inventory levels below threshold and calculates reorder costs.
PROMPT ========================================================================================
SELECT 
    b.BranchID,
    SUBSTR(b.BranchName, 1, 18) AS "Branch Name",
    i.ItemID,
    SUBSTR(i.ItemName, 1, 18) AS "Item Description",
    s.Quantity AS "Current Stock",
    s.ReorderLevel AS "Reorder Threshold",
    s.MaximumStock AS "Capacity Limit",
    (s.MaximumStock - s.Quantity) AS "Order Qty",
    TO_CHAR((s.MaximumStock - s.Quantity) * i.Price, 'FM99,990.00') AS "Est Cost (MYR)"
FROM Branch b
JOIN Stock s ON b.BranchID = s.BranchID
JOIN Item i ON s.ItemID = i.ItemID
WHERE s.Quantity <= s.ReorderLevel
ORDER BY b.BranchID, (s.MaximumStock - s.Quantity) DESC;

PROMPT
PROMPT ----------------------------------------------------------------------------------------
PROMPT REORDER DEFICIENCY and BUDGET FORECAST TOTALS:
PROMPT ----------------------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT s.BranchID) AS "Branches in Deficit",
    COUNT(*) AS "Deficient SKU Lines",
    SUM(s.MaximumStock - s.Quantity) AS "Total Units Needed",
    TO_CHAR(SUM((s.MaximumStock - s.Quantity) * i.Price), 'FM$999,990.00') AS "Total Restock Budget"
FROM Stock s
JOIN Item i ON s.ItemID = i.ItemID
WHERE s.Quantity <= s.ReorderLevel;
PROMPT
PROMPT CONCLUSION: Critical stock deficit across store network requires immediate purchase order generation to avoid stockout losses.
PROMPT ========================================================================================

PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 2] TACTICAL: NEAR-EXPIRY BATCH RISK AND SPOILAGE EXPOSURE
PROMPT Purpose: Audits batches expiring within 90 days to minimize warehouse spoilage losses.
PROMPT ========================================================================================
SELECT 
    sb.BatchID,
    SUBSTR(i.ItemName, 1, 18) AS "Item Name",
    SUBSTR(b.BranchName, 1, 16) AS "Warehouse Branch",
    sb.Quantity AS "Units",
    TO_CHAR(sb.ReceivedDate, 'YYYY-MM-DD') AS "Received",
    TO_CHAR(sb.ExpiryDate, 'YYYY-MM-DD') AS "Expiry",
    ROUND(sb.ExpiryDate - SYSDATE) AS "Days Left",
    TO_CHAR(sb.Quantity * i.Price, 'FM99,990.00') AS "At-Risk (MYR)"
FROM StockBatch sb
JOIN Item i ON sb.ItemID = i.ItemID
JOIN Branch b ON sb.BranchID = b.BranchID
WHERE sb.ExpiryDate IS NOT NULL 
  AND sb.ExpiryDate <= SYSDATE + 90
ORDER BY sb.ExpiryDate ASC;

PROMPT
PROMPT ----------------------------------------------------------------------------------------
PROMPT AT-RISK INVENTORY (<90 DAYS) FINANCIAL EXPOSURE:
PROMPT ----------------------------------------------------------------------------------------
SELECT 
    COUNT(*) AS "Near-Expiry Batches",
    SUM(sb.Quantity) AS "Total Units at Risk",
    TO_CHAR(SUM(sb.Quantity * i.Price), 'FM$999,990.00') AS "Total Financial Exposure",
    TO_CHAR(AVG(ROUND(sb.ExpiryDate - SYSDATE)), 'FM990.0') || ' Days' AS "Avg Shelf Life Left"
FROM StockBatch sb
JOIN Item i ON sb.ItemID = i.ItemID
WHERE sb.ExpiryDate IS NOT NULL AND sb.ExpiryDate <= SYSDATE + 90;
PROMPT
PROMPT CONCLUSION: Trigger Module 4 markdown discounts for batches under 30 days remaining to accelerate sell-through.
PROMPT ========================================================================================


-- TASK 5: STORED PROCEDURES WITH EXCEPTION HANDLING (2 PROCEDURES)
-- -----------------------------------------------------------------------------

-- Procedure 1: Mark Purchase Order as Received and Sync Branch Inventory
-- Updates PO status, increments Stock and StockBatch, and records audit entry.
CREATE OR REPLACE PROCEDURE sp_receive_purchase_order (
    p_po_id        IN PurchaseOrder.PurchaseOrderID%TYPE,
    p_employee_id  IN Employee.EmployeeID%TYPE,
    p_branch_id    IN Branch.BranchID%TYPE
) AS
    -- Custom Exceptions
    e_po_not_approved      EXCEPTION;
    e_employee_unauthorized EXCEPTION;
    e_empty_po             EXCEPTION;

    v_po_status     PurchaseOrder.Status%TYPE;
    v_emp_branch    Employee.BranchID%TYPE;
    v_emp_status    Employee.EmployeeStatus%TYPE;
    v_item_count    NUMBER := 0;
    v_log_id        NUMBER;

    -- Cursor to fetch line items
    CURSOR c_po_items IS
        SELECT ItemID, Quantity, CostPrice
        FROM PurchaseOrderItem
        WHERE PurchaseOrderID = p_po_id;
BEGIN
    -- 0. Input Parameter Validation
    IF p_po_id <= 0 OR p_employee_id <= 0 OR p_branch_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20114, 'Validation Error: Purchase Order ID, Employee ID, and Branch ID must be positive integers.');
    END IF;

    -- 1. Validate PO Existence and Status
    SELECT Status INTO v_po_status
    FROM PurchaseOrder
    WHERE PurchaseOrderID = p_po_id;

    IF v_po_status <> 'Approved' AND v_po_status <> 'Pending' THEN
        RAISE e_po_not_approved;
    END IF;

    -- 2. Validate Receiving Employee
    SELECT BranchID, EmployeeStatus INTO v_emp_branch, v_emp_status
    FROM Employee
    WHERE EmployeeID = p_employee_id;

    IF v_emp_status <> 'Active' OR v_emp_branch <> p_branch_id THEN
        RAISE e_employee_unauthorized;
    END IF;

    -- 3. Process Line Items
    FOR r_item IN c_po_items LOOP
        v_item_count := v_item_count + 1;

        -- Upsert branch Stock record
        MERGE INTO Stock s
        USING (SELECT p_branch_id AS b_id, r_item.ItemID AS i_id FROM DUAL) src
        ON (s.BranchID = src.b_id AND s.ItemID = src.i_id)
        WHEN MATCHED THEN
            UPDATE SET s.Quantity = s.Quantity + r_item.Quantity, s.LastUpdated = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (BranchID, ItemID, Quantity, ReorderLevel, MaximumStock, ShelfLocation, LastUpdated)
            VALUES (p_branch_id, r_item.ItemID, r_item.Quantity, 10, 500, 'Aisle-Receiving', SYSDATE);

        -- Add to StockBatch (Default 180-day shelf life)
        INSERT INTO StockBatch (
            BatchID, Quantity, ExpiryDate, ReceivedDate, BranchID, ItemID
        ) VALUES (
            (SELECT NVL(MAX(BatchID), 0) + 1 FROM StockBatch),
            r_item.Quantity,
            ADD_MONTHS(SYSDATE, 6),
            SYSDATE,
            p_branch_id,
            r_item.ItemID
        );

        -- Log Inventory Transaction
        v_log_id := seq_stock_log_id.NEXTVAL;
        INSERT INTO StockLog (
            StockLogID, AdjustmentType, QuantityChanged, AdjustmentDate,
            Remarks, BranchID, ItemID, EmployeeID
        ) VALUES (
            v_log_id, 'Restock - PO Delivery', r_item.Quantity, SYSDATE,
            'PO #' || p_po_id || ' received and verified by Staff #' || p_employee_id,
            p_branch_id, r_item.ItemID, p_employee_id
        );
    END LOOP;

    IF v_item_count = 0 THEN
        RAISE e_empty_po;
    END IF;

    -- 4. Mark PO as Received
    UPDATE PurchaseOrder
    SET Status = 'Received'
    WHERE PurchaseOrderID = p_po_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: PO #' || p_po_id || ' received. ' || v_item_count || ' items added to Branch #' || p_branch_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20101, 'Lookup Error: Purchase Order, Employee, or Branch not found.');
    WHEN e_po_not_approved THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20102, 'State Error: Purchase Order cannot be received (Current Status: ' || v_po_status || ').');
    WHEN e_employee_unauthorized THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20103, 'Auth Error: Staff #' || p_employee_id || ' is inactive or does not belong to Branch #' || p_branch_id);
    WHEN e_empty_po THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20104, 'Integrity Error: PO #' || p_po_id || ' has no line items.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20100, 'System Error in sp_receive_purchase_order: ' || SQLERRM);
END sp_receive_purchase_order;
/

-- Procedure 2: Log Damaged/Expired Stock Write-Off
-- Demonstrates check constraint exception binding, quantity reduction, and audit trail.
CREATE OR REPLACE PROCEDURE sp_adjust_damaged_stock (
    p_branch_id   IN Stock.BranchID%TYPE,
    p_item_id     IN Stock.ItemID%TYPE,
    p_employee_id IN Employee.EmployeeID%TYPE,
    p_qty_damaged IN NUMBER,
    p_adj_type    IN VARCHAR2, -- 'Damaged', 'Expired', 'Audit Write-off'
    p_remarks     IN VARCHAR2
) AS
    -- PRAGMA Exception for Oracle Check Constraint violation (-2290)
    e_check_constraint_violated EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_check_constraint_violated, -2290);

    -- Custom Exceptions
    e_invalid_qty        EXCEPTION;
    e_insufficient_stock EXCEPTION;

    v_current_stock NUMBER;
    v_log_id        NUMBER;
BEGIN
    IF p_branch_id <= 0 OR p_item_id <= 0 OR p_employee_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20112, 'Validation Error: Branch, Item, and Employee IDs must be positive integers.');
    END IF;

    IF p_adj_type NOT IN ('Damaged', 'Expired', 'Audit Write-off', 'Audit Correction') THEN
        RAISE_APPLICATION_ERROR(-20113, 'Validation Error: AdjustmentType must be Damaged, Expired, Audit Write-off, or Audit Correction.');
    END IF;

    IF p_remarks IS NULL OR LENGTH(TRIM(p_remarks)) < 3 THEN
        RAISE_APPLICATION_ERROR(-20115, 'Validation Error: Remarks must provide an audit reason (minimum 3 characters).');
    END IF;

    IF p_qty_damaged <= 0 THEN
        RAISE e_invalid_qty;
    END IF;

    SELECT Quantity INTO v_current_stock
    FROM Stock
    WHERE BranchID = p_branch_id AND ItemID = p_item_id;

    IF v_current_stock < p_qty_damaged THEN
        RAISE e_insufficient_stock;
    END IF;

    -- Decrement branch stock
    UPDATE Stock
    SET Quantity = Quantity - p_qty_damaged,
        LastUpdated = SYSDATE
    WHERE BranchID = p_branch_id AND ItemID = p_item_id;

    -- Record Audit Trail
    v_log_id := seq_stock_log_id.NEXTVAL;
    INSERT INTO StockLog (
        StockLogID, AdjustmentType, QuantityChanged, AdjustmentDate,
        Remarks, BranchID, ItemID, EmployeeID
    ) VALUES (
        v_log_id, p_adj_type, -p_qty_damaged, SYSDATE,
        SUBSTR(p_remarks, 1, 300), p_branch_id, p_item_id, p_employee_id
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Write-off complete: ' || p_qty_damaged || ' units adjusted for Item #' || p_item_id || ' at Branch #' || p_branch_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20105, 'Lookup Error: Stock record for Item #' || p_item_id || ' at Branch #' || p_branch_id || ' not found.');
    WHEN e_invalid_qty THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20106, 'Validation Error: Quantity damaged must be greater than zero.');
    WHEN e_insufficient_stock THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20107, 'Stock Error: Current stock (' || v_current_stock || ') is less than requested write-off (' || p_qty_damaged || ').');
    WHEN e_check_constraint_violated THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20108, 'Integrity Error: Check constraint violated during stock adjustment.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20100, 'System Error in sp_adjust_damaged_stock: ' || SQLERRM);
END sp_adjust_damaged_stock;
/

-- -----------------------------------------------------------------------------
-- TASK 6: CONDITIONAL TRIGGERS (2 TRIGGERS)
-- -----------------------------------------------------------------------------

-- Trigger 1: Enforce Positive Quantities and Costs in Purchase Orders
CREATE OR REPLACE TRIGGER trg_guard_po_item_integrity
BEFORE INSERT OR UPDATE ON PurchaseOrderItem
FOR EACH ROW
WHEN (NEW.Quantity <= 0 OR NEW.CostPrice <= 0)
BEGIN
    RAISE_APPLICATION_ERROR(-20110, 'Trigger Violation: Purchase order item Quantity and CostPrice must both be strictly greater than zero.');
END trg_guard_po_item_integrity;
/

-- Trigger 2: Prevent Stock from Exceeding Branch Warehouse Capacity
CREATE OR REPLACE TRIGGER trg_guard_maximum_stock_capacity
BEFORE UPDATE OF Quantity ON Stock
FOR EACH ROW
WHEN (NEW.Quantity > OLD.MaximumStock)
BEGIN
    RAISE_APPLICATION_ERROR(-20111, 'Trigger Violation: Updated stock (' || :NEW.Quantity || ') exceeds branch maximum storage capacity (' || :OLD.MaximumStock || ').');
END trg_guard_maximum_stock_capacity;
/

-- -----------------------------------------------------------------------------
-- TASK 7: REPORTS GENERATION WITH NESTED CURSORS (2 REPORTS)
-- -----------------------------------------------------------------------------

-- Report 1: Comprehensive Branch Inventory and Stock Audit Report (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_branch_inventory_audit (
    p_branch_id IN Branch.BranchID%TYPE
) AS
    -- Parent Cursor: Branch Details
    CURSOR c_branch IS
        SELECT BranchID, BranchName, Address, City, State, BranchPhoneNo
        FROM Branch
        WHERE BranchID = p_branch_id;

    -- Nested Child Cursor 1: Current Stock and Reorder Status
    CURSOR c_stock (cp_branch_id NUMBER) IS
        SELECT s.ItemID, i.ItemName, i.Brand, s.Quantity, s.ReorderLevel, s.MaximumStock, s.ShelfLocation, i.Price
        FROM Stock s
        JOIN Item i ON s.ItemID = i.ItemID
        WHERE s.BranchID = cp_branch_id
        ORDER BY s.Quantity ASC;

    -- Nested Child Cursor 2: Recent Stock Adjustment Logs (Last 10)
    CURSOR c_logs (cp_branch_id NUMBER) IS
        SELECT sl.StockLogID, sl.AdjustmentDate, i.ItemName, sl.AdjustmentType, sl.QuantityChanged, e.EmployeeName
        FROM StockLog sl
        JOIN Item i ON sl.ItemID = i.ItemID
        JOIN Employee e ON sl.EmployeeID = e.EmployeeID
        WHERE sl.BranchID = cp_branch_id
        ORDER BY sl.AdjustmentDate DESC;

    r_br c_branch%ROWTYPE;
    v_total_units NUMBER := 0;
    v_total_val   NUMBER := 0;
    v_low_stock   NUMBER := 0;
BEGIN
    IF p_branch_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Branch ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_branch;
    FETCH c_branch INTO r_br;
    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID #' || p_branch_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_branch;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                    88 SPEEDMART BRANCH INVENTORY AUDIT REPORT                          ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Branch ID   : #' || r_br.BranchID || ' - ' || r_br.BranchName);
    DBMS_OUTPUT.PUT_LINE('Location    : ' || r_br.Address || ', ' || r_br.City || ', ' || r_br.State);
    DBMS_OUTPUT.PUT_LINE('Contact     : ' || r_br.BranchPhoneNo || ' | Report Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('CURRENT INVENTORY LEVEL:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Item ID', 9) || RPAD('Item Name', 24) || RPAD('Shelf', 14) || LPAD('Qty', 8) || LPAD('Reorder', 10) || LPAD('Max', 8) || LPAD('Value (MYR)', 14));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_stk IN c_stock(r_br.BranchID) LOOP
        v_total_units := v_total_units + r_stk.Quantity;
        v_total_val   := v_total_val + (r_stk.Quantity * r_stk.Price);
        IF r_stk.Quantity <= r_stk.ReorderLevel THEN
            v_low_stock := v_low_stock + 1;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_stk.ItemID, 9) ||
            RPAD(SUBSTR(r_stk.ItemName, 1, 22), 24) ||
            RPAD(NVL(r_stk.ShelfLocation, 'N/A'), 14) ||
            LPAD(r_stk.Quantity, 8) ||
            LPAD(r_stk.ReorderLevel, 10) ||
            LPAD(r_stk.MaximumStock, 8) ||
            LPAD(TO_CHAR(r_stk.Quantity * r_stk.Price, 'FM999,990.00'), 14)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('RECENT STOCK ADJUSTMENTS AND WRITE-OFFS:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Log ID', 9) || RPAD('Date', 12) || RPAD('Item Name', 22) || RPAD('Type', 20) || LPAD('Qty', 8) || '  ' || RPAD('Staff', 16));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_lg IN c_logs(r_br.BranchID) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_lg.StockLogID, 9) ||
            RPAD(TO_CHAR(r_lg.AdjustmentDate, 'YYYY-MM-DD'), 12) ||
            RPAD(SUBSTR(r_lg.ItemName, 1, 20), 22) ||
            RPAD(SUBSTR(r_lg.AdjustmentType, 1, 18), 20) ||
            LPAD(r_lg.QuantityChanged, 8) || '  ' ||
            RPAD(SUBSTR(r_lg.EmployeeName, 1, 15), 16)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('SUMMARY: Total Units: ' || v_total_units || ' | Total Value: MYR ' || TO_CHAR(v_total_val, 'FM999,990.00') || ' | Low Stock Alerts: ' || v_low_stock);
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_branch_inventory_audit;
/

-- Report 2: Supplier Procurement and Purchase Order Line Summary (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_supplier_procurement_audit (
    p_supplier_id IN Supplier.SupplierID%TYPE
) AS
    -- Parent Cursor: Supplier Header
    CURSOR c_sup IS
        SELECT SupplierID, CompanyName, PhoneNo, Email, City, State, SupplierStatus
        FROM Supplier
        WHERE SupplierID = p_supplier_id;

    -- Nested Child Cursor: Purchase Orders
    CURSOR c_po (cp_sup_id NUMBER) IS
        SELECT PurchaseOrderID, OrderDate, Status
        FROM PurchaseOrder
        WHERE SupplierID = cp_sup_id
        ORDER BY OrderDate DESC;

    -- Inner Line Item Cursor for each PO
    CURSOR c_po_lines (cp_po_id NUMBER) IS
        SELECT poi.ItemID, i.ItemName, poi.Quantity, poi.CostPrice, (poi.Quantity * poi.CostPrice) AS LineTotal
        FROM PurchaseOrderItem poi
        JOIN Item i ON poi.ItemID = i.ItemID
        WHERE poi.PurchaseOrderID = cp_po_id;

    r_sup c_sup%ROWTYPE;
    v_po_total NUMBER;
    v_grand_spend NUMBER := 0;
BEGIN
    IF p_supplier_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Supplier ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_sup;
    FETCH c_sup INTO r_sup;
    IF c_sup%NOTFOUND THEN
        CLOSE c_sup;
        DBMS_OUTPUT.PUT_LINE('Error: Supplier ID #' || p_supplier_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_sup;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                   88 SPEEDMART SUPPLIER PROCUREMENT BREAKDOWN                          ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Supplier ID : #' || r_sup.SupplierID || ' - ' || r_sup.CompanyName);
    DBMS_OUTPUT.PUT_LINE('Contact     : ' || r_sup.PhoneNo || ' | ' || r_sup.Email || ' | Status: ' || r_sup.SupplierStatus);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_p IN c_po(r_sup.SupplierID) LOOP
        v_po_total := 0;
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '>> PURCHASE ORDER #' || r_p.PurchaseOrderID || ' | Date: ' || TO_CHAR(r_p.OrderDate, 'YYYY-MM-DD') || ' | Status: ' || r_p.Status);
        DBMS_OUTPUT.PUT_LINE('   ' || RPAD('Item ID', 9) || RPAD('Item Name', 26) || LPAD('Qty', 8) || LPAD('Unit Cost (MYR)', 18) || LPAD('Subtotal (MYR)', 18));
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');

        FOR r_ln IN c_po_lines(r_p.PurchaseOrderID) LOOP
            v_po_total := v_po_total + r_ln.LineTotal;
            DBMS_OUTPUT.PUT_LINE('   ' ||
                RPAD('#' || r_ln.ItemID, 9) ||
                RPAD(SUBSTR(r_ln.ItemName, 1, 24), 26) ||
                LPAD(r_ln.Quantity, 8) ||
                LPAD(TO_CHAR(r_ln.CostPrice, 'FM999,990.00'), 18) ||
                LPAD(TO_CHAR(r_ln.LineTotal, 'FM999,990.00'), 18)
            );
        END LOOP;

        v_grand_spend := v_grand_spend + v_po_total;
        DBMS_OUTPUT.PUT_LINE('   PO Subtotal: MYR ' || TO_CHAR(v_po_total, 'FM999,990.00'));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('GRAND TOTAL PROCUREMENT EXPENDITURE: MYR ' || TO_CHAR(v_grand_spend, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_supplier_procurement_audit;
/