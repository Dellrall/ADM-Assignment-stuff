-- ============================================================================
-- MODULE 2: INVENTORY & PURCHASING MANAGEMENT
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 2
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 2: INVENTORY & PURCHASING MANAGEMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_receive_purchase_order
-- SCENARIO: Handles physical PO delivery intake at branch warehouse.
--   Business Rule 21: PO status cannot be 'Received' until line items are verified.
--   Task 8 Features: MERGE statement, Multiple table atomic updates,
--                    Custom Exceptions, Sequence (seq_stock_log_id), RAISE_APPLICATION_ERROR.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_receive_purchase_order (
    p_po_id               IN  NUMBER,
    p_receiving_branch_id IN  NUMBER,
    p_employee_id         IN  NUMBER,
    p_items_received      OUT NUMBER,
    p_status_msg          OUT VARCHAR2
) AS
    -- User-defined exceptions
    e_po_not_approved       EXCEPTION;
    e_unauthorized_employee EXCEPTION;
    e_empty_po              EXCEPTION;

    v_po_status     VARCHAR2(20);
    v_emp_branch    NUMBER;
    v_emp_status    VARCHAR2(20);
    v_item_count    NUMBER := 0;

    -- Cursor to iterate through PO line items
    CURSOR c_po_items IS
        SELECT ItemID, Quantity, CostPrice
        FROM PurchaseOrderItem
        WHERE PurchaseOrderID = p_po_id;
BEGIN
    -- 1. Validate PO status (must be 'Approved' or 'Pending')
    SELECT Status INTO v_po_status
    FROM PurchaseOrder
    WHERE PurchaseOrderID = p_po_id;

    IF v_po_status = 'Received' THEN
        RAISE_APPLICATION_ERROR(-20021, 'PO Intake Error: Purchase Order #' || p_po_id || ' has already been received.');
    ELSIF v_po_status = 'Cancelled' THEN
        RAISE_APPLICATION_ERROR(-20022, 'PO Intake Error: Purchase Order #' || p_po_id || ' is cancelled.');
    END IF;

    -- 2. Validate receiving employee
    SELECT BranchID, EmployeeStatus INTO v_emp_branch, v_emp_status
    FROM Employee
    WHERE EmployeeID = p_employee_id;

    IF v_emp_status != 'Active' OR v_emp_branch != p_receiving_branch_id THEN
        RAISE e_unauthorized_employee;
    END IF;

    -- 3. Process PO line items into branch Stock and Batch
    FOR item_rec IN c_po_items LOOP
        v_item_count := v_item_count + 1;

        -- Upsert branch Stock using MERGE
        MERGE INTO Stock s
        USING (SELECT p_receiving_branch_id AS BranchID, item_rec.ItemID AS ItemID FROM dual) src
        ON (s.BranchID = src.BranchID AND s.ItemID = src.ItemID)
        WHEN MATCHED THEN
            UPDATE SET s.Quantity = s.Quantity + item_rec.Quantity,
                       s.LastUpdated = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (BranchID, ItemID, Quantity, ReorderLevel, MaximumStock, ShelfLocation, LastUpdated)
            VALUES (p_receiving_branch_id, item_rec.ItemID, item_rec.Quantity, 15, 200, 'Aisle-R1', SYSDATE);

        -- Insert new batch record
        INSERT INTO StockBatch (
            BatchID, Quantity, ExpiryDate, ReceivedDate, BranchID, ItemID
        ) VALUES (
            seq_po_id.NEXTVAL,
            item_rec.Quantity,
            ADD_MONTHS(SYSDATE, 12), -- Default 1-year shelf life
            SYSDATE,
            p_receiving_branch_id,
            item_rec.ItemID
        );

        -- Insert audit log into StockLog
        INSERT INTO StockLog (
            StockLogID, AdjustmentType, QuantityChanged,
            AdjustmentDate, Remarks, BranchID, ItemID, EmployeeID
        ) VALUES (
            seq_stock_log_id.NEXTVAL,
            'Restock',
            item_rec.Quantity,
            SYSDATE,
            'Received physical delivery from PO #' || p_po_id,
            p_receiving_branch_id,
            item_rec.ItemID,
            p_employee_id
        );
    END LOOP;

    IF v_item_count = 0 THEN
        RAISE e_empty_po;
    END IF;

    -- 4. Mark PO as 'Received' (Rule 21)
    UPDATE PurchaseOrder 
    SET Status = 'Received'
    WHERE PurchaseOrderID = p_po_id;

    p_items_received := v_item_count;
    p_status_msg := 'SUCCESS: PO #' || p_po_id || ' received with ' || v_item_count || ' line item(s) processed.';
    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: PO ID #' || p_po_id || ' or Employee ID #' || p_employee_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20023, p_status_msg);

    WHEN e_unauthorized_employee THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Employee is not active or assigned to receiving branch #' || p_receiving_branch_id;
        RAISE_APPLICATION_ERROR(-20024, p_status_msg);

    WHEN e_empty_po THEN
        ROLLBACK;
        p_status_msg := 'FAILED: PO #' || p_po_id || ' contains no line items.';
        RAISE_APPLICATION_ERROR(-20025, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: System error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20026, p_status_msg);
