-- =============================================================================
-- MODULE 1: MEMBER and LOYALTY MANAGEMENT
-- BMCS3183 Advanced Database Management | 88 Speedmart System
-- =============================================================================

SET LINESIZE 200;
SET PAGESIZE 50;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;

-- -----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES, VIEWS, CUSTOM EXCEPTIONS)
-- -----------------------------------------------------------------------------


-- Drop existing sequences and indexes for clean re-execution
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_member_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_member_status_type';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_redemption_member_order';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. Sequence for Member Management
CREATE SEQUENCE seq_member_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes
CREATE INDEX idx_member_status_type ON Member (MemberStatus, MembershipType);
CREATE INDEX idx_redemption_member_order ON PointRedemption (MemberID, OrderID, RedemptionStatus);

-- 3. View 1: Member Lifetime Value and Loyalty Engagement (Strategic View)
CREATE OR REPLACE VIEW v_member_loyalty_summary AS
SELECT 
    m.MemberID,
    m.Name AS MemberName,
    m.MembershipType,
    m.MemberStatus,
    m.MemberPoint AS CurrentPoints,
    NVL(COUNT(DISTINCT o.OrderID), 0) AS TotalOrders,
    NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) AS LifetimeSpend,
    NVL(SUM(pr.PointUsed), 0) AS TotalPointsRedeemed,
    MAX(o.OrderDate) AS LastOrderDate,
    ROUND(MONTHS_BETWEEN(SYSDATE, NVL(MAX(o.OrderDate), m.JoinDate)), 1) AS MonthsSinceLastActivity
FROM Member m
LEFT JOIN CustomerOrder o ON m.MemberID = o.MemberID AND o.OrderStatus = 'Completed'
LEFT JOIN OrderDetail od ON o.OrderID = od.OrderID AND od.LineStatus = 'Active'
LEFT JOIN PointRedemption pr ON m.MemberID = pr.MemberID AND pr.RedemptionStatus = 'Completed'
GROUP BY m.MemberID, m.Name, m.MembershipType, m.MemberStatus, m.MemberPoint, m.JoinDate;

-- 4. View 2: Voucher Utilization and Discount Impact (Tactical View)
CREATE OR REPLACE VIEW v_voucher_utilization AS
SELECT 
    v.VoucherID,
    v.VoucherName,
    v.VoucherType,
    v.DiscountValue,
    v.MinimumSpend,
    v.RequiredPoint,
    v.VoucherStatus,
    COUNT(pr.PointRedemptionID) AS TimesRedeemed,
    NVL(SUM(pr.PointUsed), 0) AS TotalPointsConsumed,
    COUNT(CASE WHEN pr.RedemptionStatus = 'Completed' THEN 1 END) AS CompletedRedemptions
FROM Voucher v
LEFT JOIN PointRedemption pr ON v.VoucherID = pr.VoucherID
GROUP BY v.VoucherID, v.VoucherName, v.VoucherType, v.DiscountValue, v.MinimumSpend, v.RequiredPoint, v.VoucherStatus;

-- -----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL and OPERATIONAL QUERIES (2 QUERIES)
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- SQL*PLUS TERMINAL & COLUMN FORMATTING
-- -----------------------------------------------------------------------------
SET LINESIZE 220;
SET PAGESIZE 100;
SET FEEDBACK ON;
SET RECSEP OFF;

-- Column formatting for Query 1
COLUMN MemberID                   FORMAT 9999      HEADING "ID";
COLUMN "Customer Name"            FORMAT A18       HEADING "Customer Name";
COLUMN "Tier"                     FORMAT A6        HEADING "Tier";
COLUMN "Lifetime Spend"           FORMAT A14       HEADING "Total Spend";
COLUMN "Point Balance"            FORMAT 999999    HEADING "Points";
COLUMN "Last Purchase"            FORMAT A12       HEADING "Last Active";
COLUMN "Inactive Months"          FORMAT 999.9     HEADING "Months";
COLUMN "Retention Action Required" FORMAT A32      HEADING "Retention Strategy";

