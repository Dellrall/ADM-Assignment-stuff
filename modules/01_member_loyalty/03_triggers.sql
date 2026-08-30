-- ============================================================================
-- MODULE 1: MEMBER & LOYALTY MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 1
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 1: MEMBER & LOYALTY MANAGEMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_point_redemption
-- SCENARIO: Enforces Business Rules 7 & 11 at database kernel level.
--   Prevents fraud or race conditions by rejecting point redemptions if:
--   1. The member status is 'Inactive'.
--   2. The member's current point balance is strictly less than :NEW.PointUsed.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_point_redemption
BEFORE INSERT ON PointRedemption
FOR EACH ROW
DECLARE
    v_curr_points NUMBER;
    v_status      VARCHAR2(20);
BEGIN
    -- Query member's live points and status
    SELECT MemberPoint, MemberStatus 
    INTO v_curr_points, v_status
    FROM Member
    WHERE MemberID = :NEW.MemberID;

    IF v_status != 'Active' THEN
        RAISE_APPLICATION_ERROR(-20011, 'Trigger Violation: Inactive member (ID: ' || 
                                :NEW.MemberID || ') is not permitted to redeem points.');
    END IF;

    IF v_curr_points < :NEW.PointUsed THEN
        RAISE_APPLICATION_ERROR(-20012, 'Trigger Violation: Member (ID: ' || :NEW.MemberID || 
                                ') has insufficient points (' || v_curr_points || 
                                ') for redemption of ' || :NEW.PointUsed || ' points.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20013, 'Trigger Violation: Member ID ' || :NEW.MemberID || ' not found.');
END trg_guard_point_redemption;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_enforce_vip_expiration
-- SCENARIO: Enforces Business Rules 1 & 13.
--   When a member's tier is updated to 'VIP', this trigger automatically 
--   computes and sets ExpiryDate to exactly 12 months from current date,
--   and ensures MemberStatus is active.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_enforce_vip_expiration
BEFORE UPDATE OF MembershipType ON Member
FOR EACH ROW
WHEN (NEW.MembershipType = 'VIP')
BEGIN
    :NEW.ExpiryDate   := ADD_MONTHS(SYSDATE, 12);
    :NEW.MemberStatus := 'Active';
END trg_enforce_vip_expiration;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_point_redemption
PROMPT ============================================================================

DECLARE
    v_test_mem_id NUMBER;
BEGIN
    -- 1. Setup a test member with 50 points
    SELECT MIN(MemberID) INTO v_test_mem_id FROM Member WHERE MemberStatus = 'Active';
    
    UPDATE Member SET MemberPoint = 50 WHERE MemberID = v_test_mem_id;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Test Member ID ' || v_test_mem_id || ' points set to 50.');

    -- 2. Attempt invalid redemption of 9999 points (Exceeds Balance)
    BEGIN
        INSERT INTO PointRedemption (
            PointRedemptionID, RedemptionDate, PointUsed,
            RedemptionStatus, Remarks, MemberID, VoucherID, OrderID
        ) VALUES (
            999901, SYSDATE, 9999, 'Pending', 'Test Fraud Trigger', v_test_mem_id, 1, 1
        );
        ROLLBACK;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection: ' || SQLERRM);
            ROLLBACK;
    END;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_enforce_vip_expiration
PROMPT ============================================================================

DECLARE
    v_test_mem_id NUMBER;
    v_expiry      DATE;
BEGIN
    SELECT MIN(MemberID) INTO v_test_mem_id 
    FROM Member 
    WHERE MembershipType = 'Normal';

    IF v_test_mem_id IS NOT NULL THEN
        -- Upgrade to VIP
        UPDATE Member 
        SET MembershipType = 'VIP'
        WHERE MemberID = v_test_mem_id;

        SELECT ExpiryDate INTO v_expiry FROM Member WHERE MemberID = v_test_mem_id;
        
        DBMS_OUTPUT.PUT_LINE('Member ID ' || v_test_mem_id || ' upgraded to VIP.');
        DBMS_OUTPUT.PUT_LINE('Auto-calculated Expiry Date by Trigger: ' || TO_CHAR(v_expiry, 'YYYY-MM-DD'));
        ROLLBACK; -- Clean up test
    END IF;
END;
/