END sp_receive_purchase_order;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_adjust_damaged_stock
-- SCENARIO: Inventory write-off for damaged or expired items.
--   Business Rule 19: Expired/damaged goods must be deducted from stock and 
--   logged in StockLog with employee association.
--   Task 8 Features: PRAGMA EXCEPTION_INIT(-2290), User Exceptions.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_adjust_damaged_stock (
    p_branch_id     IN  NUMBER,
    p_item_id       IN  NUMBER,
    p_employee_id   IN  NUMBER,
    p_qty_to_deduct IN  NUMBER,
    p_adj_type      IN  VARCHAR2,
    p_remarks       IN  VARCHAR2,
    p_status_msg    OUT VARCHAR2
) AS
    -- PRAGMA Binding for Oracle Check Constraint Violation (ORA-02290)
    e_chk_violation EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_chk_violation, -2290);

    -- Custom exceptions
    e_insufficient_stock EXCEPTION;
    e_invalid_adj_type   EXCEPTION;
    e_invalid_qty        EXCEPTION;

    v_current_qty NUMBER;
BEGIN
    -- 1. Validate quantity and adjustment type
    IF p_qty_to_deduct <= 0 THEN
        RAISE e_invalid_qty;
    END IF;

    IF UPPER(TRIM(p_adj_type)) NOT IN ('DAMAGED', 'EXPIRED', 'WRITE-OFF') THEN
        RAISE e_invalid_adj_type;
    END IF;

    -- 2. Verify current stock balance
    SELECT Quantity INTO v_current_qty
    FROM Stock
    WHERE BranchID = p_branch_id AND ItemID = p_item_id
    FOR UPDATE;

    IF v_current_qty < p_qty_to_deduct THEN
        RAISE e_insufficient_stock;
    END IF;

    -- 3. Deduct stock quantity
    UPDATE Stock
    SET Quantity = Quantity - p_qty_to_deduct,
        LastUpdated = SYSDATE
    WHERE BranchID = p_branch_id AND ItemID = p_item_id;

    -- 4. Insert write-off log (Rule 19)
    INSERT INTO StockLog (
        StockLogID, AdjustmentType, QuantityChanged,
        AdjustmentDate, Remarks, BranchID, ItemID, EmployeeID
    ) VALUES (
        seq_stock_log_id.NEXTVAL,
        INITCAP(TRIM(p_adj_type)),
        -p_qty_to_deduct,
        SYSDATE,
        TRIM(p_remarks),
        p_branch_id,
        p_item_id,
        p_employee_id
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Deducted ' || p_qty_to_deduct || ' unit(s) of Item #' || 
                    p_item_id || ' at Branch #' || p_branch_id || ' (' || p_adj_type || ').';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Item #' || p_item_id || ' is not stocked at Branch #' || p_branch_id;
        RAISE_APPLICATION_ERROR(-20027, p_status_msg);

    WHEN e_insufficient_stock THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Current stock (' || v_current_qty || ') is less than deduction quantity (' || p_qty_to_deduct || ').';
        RAISE_APPLICATION_ERROR(-20028, p_status_msg);

    WHEN e_invalid_adj_type THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Adjustment type must be DAMAGED, EXPIRED, or WRITE-OFF.';
        RAISE_APPLICATION_ERROR(-20029, p_status_msg);

    WHEN e_chk_violation THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Database check constraint violated (quantity cannot be negative).';
        RAISE_APPLICATION_ERROR(-20030, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20031, p_status_msg);
END sp_adjust_damaged_stock;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 2: sp_adjust_damaged_stock
PROMPT ============================================================================

DECLARE
    v_msg VARCHAR2(400);
BEGIN
    -- Test 1: Successful damaged stock write-off
    sp_adjust_damaged_stock(
        p_branch_id     => 1,
        p_item_id       => 1,
        p_employee_id   => 1,
        p_qty_to_deduct => 2,
        p_adj_type      => 'Damaged',
        p_remarks       => 'Broken bottle during counter restock',
        p_status_msg    => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional excessive stock deduction (Demonstrating Exception)
    BEGIN
        sp_adjust_damaged_stock(
            p_branch_id     => 1,
            p_item_id       => 1,
            p_employee_id   => 1,
            p_qty_to_deduct => 99999, -- Exceeds stock
            p_adj_type      => 'Expired',
            p_remarks       => 'Test Overdraw',
            p_status_msg    => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception: ' || SQLERRM);
    END;
END;
/
