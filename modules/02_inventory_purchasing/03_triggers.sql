-- ============================================================================
-- MODULE 2: INVENTORY & PURCHASING MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 2
-- ============================================================================

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
BEFORE UPDATE OF Quantity ON Stock
FOR EACH ROW
WHEN (NEW.Quantity > OLD.MaximumStock)
BEGIN
    RAISE_APPLICATION_ERROR(-20026, 'Trigger Violation: Updating Quantity to ' || :NEW.Quantity || 
                            ' exceeds branch warehouse MaximumStock ceiling (' || :OLD.MaximumStock || ').');
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
    -- Attempt to update quantity beyond MaximumStock
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
