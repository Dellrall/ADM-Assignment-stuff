-- ============================================================================
-- MODULE 3: ORDER, PAYMENT & FULFILLMENT MANAGEMENT
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 3
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 3: ORDER, PAYMENT & FULFILLMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_create_pickup_order
-- SCENARIO: Handles customer in-store pickup booking and code generation.
--   Business Rules 2, 22, 28, 29: Pickup is free; generates unique 6-digit code;
--   enforces customer cancellation safety limit (<3 cancellations/day).
--   Task 8 Features: Sequence (seq_order_id), Autonomous code generation,
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
--                    Custom Exceptions, RAISE_APPLICATION_ERROR.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_create_pickup_order (
    p_member_id    IN  NUMBER,
    p_branch_id    IN  NUMBER,
    p_pickup_date  IN  DATE,
    p_order_id     OUT NUMBER,
    p_pickup_code  OUT VARCHAR2,
    p_status_msg   OUT VARCHAR2
) AS
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - CUSTOM USER EXCEPTION]
    -- Custom Exceptions
    e_inactive_member    EXCEPTION;
    e_inactive_branch    EXCEPTION;
    e_daily_limit_excess EXCEPTION;

    v_mem_status    VARCHAR2(20);
    v_branch_status VARCHAR2(20);
    v_branch_addr   VARCHAR2(200);
    v_daily_cancels NUMBER := 0;
BEGIN
    -- 1. Validate Member State
    SELECT MemberStatus INTO v_mem_status
    FROM Member
    WHERE MemberID = p_member_id;

    IF v_mem_status != 'Active' THEN
        RAISE e_inactive_member;
    END IF;

    -- 2. Validate Branch State
    SELECT BranchStatus, Address INTO v_branch_status, v_branch_addr
    FROM Branch
    WHERE BranchID = p_branch_id;

    IF v_branch_status != 'Active' THEN
        RAISE e_inactive_branch;
    END IF;

    -- 3. Check Daily Cancellation Abuse Protection (Rule 28: max 3/day)
    SELECT COUNT(*) INTO v_daily_cancels
    FROM CustomerOrder
    WHERE MemberID = p_member_id 
      AND TRUNC(OrderDate) = TRUNC(SYSDATE)
      AND OrderStatus = 'Cancelled';

    IF v_daily_cancels >= 3 THEN
        RAISE e_daily_limit_excess;
    END IF;

    -- 4. Generate Unique 6-Digit Pickup Code (e.g. PK8492) (Rule 29)
    p_pickup_code := 'PK' || LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1000, 9999))), 4, '0');
    p_order_id    := seq_order_id.NEXTVAL;

    -- 5. Atomic Insertion into CustomerOrder and Pickup
    INSERT INTO CustomerOrder (
        OrderID, OrderDate, OrderTime, OrderStatus, MemberID, BranchID
    ) VALUES (
        p_order_id,
        SYSDATE,
        TO_CHAR(SYSDATE, 'HH24:MI'),
        'Pending',
        p_member_id,
        p_branch_id
    );

    INSERT INTO Pickup (
        PickupID, PickupDate, PickupTime, PickupCode,
        PickupAddress, PickupStatus, Remarks, OrderID
    ) VALUES (
        p_order_id,
        NVL(p_pickup_date, TRUNC(SYSDATE) + 1),
        '14:00',
        p_pickup_code,
        v_branch_addr,
        'Pending',
        'Self-pickup order generated via counter/app',
        p_order_id
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Pickup Order #' || p_order_id || 
                    ' booked. Claim Code: ' || p_pickup_code || ' at Branch #' || p_branch_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Member ID #' || p_member_id || ' or Branch ID #' || p_branch_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20031, p_status_msg);

    WHEN e_inactive_member THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Member account is Inactive.';
        RAISE_APPLICATION_ERROR(-20032, p_status_msg);

    WHEN e_inactive_branch THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Selected retail branch is currently closed or inactive.';
        RAISE_APPLICATION_ERROR(-20033, p_status_msg);

    WHEN e_daily_limit_excess THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Order blocked. Member has reached daily cancellation limit (Rule 28).';
        RAISE_APPLICATION_ERROR(-20034, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: System error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20035, p_status_msg);
END sp_create_pickup_order;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_settle_order_payment
-- SCENARIO: Multi-channel checkout settlement and loyalty points award.
--   Business Rules 8, 30: Settlements via Cash, Card, E-Wallet, Online Banking;
--   awards 1 point per RM 1.00 spent on completed orders.
--   Task 8 Features: PRAGMA EXCEPTION_INIT(-1), Sequence (seq_payment_id),
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
--                    Points accrual transaction.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_settle_order_payment (
    p_order_id         IN  NUMBER,
    p_payment_method   IN  VARCHAR2,
    p_amount_paid      IN  NUMBER,
    p_transaction_no   IN  VARCHAR2,
    p_payment_id       OUT NUMBER,
    p_points_awarded   OUT NUMBER,
    p_status_msg       OUT VARCHAR2
) AS
    -- PRAGMA Binding for Unique Constraint Violation (ORA-00001)
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - PRAGMA EXCEPTION_INIT]
    e_duplicate_txn EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_duplicate_txn, -1);

    -- Custom Exceptions
    e_order_not_pending EXCEPTION;
    e_invalid_method    EXCEPTION;
    e_underpayment      EXCEPTION;

    v_order_status  VARCHAR2(20);
    v_member_id     NUMBER;
    v_order_items_total NUMBER := 0;
    v_delivery_fee      NUMBER := 0;
    v_net_payable       NUMBER := 0;
