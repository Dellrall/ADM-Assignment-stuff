-- ============================================================================
-- MODULE 2: INVENTORY & PURCHASING MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 2
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 2: INVENTORY & PURCHASING MANAGEMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_po_item_integrity
-- SCENARIO: Enforces procurement pricing integrity at the database layer.
--   Rejects any PurchaseOrderItem insert/update where Quantity <= 0 or CostPrice <= 0.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_po_item_integrity
BEFORE INSERT OR UPDATE ON PurchaseOrderItem
FOR EACH ROW
WHEN (NEW.Quantity <= 0 OR NEW.CostPrice <= 0)
BEGIN
    RAISE_APPLICATION_ERROR(-20025, 'Trigger Violation: Purchase order line item must have strictly positive Quantity and Cost Price.');
END trg_guard_po_item_integrity;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_guard_maximum_stock_capacity
-- SCENARIO: Enforces warehouse physical ceiling constraints.
--   Prevents any stock update that would push Quantity above MaximumStock.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_maximum_stock_capacity
BEFORE INSERT OR UPDATE OF Quantity ON Stock
FOR EACH ROW
BEGIN
    IF :NEW.Quantity > :NEW.MaximumStock THEN
        RAISE_APPLICATION_ERROR(-20026, 'Trigger Violation: Updating Quantity to ' || :NEW.Quantity || 
                                ' exceeds branch warehouse MaximumStock ceiling (' || :NEW.MaximumStock || ').');
    END IF;
END trg_guard_maximum_stock_capacity;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_po_item_integrity
PROMPT ============================================================================

BEGIN
    -- Attempt invalid PO item with negative cost price
    INSERT INTO PurchaseOrderItem (PurchaseOrderID, ItemID, Quantity, CostPrice)
    VALUES (1, 1, 10, -5.00);
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Negative Cost): ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_guard_maximum_stock_capacity
PROMPT ============================================================================

BEGIN
    -- Ensure test stock record exists with MaximumStock = 200
    MERGE INTO Stock s
    USING (SELECT 1 AS BranchID, 1 AS ItemID FROM dual) src
    ON (s.BranchID = src.BranchID AND s.ItemID = src.ItemID)
    WHEN MATCHED THEN
        UPDATE SET s.MaximumStock = 200
    WHEN NOT MATCHED THEN
        INSERT (BranchID, ItemID, Quantity, ReorderLevel, MaximumStock, ShelfLocation, LastUpdated)
        VALUES (1, 1, 50, 15, 200, 'Aisle 1-A', SYSDATE);

    -- Attempt to update quantity beyond MaximumStock (99,999 > 200)
    UPDATE Stock 
    SET Quantity = 99999 
    WHERE BranchID = 1 AND ItemID = 1;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Exceed Max Capacity): ' || SQLERRM);
        ROLLBACK;
END;
/
