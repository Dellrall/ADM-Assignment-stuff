-- ============================================================================
-- MODULE 5: REFUND & RETURN MANAGEMENT (SELECTED ADDITIONAL MODULE)
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 5
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: REFUND & RETURN MANAGEMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_submit_refund_claim
-- SCENARIO: Customer lodges a post-purchase return claim.
--   Business Rule 31: Return/refund requests must be submitted within 7 days of order.
--   Business Rule 33: Only damaged, defective, or expired goods eligible for refund.
--   Task 8 Features: Sequence (seq_refund_id), Custom Exceptions, 
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
--                    Multi-table atomic inserts, RAISE_APPLICATION_ERROR.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_submit_refund_claim (
    p_order_id      IN  NUMBER,
    p_reason        IN  VARCHAR2,
    p_return_method IN  VARCHAR2,
    p_photo_url     IN  VARCHAR2,
    p_item_id       IN  NUMBER,
    p_quantity      IN  NUMBER,
    p_condition     IN  VARCHAR2,
    p_refund_id     OUT NUMBER,
    p_claim_amount  OUT NUMBER,
    p_status_msg    OUT VARCHAR2
) AS
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - CUSTOM USER EXCEPTION]
-- Custom User Exceptions
    e_order_not_completed EXCEPTION;
    e_claim_window_passed EXCEPTION;
    e_invalid_condition   EXCEPTION;
    e_invalid_quantity    EXCEPTION;
    e_item_not_in_order   EXCEPTION;
    e_existing_refund     EXCEPTION;

    v_order_status DATE;
    v_ord_stat_str VARCHAR2(20);
    v_order_date   DATE;
    v_unit_price   NUMBER;
    v_discount     NUMBER;
    v_order_qty    NUMBER;
    v_existing_ref NUMBER := 0;
BEGIN
    -- 1. Validate Order Existence and 7-Day Window (Rule 31)
    SELECT OrderDate, OrderStatus INTO v_order_date, v_ord_stat_str
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_ord_stat_str != 'Completed' THEN
        RAISE e_order_not_completed;
    END IF;

    IF SYSDATE > (v_order_date + 7) THEN
        RAISE e_claim_window_passed;
    END IF;

    -- 2. Check for existing refund claim on this order (Rule 6: 1:1 relationship)
    SELECT COUNT(*) INTO v_existing_ref
    FROM Refund
    WHERE OrderID = p_order_id;

    IF v_existing_ref > 0 THEN
        RAISE e_existing_refund;
    END IF;

    -- 3. Validate Defect Condition (Rule 33)
    IF UPPER(TRIM(p_condition)) NOT IN ('DAMAGED', 'DEFECTIVE', 'EXPIRED') THEN
        RAISE e_invalid_condition;
    END IF;

    -- 4. Validate Item Purchased in Order
    SELECT Quantity, UnitPrice, Discount 
    INTO v_order_qty, v_unit_price, v_discount
    FROM OrderDetail
    WHERE OrderID = p_order_id AND ItemID = p_item_id;

    IF p_quantity <= 0 OR p_quantity > v_order_qty THEN
        RAISE e_invalid_quantity;
    END IF;

    -- 5. Calculate Refund Payout Amount
    p_claim_amount := ROUND(p_quantity * (v_unit_price - v_discount), 2);
    p_refund_id    := seq_refund_id.NEXTVAL;

    -- 6. Insert Refund Ticket and ReturnItem
    INSERT INTO Refund (
        RefundID, RefundDate, RefundReason, ReturnMethod,
        EvidencePhoto, RefundAmount, RefundRemark, RefundStatus, OrderID
    ) VALUES (
        p_refund_id,
        SYSDATE,
        TRIM(p_reason),
        INITCAP(TRIM(p_return_method)),
        p_photo_url,
        p_claim_amount,
        'Customer lodged claim for ' || p_quantity || ' unit(s) of Item #' || p_item_id,
        'Pending',
        p_order_id
    );

    INSERT INTO ReturnItem (
        RefundID, ItemID, Quantity, ItemCondition, ReturnRemark
    ) VALUES (
        p_refund_id,
        p_item_id,
        p_quantity,
        INITCAP(TRIM(p_condition)),
        'Return verified: ' || p_condition
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Refund Claim #' || p_refund_id || ' submitted (Claim Amount: RM ' || 
                    TO_CHAR(p_claim_amount, 'FM999,990.00') || '). Status: Pending Review.';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Order ID #' || p_order_id || ' or Item #' || p_item_id || ' does not exist in order records.';
        RAISE_APPLICATION_ERROR(-20051, p_status_msg);

    WHEN e_order_not_completed THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Refund can only be requested for Completed orders.';
        RAISE_APPLICATION_ERROR(-20052, p_status_msg);

    WHEN e_claim_window_passed THEN
        ROLLBACK;
        p_status_msg := 'FAILED: 7-day refund request window has expired for this order (Rule 31).';
        RAISE_APPLICATION_ERROR(-20053, p_status_msg);

    WHEN e_invalid_condition THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Only Damaged, Defective, or Expired items are eligible for refund (Rule 33).';
        RAISE_APPLICATION_ERROR(-20054, p_status_msg);

    WHEN e_invalid_quantity THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Returned quantity must be between 1 and ' || v_order_qty;
        RAISE_APPLICATION_ERROR(-20055, p_status_msg);

    WHEN e_existing_refund THEN
        ROLLBACK;
        p_status_msg := 'FAILED: A refund claim has already been lodged for Order #' || p_order_id;
        RAISE_APPLICATION_ERROR(-20056, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20057, p_status_msg);
END sp_submit_refund_claim;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_adjudicate_refund_claim
-- SCENARIO: Store manager reviews and approves/rejects a refund claim.
--   Business Rule 32: Approved refunds credited back to original payment within 5-7 days.
--   Task 8 Features: PRAGMA EXCEPTION_INIT(-2290), Cascading status updates.
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_adjudicate_refund_claim (
    p_refund_id       IN  NUMBER,
    p_decision        IN  VARCHAR2,
    p_manager_remarks IN  VARCHAR2,
    p_status_msg      OUT VARCHAR2
) AS
    -- PRAGMA Binding for Oracle Check Constraint Violation (ORA-02290)
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - PRAGMA EXCEPTION_INIT]
    e_chk_constraint EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_chk_constraint, -2290);

    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - CUSTOM USER EXCEPTION]