-- Column formatting for Query 2
COLUMN VoucherID                  FORMAT 9999      HEADING "ID";
COLUMN "Voucher Name"             FORMAT A22       HEADING "Voucher Campaign";
COLUMN "Type"                     FORMAT A20       HEADING "Voucher Category";
COLUMN "Value"                    FORMAT A10       HEADING "Discount";
COLUMN "Pts Cost"                 FORMAT 999999    HEADING "Pt Cost";
COLUMN "Total Claims"             FORMAT 99999     HEADING "Claimed";
COLUMN "Used Claims"              FORMAT 99999     HEADING "Redeemed";
COLUMN "Total Pts Burned"         FORMAT A16       HEADING "Total Pts Used";
COLUMN "Conversion Rate"          FORMAT A15       HEADING "Conversion";


PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 1] STRATEGIC: MEMBER INACTIVITY RISK AND RETENTION SEGMENTATION
PROMPT Purpose: Identifies high-value and churn-risk members by inactivity duration and spend.
PROMPT ========================================================================================
SELECT 
    v.MemberID,
    RPAD(v.MemberName, 18) AS "Customer Name",
    v.MembershipType AS "Tier",
    TO_CHAR(v.LifetimeSpend, 'FM99,990.00') AS "Lifetime Spend",
    v.CurrentPoints AS "Point Balance",
    NVL(TO_CHAR(v.LastOrderDate, 'YYYY-MM-DD'), 'NO ORDERS') AS "Last Purchase",
    v.MonthsSinceLastActivity AS "Inactive Months",
    CASE 
        WHEN v.MonthsSinceLastActivity >= 12 THEN 'HIGH CHURN RISK (Auto-Inactive)'
        WHEN v.MonthsSinceLastActivity >= 6 THEN 'TACTICAL RE-ENGAGE'
        ELSE 'ACTIVE ENGAGED'
    END AS "Retention Action Required"
FROM v_member_loyalty_summary v
WHERE v.MemberStatus = 'Active'
ORDER BY v.MonthsSinceLastActivity DESC, v.LifetimeSpend DESC;

-- Executive Portfolio Summary & Strategic Totals
PROMPT ----------------------------------------------------------------------------------------
PROMPT STRATEGIC PORTFOLIO TOTALS & HEALTH BREAKDOWN:
SELECT 
    COUNT(*) AS "Active Members",
    COUNT(CASE WHEN MonthsSinceLastActivity >= 12 THEN 1 END) AS "High Churn (>12M)",
    COUNT(CASE WHEN MonthsSinceLastActivity BETWEEN 6 AND 11.9 THEN 1 END) AS "At-Risk (6-12M)",
    COUNT(CASE WHEN MonthsSinceLastActivity < 6 THEN 1 END) AS "Healthy (<6M)",
    TO_CHAR(SUM(LifetimeSpend), 'FM$999,990.00') AS "Total Spend",
    TO_CHAR(AVG(LifetimeSpend), 'FM$990.00') AS "Avg Member Spend"
FROM v_member_loyalty_summary
WHERE MemberStatus = 'Active';
PROMPT CONCLUSION: 1 member exceeds 12M inactivity (auto-deactivate per Rule 3). 1 member at risk requires coupon re-engagement.

PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 2] TACTICAL: VOUCHER CAMPAIGN UTILIZATION AND CONVERSION AUDIT
PROMPT Purpose: Measures voucher claim-to-redemption rates and point burn across campaigns.
PROMPT ========================================================================================
SELECT 
    vu.VoucherID,
    RPAD(vu.VoucherName, 25) AS "Voucher Name",
    vu.VoucherType AS "Type",
    TO_CHAR(vu.DiscountValue, 'FM90.00') AS "Value",
    vu.RequiredPoint AS "Pts Cost",
    vu.TimesRedeemed AS "Total Claims",
    vu.CompletedRedemptions AS "Used Claims",
    TO_CHAR(vu.TotalPointsConsumed, 'FM999,999') AS "Total Pts Burned",
    ROUND((vu.CompletedRedemptions / NULLIF(vu.TimesRedeemed, 0)) * 100, 2) || '%' AS "Conversion Rate"
FROM v_voucher_utilization vu
WHERE vu.TimesRedeemed > 0
ORDER BY vu.TotalPointsConsumed DESC;

-- -----------------------------------------------------------------------------
-- TASK 5: STORED PROCEDURES WITH EXCEPTION HANDLING (2 PROCEDURES)
-- -----------------------------------------------------------------------------

