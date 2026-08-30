-- ============================================================================
-- MODULE 3: ORDER, PAYMENT & FULFILLMENT MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 3
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 3: ORDER, PAYMENT & FULFILLMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_exclusive_fulfillment
-- SCENARIO: Enforces Core Business Assumption 2 (Mutual Exclusivity).
--   An order can have EITHER a Pickup booking OR a Delivery dispatch, but NEVER both.
--   Rejects any Delivery insert if a matching Pickup record exists for the OrderID.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_exclusive_fulfillment
BEFORE INSERT ON Delivery
FOR EACH ROW
DECLARE
    v_pickup_count NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_pickup_count
    FROM Pickup
    WHERE OrderID = :NEW.OrderID;

    IF v_pickup_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20035, 'Trigger Violation: Order #' || :NEW.OrderID || 
                                ' is already scheduled for In-Store Pickup. Concurrent Delivery dispatch is prohibited (Assumption 2).');
    END IF;
END trg_guard_exclusive_fulfillment;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_guard_paid_payment_state
-- SCENARIO: Enforces Financial Audit Integrity.
--   A settled payment (PaymentStatus = 'Paid') can never be reverted to 'Pending'.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_paid_payment_state
BEFORE UPDATE OF PaymentStatus ON Payment
FOR EACH ROW
WHEN (OLD.PaymentStatus = 'Paid' AND NEW.PaymentStatus = 'Pending')
BEGIN
    RAISE_APPLICATION_ERROR(-20036, 'Trigger Violation: Financial Integrity Protection - Settled payment (ID: ' || 
                            :OLD.PaymentID || ') cannot be reverted to Pending state.');
END trg_guard_paid_payment_state;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_exclusive_fulfillment
PROMPT ============================================================================

DECLARE
    v_pickup_ord_id NUMBER;
BEGIN
    -- Find an order that has a pickup record
    SELECT MIN(OrderID) INTO v_pickup_ord_id FROM Pickup;

    IF v_pickup_ord_id IS NOT NULL THEN
        -- Attempt invalid delivery dispatch for this pickup order
        INSERT INTO Delivery (
            DeliveryID, DeliveryDate, DeliveryTime, DeliveryStatus,
            TrackingNumber, DeliveryRemark, DeliveryServiceID, OrderID
        ) VALUES (
            999902, SYSDATE, '10:00', 'Pending', 'TRK-INVALID-001', 'Conflict Test', 1, v_pickup_ord_id
        );
        ROLLBACK;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Exclusive XOR): ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_guard_paid_payment_state
PROMPT ============================================================================

DECLARE
    v_paid_id NUMBER;
BEGIN
    SELECT MIN(PaymentID) INTO v_paid_id 
    FROM Payment 
    WHERE PaymentStatus = 'Paid';

    IF v_paid_id IS NOT NULL THEN
        UPDATE Payment 
        SET PaymentStatus = 'Pending' 
        WHERE PaymentID = v_paid_id;
        ROLLBACK;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Financial Tampering): ' || SQLERRM);
        ROLLBACK;
END;
/