-- Custom User Exceptions
    e_claim_not_pending EXCEPTION;
    e_invalid_decision  EXCEPTION;

    v_claim_status VARCHAR2(20);
    v_order_id     NUMBER;
BEGIN
    -- 1. Validate Claim State
    SELECT RefundStatus, OrderID INTO v_claim_status, v_order_id
    FROM Refund
    WHERE RefundID = p_refund_id
    FOR UPDATE;

    IF v_claim_status != 'Pending' THEN
        RAISE e_claim_not_pending;
    END IF;

    IF UPPER(TRIM(p_decision)) NOT IN ('APPROVED', 'REJECTED') THEN
        RAISE e_invalid_decision;
    END IF;

    -- 2. Update Refund Status and Adjudication Remarks
    UPDATE Refund
    SET RefundStatus = INITCAP(TRIM(p_decision)),
        RefundRemark = TRIM(p_manager_remarks)
    WHERE RefundID = p_refund_id;

    -- 3. If Approved, update Payment status and OrderDetail line status (Rule 32)
    IF UPPER(TRIM(p_decision)) = 'APPROVED' THEN
        UPDATE Payment
        SET PaymentStatus = 'Refunded'
        WHERE OrderID = v_order_id;

        UPDATE OrderDetail
        SET LineStatus = 'Returned'
        WHERE OrderID = v_order_id
          AND ItemID IN (SELECT ItemID FROM ReturnItem WHERE RefundID = p_refund_id);
    END IF;

    COMMIT;
    p_status_msg := 'SUCCESS: Claim #' || p_refund_id || ' adjudicated as ' || 
                    UPPER(TRIM(p_decision)) || '. (Order #' || v_order_id || ').';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Refund ID #' || p_refund_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20058, p_status_msg);

    WHEN e_claim_not_pending THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Claim #' || p_refund_id || ' is already ' || v_claim_status;
        RAISE_APPLICATION_ERROR(-20059, p_status_msg);

    WHEN e_invalid_decision THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Decision must be either APPROVED or REJECTED.';
        RAISE_APPLICATION_ERROR(-20060, p_status_msg);

    WHEN e_chk_constraint THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Database check constraint violated on refund status transition (ORA-02290).';
        RAISE_APPLICATION_ERROR(-20061, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20062, p_status_msg);
END sp_adjudicate_refund_claim;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 1: sp_submit_refund_claim
PROMPT ============================================================================

DECLARE
    v_test_order_id NUMBER := 999905;
    v_ref_id NUMBER;
    v_amt    NUMBER;
    v_msg    VARCHAR2(400);
BEGIN
    -- Setup temporary Completed test order within 7-day window
    DELETE FROM ReturnItem WHERE RefundID IN (SELECT RefundID FROM Refund WHERE OrderID = v_test_order_id);
    DELETE FROM Refund WHERE OrderID = v_test_order_id;
    DELETE FROM Payment WHERE OrderID = v_test_order_id;
    DELETE FROM OrderDetail WHERE OrderID = v_test_order_id;
    DELETE FROM CustomerOrder WHERE OrderID = v_test_order_id;

    INSERT INTO CustomerOrder (OrderID, OrderDate, OrderTime, OrderStatus, MemberID, BranchID)
    VALUES (v_test_order_id, SYSDATE, '12:00', 'Completed', 1, 1);

    INSERT INTO OrderDetail (ItemID, OrderID, Quantity, UnitPrice, Discount, LineStatus)
    VALUES (1, v_test_order_id, 2, 25.90, 0.00, 'Active');

    INSERT INTO Payment (PaymentID, PaymentMethod, PaymentDate, AmountPaid, TransactionNo, PaymentStatus, OrderID)
    VALUES (999905, 'Card', SYSDATE, 51.80, 'TXN-TEST-999905', 'Paid', v_test_order_id);

    -- Test 1: Successful Refund Claim Submission
    sp_submit_refund_claim(
        p_order_id      => v_test_order_id,
        p_reason        => 'Milk bottle was sour and curdled upon delivery',
        p_return_method => 'Drop-off at Branch',
        p_photo_url     => 'http://proof.speedmart88.my/proof01.jpg',
        p_item_id       => 1,
        p_quantity      => 1,
        p_condition     => 'Expired',
        p_refund_id     => v_ref_id,
        p_claim_amount  => v_amt,
        p_status_msg    => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional Invalid Condition (Demonstrating Exception on 'Good' items)
    BEGIN
        sp_submit_refund_claim(
            p_order_id      => v_test_order_id,
            p_reason        => 'Changed my mind',
            p_return_method => 'In-Store Counter',
            p_photo_url     => 'http://proof.test/pic.jpg',
            p_item_id       => 1,
            p_quantity      => 1,
            p_condition     => 'Good', -- Rejected by Rule 33!
            p_refund_id     => v_ref_id,
            p_claim_amount  => v_amt,
            p_status_msg    => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception (Rule 33 Guard): ' || SQLERRM);
    END;
END;
/
