-- ============================================================================
-- MODULE 1: MEMBER & LOYALTY MANAGEMENT
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 1
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 1: MEMBER & LOYALTY MANAGEMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_register_or_renew_member
-- SCENARIO: Handles customer enrollment and VIP renewals. 
--   Business Rule 1: Normal Member is free; VIP Member is RM12/yr (12-month validity).
--   Business Rule 15: Single account per IC/Email.
--   Task 8 Features: Sequence (seq_member_id), Custom Exceptions, 
--                    RAISE_APPLICATION_ERROR, DUP_VAL_ON_INDEX.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_register_or_renew_member (
    p_name            IN  VARCHAR2,
    p_email           IN  VARCHAR2,
    p_password        IN  VARCHAR2,
    p_phone_no        IN  VARCHAR2,
    p_membership_type IN  VARCHAR2,
    p_delivery_addr   IN  VARCHAR2,
    p_new_member_id   OUT NUMBER,
    p_status_msg      OUT VARCHAR2
) AS
    -- User-defined exceptions
    e_invalid_email EXCEPTION;
    e_invalid_type  EXCEPTION;
    e_empty_name    EXCEPTION;

    v_calc_expiry DATE := NULL;
    v_existing_cnt NUMBER := 0;
BEGIN
    -- 1. Validate Input Parameters
    IF TRIM(p_name) IS NULL THEN
        RAISE e_empty_name;
    END IF;

    IF NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$') THEN
        RAISE e_invalid_email;
    END IF;

    IF UPPER(TRIM(p_membership_type)) NOT IN ('NORMAL', 'VIP') THEN
        RAISE e_invalid_type;
    END IF;

    -- 2. Check for duplicate email registration
    SELECT COUNT(*) INTO v_existing_cnt 
    FROM Member 
    WHERE UPPER(Email) = UPPER(TRIM(p_email));

    IF v_existing_cnt > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Registration Rejected: Email address ' || p_email || ' is already registered.');
    END IF;

    -- 3. Calculate Expiration Date for VIP (Rule 1: 1 Year validity)
    IF UPPER(TRIM(p_membership_type)) = 'VIP' THEN
        v_calc_expiry := ADD_MONTHS(SYSDATE, 12);
    ELSE
        v_calc_expiry := NULL; -- Normal members have lifetime validity
    END IF;

    -- 4. Generate ID via Sequence and Insert Record
    p_new_member_id := seq_member_id.NEXTVAL;

    INSERT INTO Member (
        MemberID, Name, Email, Password, PhoneNo,
        MembershipType, MemberPoint, JoinDate, ExpiryDate,
        MemberStatus, DeliveryAddress
    ) VALUES (
        p_new_member_id,
        TRIM(p_name),
        LOWER(TRIM(p_email)),
        p_password,
        TRIM(p_phone_no),
        UPPER(TRIM(p_membership_type)),
        0,              -- Initial points
        SYSDATE,        -- Join date
        v_calc_expiry,  -- Expiry date
        'Active',
        TRIM(p_delivery_addr)
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Member registered successfully with ID ' || p_new_member_id || 
                    ' (' || UPPER(TRIM(p_membership_type)) || ' tier).';

EXCEPTION
    WHEN e_empty_name THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Member name cannot be blank.';
        RAISE_APPLICATION_ERROR(-20002, p_status_msg);

    WHEN e_invalid_email THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Invalid email format: ' || p_email;
        RAISE_APPLICATION_ERROR(-20003, p_status_msg);

    WHEN e_invalid_type THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Membership type must be either NORMAL or VIP.';
        RAISE_APPLICATION_ERROR(-20004, p_status_msg);

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Database unique constraint collision during member registration.';
        RAISE_APPLICATION_ERROR(-20005, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20006, p_status_msg);
END sp_register_or_renew_member;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_process_point_redemption
-- SCENARIO: Processes checkout voucher point redemption.
--   Business Rules 7, 10, 11, 12: Points earned can be redeemed for vouchers;
--   only 1 voucher per order; pre-discount total must meet minimum spend.
--   Task 8 Features: PRAGMA EXCEPTION_INIT, User Exceptions, Row Locking.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_process_point_redemption (
    p_member_id        IN  NUMBER,
    p_voucher_id       IN  NUMBER,
    p_order_id         IN  NUMBER,
    p_redemption_id    OUT NUMBER,
    p_discount_applied OUT NUMBER
) AS
    -- PRAGMA Binding for Oracle Foreign Key integrity violation (ORA-02291)
    e_fk_violation EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fk_violation, -2291);

    -- Custom Business Exceptions
    e_insufficient_points EXCEPTION;
    e_inactive_member     EXCEPTION;
    e_invalid_order_state EXCEPTION;
    e_min_spend_unmet     EXCEPTION;
    e_voucher_expired     EXCEPTION;

    v_member_points NUMBER;
    v_member_status VARCHAR2(20);
    v_req_points    NUMBER;
    v_min_spend     NUMBER;
    v_vch_discount  NUMBER;
    v_vch_status    VARCHAR2(20);
    v_vch_expiry    DATE;
    v_order_status  VARCHAR2(20);
    v_order_subtotal NUMBER := 0;