BEGIN
    -- 1. Validate Order Status and Member
    SELECT OrderStatus, MemberID INTO v_order_status, v_member_id
    FROM CustomerOrder
    WHERE OrderID = p_order_id
    FOR UPDATE;

    IF v_order_status != 'Pending' THEN
        RAISE e_order_not_pending;
    END IF;

    -- 2. Validate Payment Method (Rule 30)
    IF UPPER(TRIM(p_payment_method)) NOT IN ('CASH', 'CARD', 'E-WALLET', 'ONLINE BANKING') THEN
        RAISE e_invalid_method;
    END IF;

    -- 3. Calculate Required Grand Total (Items Subtotal + Delivery Charge)
    SELECT NVL(SUM(Quantity * (UnitPrice - Discount)), 0)
    INTO v_order_items_total
    FROM OrderDetail
    WHERE OrderID = p_order_id;

    SELECT NVL(SUM(ds.DeliveryCharge), 0)
    INTO v_delivery_fee
    FROM Delivery d
    JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
    WHERE d.OrderID = p_order_id;

    v_net_payable := v_order_items_total + v_delivery_fee;

    -- For orders with line items, ensure amount paid meets payable total
    IF v_order_items_total > 0 AND p_amount_paid < v_net_payable THEN
        RAISE e_underpayment;
    END IF;

    -- 4. Insert Payment Record
    p_payment_id := seq_payment_id.NEXTVAL;

    INSERT INTO Payment (
        PaymentID, PaymentMethod, PaymentDate, AmountPaid,
        TransactionNo, PaymentStatus, OrderID
    ) VALUES (
        p_payment_id,
        INITCAP(TRIM(p_payment_method)),
        SYSDATE,
        p_amount_paid,
        TRIM(p_transaction_no),
        'Paid',
        p_order_id
    );

    -- 5. Mark Order Completed and Accrue Loyalty Points (Rule 8: 1 pt per RM1)
    UPDATE CustomerOrder 
    SET OrderStatus = 'Completed'
    WHERE OrderID = p_order_id;

    p_points_awarded := TRUNC(p_amount_paid);

    UPDATE Member 
    SET MemberPoint = MemberPoint + p_points_awarded
    WHERE MemberID = v_member_id;

    COMMIT;
    p_status_msg := 'SUCCESS: Payment #' || p_payment_id || ' settled (RM ' || 
                    TO_CHAR(p_amount_paid, 'FM999,990.00') || '). Awarded ' || 
                    p_points_awarded || ' loyalty points to Member #' || v_member_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Order ID #' || p_order_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20036, p_status_msg);

    WHEN e_order_not_pending THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Order #' || p_order_id || ' is already completed or cancelled.';
        RAISE_APPLICATION_ERROR(-20037, p_status_msg);

    WHEN e_invalid_method THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Invalid payment method. Must be Cash, Card, E-Wallet, or Online Banking.';
        RAISE_APPLICATION_ERROR(-20038, p_status_msg);

    WHEN e_underpayment THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Amount paid (RM ' || TO_CHAR(p_amount_paid, 'FM990.00') || 
                        ') is less than net payable amount (RM ' || TO_CHAR(v_net_payable, 'FM990.00') || ').';
        RAISE_APPLICATION_ERROR(-20039, p_status_msg);

    WHEN e_duplicate_txn THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Transaction No ' || p_transaction_no || ' has already been processed.';
        RAISE_APPLICATION_ERROR(-20040, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20041, p_status_msg);
END sp_settle_order_payment;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 1: sp_create_pickup_order
PROMPT ============================================================================

DECLARE
    v_ord_id NUMBER;
    v_code   VARCHAR2(20);
    v_msg    VARCHAR2(400);
BEGIN
    -- Test 1: Successful Pickup Order Booking
    sp_create_pickup_order(
        p_member_id   => 1,
        p_branch_id   => 1,
        p_pickup_date => SYSDATE + 1,
        p_order_id    => v_ord_id,
        p_pickup_code => v_code,
        p_status_msg  => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Settle Payment for the newly created order
    DECLARE
        v_pay_id NUMBER;
        v_pts    NUMBER;
    BEGIN
        sp_settle_order_payment(
            p_order_id       => v_ord_id,
            p_payment_method => 'E-Wallet',
            p_amount_paid    => 55.50,
            p_transaction_no => 'TXN-EW-DEMO-' || v_ord_id,
            p_payment_id     => v_pay_id,
            p_points_awarded => v_pts,
            p_status_msg     => v_msg
        );
        DBMS_OUTPUT.PUT_LINE(v_msg);
    END;
END;
/