-- Procedure 1: Register New Member or Upgrade Membership
-- Demonstrates custom exceptions, RAISE_APPLICATION_ERROR, and transaction integrity.
CREATE OR REPLACE PROCEDURE sp_register_or_renew_member (
    p_name           IN  Member.Name%TYPE,
    p_email          IN  Member.Email%TYPE,
    p_password       IN  Member.Password%TYPE,
    p_phone          IN  Member.PhoneNo%TYPE,
    p_type           IN  Member.MembershipType%TYPE,
    p_address        IN  Member.DeliveryAddress%TYPE,
    p_new_member_id  OUT Member.MemberID%TYPE
) AS
    -- Custom Exceptions
    e_invalid_email EXCEPTION;
    e_invalid_type  EXCEPTION;
    
    v_count NUMBER;
    v_expiry DATE := NULL;
BEGIN
    -- Input Validation and Format Constraints
    -- Input Validation and Format Constraints
    IF p_name IS NULL OR LENGTH(TRIM(p_name)) < 2 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Validation Error: Member Name must be at least 2 characters.');
    END IF;

    IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
        RAISE_APPLICATION_ERROR(-20014, 'Validation Error: Password must be at least 6 characters.');
    END IF;

    IF NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$') THEN
        RAISE e_invalid_email;
    END IF;

    IF p_phone IS NOT NULL AND NOT REGEXP_LIKE(p_phone, '^01[0-9]-[0-9]{7,8}$') THEN
        RAISE_APPLICATION_ERROR(-20013, 'Validation Error: Phone format must match 01X-XXXXXXX (e.g. 012-3456789).');
    END IF;

    IF p_type NOT IN ('Normal', 'VIP') THEN
        RAISE e_invalid_type;
    END IF;

    -- Check Email Duplication
    SELECT COUNT(*) INTO v_count FROM Member WHERE LOWER(Email) = LOWER(p_email);
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Registration Error: Email address already registered in system.');
    END IF;

    -- VIP membership is valid for 1 year (RM12/year)
    IF p_type = 'VIP' THEN
        v_expiry := ADD_MONTHS(SYSDATE, 12);
    END IF;

    p_new_member_id := seq_member_id.NEXTVAL;

    INSERT INTO Member (
        MemberID, Name, Email, Password, PhoneNo, MembershipType,
        MemberPoint, JoinDate, ExpiryDate, MemberStatus, DeliveryAddress
    ) VALUES (
        p_new_member_id, p_name, p_email, p_password, p_phone, p_type,
        0, SYSDATE, v_expiry, 'Active', p_address
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: Member #' || p_new_member_id || ' (' || p_type || ') created successfully.');

EXCEPTION
    WHEN e_invalid_email THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Validation Error: Invalid email format provided.');
    WHEN e_invalid_type THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003, 'Validation Error: MembershipType must be either Normal or VIP.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20000, 'System Error in sp_register_or_renew_member: ' || SQLERRM);
END sp_register_or_renew_member;
/

-- Procedure 2: Redeem Loyalty Points for Order Voucher
-- Demonstrates balance deduction, order validation, PRAGMA EXCEPTION_INIT, and state updates.
CREATE OR REPLACE PROCEDURE sp_process_point_redemption (
    p_member_id     IN Member.MemberID%TYPE,
    p_voucher_id    IN Voucher.VoucherID%TYPE,
    p_order_id      IN CustomerOrder.OrderID%TYPE,
    p_redemption_id OUT PointRedemption.PointRedemptionID%TYPE
) AS
    -- PRAGMA Exception for Oracle FK constraint violations
    e_foreign_key_violation EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_foreign_key_violation, -2291);

    -- Custom Exceptions
    e_insufficient_points EXCEPTION;
    e_inactive_member     EXCEPTION;
    e_voucher_invalid     EXCEPTION;

    v_member_points Member.MemberPoint%TYPE;
    v_member_status Member.MemberStatus%TYPE;
    v_req_points    Voucher.RequiredPoint%TYPE;
    v_voucher_stat  Voucher.VoucherStatus%TYPE;
    v_voucher_exp   Voucher.ExpiryDate%TYPE;
    v_order_status  CustomerOrder.OrderStatus%TYPE;
