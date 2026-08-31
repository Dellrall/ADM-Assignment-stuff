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
BEFORE INSERT OR UPDATE ON Stock
FOR EACH ROW
DECLARE
    v_max NUMBER;
BEGIN
    v_max := NVL(:NEW.MaximumStock, :OLD.MaximumStock);
    IF v_max IS NOT NULL AND :NEW.Quantity > v_max THEN
        RAISE_APPLICATION_ERROR(-20026, 'Trigger Violation: Quantity (' || :NEW.Quantity || 
                                ') exceeds branch warehouse MaximumStock capacity (' || v_max || ').');
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

DECLARE
    v_branch_id NUMBER;
    v_item_id   NUMBER;
BEGIN
    -- Query a guaranteed existing stock record
    SELECT BranchID, ItemID INTO v_branch_id, v_item_id
    FROM Stock
    WHERE ROWNUM = 1;

    -- Attempt to update quantity beyond MaximumStock (99,999 units)
    UPDATE Stock 
    SET Quantity = 99999 
    WHERE BranchID = v_branch_id AND ItemID = v_item_id;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Exceed Max Capacity): ' || SQLERRM);
        ROLLBACK;
END;
/