BEGIN
    -- 1. Validate Member State and Lock Points Row
    SELECT MemberPoint, MemberStatus 
    INTO v_member_points, v_member_status
    FROM Member
    WHERE MemberID = p_member_id
    FOR UPDATE;

    IF v_member_status != 'Active' THEN
        RAISE e_inactive_member;
    END IF;

    -- 2. Validate Voucher Eligibility
    SELECT RequiredPoint, MinimumSpend, DiscountValue, VoucherStatus, ExpiryDate
    INTO v_req_points, v_min_spend, v_vch_discount, v_vch_status, v_vch_expiry
    FROM Voucher
    WHERE VoucherID = p_voucher_id;

    IF v_vch_status != 'Active' OR v_vch_expiry < SYSDATE THEN
        RAISE e_voucher_expired;
    END IF;

    IF v_member_points < v_req_points THEN
        RAISE e_insufficient_points;
    END IF;

    -- 3. Validate Order Eligibility & Pre-Discount Subtotal (Rule 12)
    SELECT OrderStatus INTO v_order_status
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_order_status != 'Pending' THEN
        RAISE e_invalid_order_state;
    END IF;

    SELECT NVL(SUM(Quantity * UnitPrice), 0)
    INTO v_order_subtotal
    FROM OrderDetail
    WHERE OrderID = p_order_id;

    IF v_order_subtotal < v_min_spend THEN
        RAISE e_min_spend_unmet;
    END IF;

    -- 4. Deduct Points & Record Redemption
    UPDATE Member 
    SET MemberPoint = MemberPoint - v_req_points
    WHERE MemberID = p_member_id;

    p_redemption_id := seq_member_id.NEXTVAL;

    INSERT INTO PointRedemption (
        PointRedemptionID, RedemptionDate, PointUsed,
        RedemptionStatus, Remarks, MemberID, VoucherID, OrderID
    ) VALUES (
        p_redemption_id,
        SYSDATE,
        v_req_points,
        'Completed',
        'Redeemed voucher at checkout. Subtotal: RM ' || TO_CHAR(v_order_subtotal, 'FM990.00'),
        p_member_id,
        p_voucher_id,
        p_order_id
    );

    p_discount_applied := v_vch_discount;
    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Redemption Failed: Member, Voucher, or Order ID does not exist.');

    WHEN e_inactive_member THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20012, 'Redemption Failed: Member account is Inactive.');

    WHEN e_insufficient_points THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20013, 'Redemption Failed: Insufficient points. Required: ' || 
                                v_req_points || ', Current Balance: ' || v_member_points);

    WHEN e_voucher_expired THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20014, 'Redemption Failed: Voucher is expired or inactive.');

    WHEN e_invalid_order_state THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20015, 'Redemption Failed: Points can only be applied to Pending orders.');

    WHEN e_min_spend_unmet THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20016, 'Redemption Failed: Order pre-discount total (RM ' || 
                                TO_CHAR(v_order_subtotal, 'FM990.00') || ') is less than required Minimum Spend (RM ' || 
                                TO_CHAR(v_min_spend, 'FM990.00') || ').');

    WHEN e_fk_violation THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20017, 'Redemption Failed: Foreign key constraint violation (ORA-02291).');

    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20018, 'Redemption Failed: System error - ' || SQLERRM);
END sp_process_point_redemption;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 1: sp_register_or_renew_member
PROMPT ============================================================================

DECLARE
    v_new_id NUMBER;
    v_msg    VARCHAR2(400);
BEGIN
    -- Test 1: Successful VIP Member Registration
    sp_register_or_renew_member(
        p_name            => 'Alexander Wright',
        p_email           => 'alex.wright.demo@speedmart88.my',
        p_password        => 'SecurePass#2026',
        p_phone_no        => '012-9876543',
        p_membership_type => 'VIP',
        p_delivery_addr   => 'No. 88, Jalan SS2/55, 47300 Petaling Jaya, Selangor',
        p_new_member_id   => v_new_id,
        p_status_msg      => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional Invalid Membership Type (Demonstrating Exception Handling)
    BEGIN
        sp_register_or_renew_member(
            p_name            => 'Invalid Tester',
            p_email           => 'tester.invalid@test.com',
            p_password        => '123456',
            p_phone_no        => '011-1234567',
            p_membership_type => 'GOLD_TIER', -- Invalid type
            p_delivery_addr   => 'Kuala Lumpur',
            p_new_member_id   => v_new_id,
            p_status_msg      => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception: ' || SQLERRM);
    END;
END;
/