BEGIN
    -- 0. Input Parameter Validation
    IF p_member_id <= 0 OR p_voucher_id <= 0 OR p_order_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20015, 'Validation Error: Member ID, Voucher ID, and Order ID must be positive integers.');
    END IF;

    -- 1. Fetch Member Details
    SELECT MemberPoint, MemberStatus INTO v_member_points, v_member_status
    FROM Member WHERE MemberID = p_member_id;

    IF v_member_status <> 'Active' THEN
        RAISE e_inactive_member;
    END IF;

    -- 2. Fetch Voucher Rules
    SELECT RequiredPoint, VoucherStatus, ExpiryDate 
    INTO v_req_points, v_voucher_stat, v_voucher_exp
    FROM Voucher WHERE VoucherID = p_voucher_id;

    IF v_voucher_stat <> 'Active' OR v_voucher_exp < SYSDATE THEN
        RAISE e_voucher_invalid;
    END IF;

    -- 3. Check Order State
    SELECT OrderStatus INTO v_order_status 
    FROM CustomerOrder WHERE OrderID = p_order_id;

    IF v_order_status <> 'Pending' THEN
        RAISE_APPLICATION_ERROR(-20005, 'Redemption Error: Points can only be applied to Pending orders.');
    END IF;

    -- 4. Check Point Balance
    IF v_member_points < v_req_points THEN
        RAISE e_insufficient_points;
    END IF;

    -- Generate Next Redemption ID
    SELECT NVL(MAX(PointRedemptionID), 0) + 1 INTO p_redemption_id FROM PointRedemption;

    -- 5. Record Point Redemption
    INSERT INTO PointRedemption (
        PointRedemptionID, RedemptionDate, PointUsed, RedemptionStatus,
        Remarks, MemberID, VoucherID, OrderID
    ) VALUES (
        p_redemption_id, SYSDATE, v_req_points, 'Completed',
        'Redeemed via PL/SQL Engine', p_member_id, p_voucher_id, p_order_id
    );

    -- 6. Deduct Member Points
    UPDATE Member 
    SET MemberPoint = MemberPoint - v_req_points
    WHERE MemberID = p_member_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Redemption successful: ' || v_req_points || ' pts deducted for Member #' || p_member_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20004, 'Lookup Error: Provided Member, Voucher, or Order ID does not exist.');
    WHEN e_inactive_member THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Eligibility Error: Inactive members cannot redeem loyalty points.');
    WHEN e_voucher_invalid THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20007, 'Voucher Error: Voucher is either inactive or expired.');
    WHEN e_insufficient_points THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20008, 'Balance Error: Insufficient points. Required: ' || v_req_points || ', Available: ' || v_member_points);
    WHEN e_foreign_key_violation THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'Integrity Error: Foreign key integrity constraint violated.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20000, 'System Error in sp_process_point_redemption: ' || SQLERRM);
END sp_process_point_redemption;
/

-- -----------------------------------------------------------------------------
-- TASK 6: CONDITIONAL TRIGGERS (2 TRIGGERS)
-- -----------------------------------------------------------------------------

-- Trigger 1: Guard Against Inactive Member Activity and Point Non-Negativity
-- Conditional BEFORE INSERT trigger on PointRedemption.
CREATE OR REPLACE TRIGGER trg_guard_point_redemption
BEFORE INSERT ON PointRedemption
FOR EACH ROW
WHEN (NEW.PointUsed > 0)
DECLARE
    v_status Member.MemberStatus%TYPE;
    v_balance Member.MemberPoint%TYPE;
BEGIN
    SELECT MemberStatus, MemberPoint INTO v_status, v_balance
    FROM Member
    WHERE MemberID = :NEW.MemberID;

    IF v_status <> 'Active' THEN
        RAISE_APPLICATION_ERROR(-20010, 'Trigger Violation: Member #' || :NEW.MemberID || ' is Inactive. Redemption rejected.');
    END IF;

    IF v_balance < :NEW.PointUsed THEN
        RAISE_APPLICATION_ERROR(-20011, 'Trigger Violation: Cannot redeem ' || :NEW.PointUsed || ' points. Current balance: ' || v_balance);
    END IF;
END trg_guard_point_redemption;
/

