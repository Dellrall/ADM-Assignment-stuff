-- ============================================================================
-- MODULE 5: REFUND & RETURN MANAGEMENT (SELECTED ADDITIONAL MODULE)
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 5
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: REFUND & RETURN MANAGEMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_return_item_condition
-- SCENARIO: Enforces Core Business Rule 33 at database kernel level.
--   "Any received items that are not damaged, defective, or expired cannot be refunded."
--   Rejects any ReturnItem row where ItemCondition is 'New' or 'Good'.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_return_item_condition
BEFORE INSERT OR UPDATE ON ReturnItem
FOR EACH ROW
WHEN (NEW.ItemCondition NOT IN ('Damaged', 'Defective', 'Expired'))
BEGIN
    RAISE_APPLICATION_ERROR(-20055, 'Trigger Violation (Rule 33): Only items in Damaged, Defective, or Expired condition are eligible for return & refund.');
END trg_guard_return_item_condition;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_guard_refund_amount_ceiling
-- SCENARIO: Enforces Financial Integrity on Return Payouts.
--   A requested RefundAmount cannot exceed the actual amount paid by the customer
--   in Payment.AmountPaid for that specific order.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_refund_amount_ceiling
BEFORE INSERT OR UPDATE OF RefundAmount ON Refund
FOR EACH ROW
DECLARE
    v_amount_paid NUMBER;
BEGIN
    SELECT NVL(AmountPaid, 0) INTO v_amount_paid
    FROM Payment
    WHERE OrderID = :NEW.OrderID AND PaymentStatus = 'Paid';

    IF :NEW.RefundAmount > v_amount_paid THEN
        RAISE_APPLICATION_ERROR(-20056, 'Trigger Violation: Requested Refund Amount (RM ' || 
                                TO_CHAR(:NEW.RefundAmount, 'FM999,990.00') || 
                                ') exceeds original amount paid for order (RM ' || 
                                TO_CHAR(v_amount_paid, 'FM999,990.00') || ').');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- If no paid payment record is found, still proceed or warn
        NULL;
END trg_guard_refund_amount_ceiling;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_return_item_condition
PROMPT ============================================================================

BEGIN
    -- Attempt invalid return item in 'Good' condition (Rejected by Rule 33)
    INSERT INTO ReturnItem (RefundID, ItemID, Quantity, ItemCondition, ReturnRemark)
    VALUES (1, 1, 1, 'Good', 'Change of mind test');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Rule 33 Violation): ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_guard_refund_amount_ceiling
PROMPT ============================================================================

DECLARE
    v_order_id NUMBER;
BEGIN
    SELECT MIN(OrderID) INTO v_order_id FROM CustomerOrder WHERE OrderStatus = 'Completed';

    IF v_order_id IS NOT NULL THEN
        -- Attempt excessive refund amount of RM 99,999.00
        INSERT INTO Refund (
            RefundID, RefundDate, RefundReason, ReturnMethod,
            EvidencePhoto, RefundAmount, RefundRemark, RefundStatus, OrderID
        ) VALUES (
            999905, SYSDATE, 'Overdraw Test', 'In-Store Counter',
            'http://proof.test/pic.jpg', 99999.00, 'Excessive test', 'Pending', v_order_id
        );
        ROLLBACK;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Exceeds Paid Amount): ' || SQLERRM);
        ROLLBACK;
END;
/