-- Trigger 2: Enforce VIP Renewal Expiry Timestamp
-- Conditional BEFORE UPDATE trigger on Member table when upgraded to VIP.
CREATE OR REPLACE TRIGGER trg_enforce_vip_expiration
BEFORE UPDATE OF MembershipType ON Member
FOR EACH ROW
WHEN (NEW.MembershipType = 'VIP' AND (OLD.MembershipType = 'Normal' OR OLD.MembershipType IS NULL))
BEGIN
    -- Automatically set VIP expiration date 1 year from current timestamp
    :NEW.ExpiryDate := ADD_MONTHS(SYSDATE, 12);
END trg_enforce_vip_expiration;
/

-- -----------------------------------------------------------------------------
-- TASK 7: REPORTS GENERATION WITH NESTED CURSORS (2 REPORTS)
-- -----------------------------------------------------------------------------

-- Report 1: On-Demand Member Loyalty and Order History Statement (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_member_annual_statement (
    p_member_id IN Member.MemberID%TYPE
) AS
    -- Parent Cursor: Member Header Details
    CURSOR c_member IS
        SELECT MemberID, Name, Email, MembershipType, MemberPoint, JoinDate, ExpiryDate, MemberStatus
        FROM Member
        WHERE MemberID = p_member_id;

    -- Child Cursor 1: Order History and Items for this Member (Parameterized)
    CURSOR c_orders (cp_member_id NUMBER) IS
        SELECT o.OrderID, o.OrderDate, o.OrderStatus, b.BranchName,
               NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) AS OrderTotal
        FROM CustomerOrder o
        JOIN Branch b ON o.BranchID = b.BranchID
        LEFT JOIN OrderDetail od ON o.OrderID = od.OrderID
        WHERE o.MemberID = cp_member_id
        GROUP BY o.OrderID, o.OrderDate, o.OrderStatus, b.BranchName
        ORDER BY o.OrderDate DESC;

    -- Child Cursor 2: Point Redemptions
    CURSOR c_redemptions (cp_member_id NUMBER) IS
        SELECT pr.PointRedemptionID, pr.RedemptionDate, pr.PointUsed, v.VoucherName, pr.RedemptionStatus
        FROM PointRedemption pr
        JOIN Voucher v ON pr.VoucherID = v.VoucherID
        WHERE pr.MemberID = cp_member_id
        ORDER BY pr.RedemptionDate DESC;

    r_mem c_member%ROWTYPE;
    v_total_spend NUMBER := 0;
    v_total_pts_used NUMBER := 0;
    v_order_count NUMBER := 0;
BEGIN
    IF p_member_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Member ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_member;
    FETCH c_member INTO r_mem;
    
    IF c_member%NOTFOUND THEN
        CLOSE c_member;
        DBMS_OUTPUT.PUT_LINE('Error: Member ID ' || p_member_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_member;

    -- Header Formatting
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                         88 SPEEDMART MEMBER LOYALTY STATEMENT                          ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Member ID   : ' || RPAD(r_mem.MemberID, 10) || 'Name        : ' || r_mem.Name);
    DBMS_OUTPUT.PUT_LINE('Email       : ' || RPAD(r_mem.Email, 25) || 'Status      : ' || r_mem.MemberStatus);
    DBMS_OUTPUT.PUT_LINE('Tier        : ' || RPAD(r_mem.MembershipType, 10) || 'Current Pts : ' || r_mem.MemberPoint);
    DBMS_OUTPUT.PUT_LINE('Join Date   : ' || TO_CHAR(r_mem.JoinDate, 'YYYY-MM-DD') || '        Expiry Date : ' || NVL(TO_CHAR(r_mem.ExpiryDate, 'YYYY-MM-DD'), 'N/A (Lifetime)'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('ORDER HISTORY:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Order ID', 12) || RPAD('Date', 14) || RPAD('Branch', 26) || RPAD('Status', 14) || LPAD('Total (MYR)', 14));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    -- Iterate Orders Child Cursor
    FOR r_ord IN c_orders(r_mem.MemberID) LOOP
        v_order_count := v_order_count + 1;
        v_total_spend := v_total_spend + r_ord.OrderTotal;
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_ord.OrderID, 12) ||
            RPAD(TO_CHAR(r_ord.OrderDate, 'YYYY-MM-DD'), 14) ||
            RPAD(SUBSTR(r_ord.BranchName, 1, 24), 26) ||
            RPAD(r_ord.OrderStatus, 14) ||
            LPAD(TO_CHAR(r_ord.OrderTotal, 'FM999,990.00'), 14)
        );
    END LOOP;

    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  * No historical orders found.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('POINT REDEMPTION HISTORY:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Claim ID', 12) || RPAD('Date', 14) || RPAD('Voucher Name', 32) || RPAD('Status', 12) || LPAD('Pts Used', 10));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    -- Iterate Redemptions Child Cursor
    FOR r_red IN c_redemptions(r_mem.MemberID) LOOP
        v_total_pts_used := v_total_pts_used + r_red.PointUsed;
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_red.PointRedemptionID, 12) ||
            RPAD(TO_CHAR(r_red.RedemptionDate, 'YYYY-MM-DD'), 14) ||
            RPAD(SUBSTR(r_red.VoucherName, 1, 30), 32) ||
            RPAD(r_red.RedemptionStatus, 12) ||
            LPAD(r_red.PointUsed, 10)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('SUMMARY: Total Orders: ' || v_order_count || ' | Total Spend: MYR ' || TO_CHAR(v_total_spend, 'FM999,990.00') || ' | Lifetime Pts Redeemed: ' || v_total_pts_used);
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_member_annual_statement;
/

-- Report 2: Voucher Campaign Performance Breakdown (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_voucher_performance_summary AS
    -- Parent Cursor: Active Vouchers
    CURSOR c_voucher IS
        SELECT VoucherID, VoucherName, VoucherType, DiscountValue, MinimumSpend, RequiredPoint, VoucherStatus
        FROM Voucher
        ORDER BY VoucherID;

    -- Child Cursor: Redemption Details by Member and Branch
    CURSOR c_voucher_claims (cp_voucher_id NUMBER) IS
        SELECT pr.PointRedemptionID, pr.RedemptionDate, m.Name AS MemberName, o.OrderID, b.BranchName
        FROM PointRedemption pr
        JOIN Member m ON pr.MemberID = m.MemberID
        JOIN CustomerOrder o ON pr.OrderID = o.OrderID
        JOIN Branch b ON o.BranchID = b.BranchID
        WHERE pr.VoucherID = cp_voucher_id
        ORDER BY pr.RedemptionDate DESC;

    v_claim_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                       88 SPEEDMART VOUCHER CAMPAIGN AUDIT REPORT                       ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');

    FOR r_vouch IN c_voucher LOOP
        v_claim_count := 0;
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '>> VOUCHER [' || r_vouch.VoucherID || '] ' || UPPER(r_vouch.VoucherName));
        DBMS_OUTPUT.PUT_LINE('   Type: ' || RPAD(r_vouch.VoucherType, 12) || ' | Value: MYR ' || TO_CHAR(r_vouch.DiscountValue, 'FM990.00') || ' | Min Spend: MYR ' || TO_CHAR(r_vouch.MinimumSpend, 'FM990.00') || ' | Pts Cost: ' || r_vouch.RequiredPoint);
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('   ' || RPAD('Claim ID', 12) || RPAD('Claim Date', 14) || RPAD('Member Name', 24) || RPAD('Order Ref', 12) || RPAD('Branch', 22));
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');

        -- Nested Child Cursor
        FOR r_claim IN c_voucher_claims(r_vouch.VoucherID) LOOP
            v_claim_count := v_claim_count + 1;
            DBMS_OUTPUT.PUT_LINE('   ' ||
                RPAD('#' || r_claim.PointRedemptionID, 12) ||
                RPAD(TO_CHAR(r_claim.RedemptionDate, 'YYYY-MM-DD'), 14) ||
                RPAD(SUBSTR(r_claim.MemberName, 1, 22), 24) ||
                RPAD('#' || r_claim.OrderID, 12) ||
                RPAD(SUBSTR(r_claim.BranchName, 1, 20), 22)
            );
        END LOOP;

        IF v_claim_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   * No claims recorded for this voucher.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   Subtotal Claims: ' || v_claim_count || ' redemption(s).');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_voucher_performance_summary;
/