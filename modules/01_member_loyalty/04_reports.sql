-- ============================================================================
-- MODULE 1: MEMBER & LOYALTY MANAGEMENT
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 1
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 1: MEMBER & LOYALTY MANAGEMENT - MANAGEMENT REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_member_annual_statement
-- CLASSIFICATION: On-Demand Detail Statement
-- COMPLEXITY: Parameterized Nested Cursors (Parent Member -> Child Orders -> Child Redemptions)
-- SCENARIO: Customer service or branch managers generate a comprehensive 12-month
--   loyalty activity statement detailing orders placed, points accrued, and vouchers redeemed.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_member_annual_statement (
    p_member_id IN NUMBER
) AS
    -- 1. Parent Cursor: Member Profile
    CURSOR c_member IS
        SELECT 
            m.MemberID, m.Name, m.Email, m.PhoneNo,
            m.MembershipType, m.MemberPoint, m.JoinDate,
            m.ExpiryDate, m.MemberStatus
        FROM Member m
        WHERE m.MemberID = p_member_id;

    -- 2. Parameterized Child Cursor 1: Completed Orders in the past 12 months
    CURSOR c_orders(p_mid NUMBER) IS
        SELECT 
            co.OrderID,
            co.OrderDate,
            b.BranchName,
            NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) AS OrderTotal,
            p.PaymentMethod,
            p.PaymentStatus
        FROM CustomerOrder co
        JOIN Branch b ON co.BranchID = b.BranchID
        LEFT JOIN OrderDetail od ON co.OrderID = od.OrderID
        LEFT JOIN Payment p ON co.OrderID = p.OrderID
        WHERE co.MemberID = p_mid
          AND co.OrderDate >= ADD_MONTHS(SYSDATE, -12)
        GROUP BY co.OrderID, co.OrderDate, b.BranchName, p.PaymentMethod, p.PaymentStatus
        ORDER BY co.OrderDate DESC;

    -- 3. Parameterized Child Cursor 2: Point Redemptions
    CURSOR c_redemptions(p_mid NUMBER) IS
        SELECT 
            pr.PointRedemptionID,
            pr.RedemptionDate,
            v.VoucherName,
            v.VoucherType,
            v.DiscountValue,
            pr.PointUsed,
            pr.RedemptionStatus,
            pr.OrderID
        FROM PointRedemption pr
        JOIN Voucher v ON pr.VoucherID = v.VoucherID
        WHERE pr.MemberID = p_mid
        ORDER BY pr.RedemptionDate DESC;

    v_mem c_member%ROWTYPE;
    v_order_count NUMBER := 0;
    v_total_spent NUMBER := 0;
    v_points_burned NUMBER := 0;
    v_redemp_count NUMBER := 0;
BEGIN
    OPEN c_member;
    FETCH c_member INTO v_mem;

    IF c_member%NOTFOUND THEN
        CLOSE c_member;
        DBMS_OUTPUT.PUT_LINE('Error: Member ID ' || p_member_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_member;

    -- Header Output
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE('               88 SPEEDMART - MEMBER ANNUAL LOYALTY & REWARD STATEMENT');
    DBMS_OUTPUT.PUT_LINE('                          Statement Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE(' Member ID    : ' || RPAD(v_mem.MemberID, 10) || ' Name        : ' || v_mem.Name);
    DBMS_OUTPUT.PUT_LINE(' Email        : ' || RPAD(v_mem.Email, 30) || ' Phone       : ' || NVL(v_mem.PhoneNo, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(' Membership   : ' || RPAD(v_mem.MembershipType, 10) || ' Status      : ' || RPAD(v_mem.MemberStatus, 15) || ' Points: ' || v_mem.MemberPoint);
    DBMS_OUTPUT.PUT_LINE(' Member Since : ' || TO_CHAR(v_mem.JoinDate, 'YYYY-MM-DD') || ' Expiry Date : ' || NVL(TO_CHAR(v_mem.ExpiryDate, 'YYYY-MM-DD'), 'LIFETIME (Free)'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));

    -- Child Section 1: Order Transactions
    DBMS_OUTPUT.PUT_LINE(' SECTION 1: ORDER TRANSACTIONS (PAST 12 MONTHS)');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Order ID', 10) || 
        RPAD('Date', 12) || 
        RPAD('Branch Outlet', 28) || 
        RPAD('Payment Method', 18) || 
        RPAD('Status', 12) || 
        LPAD('Total (RM)', 15)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));

    FOR ord IN c_orders(v_mem.MemberID) LOOP
        v_order_count := v_order_count + 1;
        v_total_spent := v_total_spent + ord.OrderTotal;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(ord.OrderID, 10) || 
            RPAD(TO_CHAR(ord.OrderDate, 'YYYY-MM-DD'), 12) || 
            RPAD(SUBSTR(ord.BranchName, 1, 26), 28) || 
            RPAD(NVL(ord.PaymentMethod, 'Pending'), 18) || 
            RPAD(NVL(ord.PaymentStatus, 'Unpaid'), 12) || 
            LPAD(TO_CHAR(ord.OrderTotal, 'FM999,990.00'), 15)
        );
    END LOOP;

    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No order transactions recorded within the past 12 months.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(' Total Completed Orders: ' || RPAD(v_order_count, 6) || 
                         ' Cumulative Spend: RM ' || TO_CHAR(v_total_spent, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));

    -- Child Section 2: Loyalty Redemptions
    DBMS_OUTPUT.PUT_LINE(' SECTION 2: VOUCHER & POINTS REDEMPTION HISTORY');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Redemp ID', 12) || 
        RPAD('Date', 12) || 
        RPAD('Voucher Campaign', 30) || 
        RPAD('Discount', 12) || 
        RPAD('Points Used', 14) || 
        RPAD('Status', 15)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));

    FOR rdm IN c_redemptions(v_mem.MemberID) LOOP
        v_redemp_count := v_redemp_count + 1;
        v_points_burned := v_points_burned + rdm.PointUsed;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(rdm.PointRedemptionID, 12) || 
            RPAD(TO_CHAR(rdm.RedemptionDate, 'YYYY-MM-DD'), 12) || 
            RPAD(SUBSTR(rdm.VoucherName, 1, 28), 30) || 
            RPAD('RM ' || TO_CHAR(rdm.DiscountValue, 'FM990.00'), 12) || 
            RPAD(rdm.PointUsed, 14) || 
            RPAD(rdm.RedemptionStatus, 15)
        );
    END LOOP;

    IF v_redemp_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No point redemption records found for this member.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 95, '-'));
    DBMS_OUTPUT.PUT_LINE(' Total Redemptions Claimed: ' || RPAD(v_redemp_count, 6) || 
                         ' Total Loyalty Points Liquidated: ' || v_points_burned || ' pts');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 95, '='));
    DBMS_OUTPUT.PUT_LINE(' [END OF ANNUAL STATEMENT - 88 SPEEDMART LOYALTY SYSTEM]');
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_member_annual_statement;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_voucher_performance_summary
-- CLASSIFICATION: Periodic Summary Report
-- COMPLEXITY: Parameterized Nested Cursors (Parent Voucher Catalog -> Child Member Redemptions)
-- SCENARIO: Marketing executives review campaign-level point liquidation, total discounts
--   awarded, and branch order attribution across voucher programs.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_voucher_performance_summary (
    p_voucher_type IN VARCHAR2 DEFAULT NULL
) AS
    -- 1. Parent Cursor: Active and Historical Voucher Campaigns
    CURSOR c_vouchers IS
        SELECT 
            v.VoucherID, v.VoucherName, v.VoucherType,
            v.DiscountValue, v.MinimumSpend, v.RequiredPoint,
            v.StartDate, v.ExpiryDate, v.VoucherStatus
        FROM Voucher v
        WHERE (p_voucher_type IS NULL OR UPPER(v.VoucherType) = UPPER(TRIM(p_voucher_type)))
        ORDER BY v.VoucherID ASC;

    -- 2. Parameterized Child Cursor: Member Redemptions under this specific Voucher
    CURSOR c_voucher_claims(p_vid NUMBER) IS
        SELECT 
            pr.PointRedemptionID,
            pr.RedemptionDate,
            m.MemberID,
            m.Name AS MemberName,
            m.MembershipType,
            pr.PointUsed,
            pr.OrderID,
            pr.RedemptionStatus
        FROM PointRedemption pr
        JOIN Member m ON pr.MemberID = m.MemberID
        WHERE pr.VoucherID = p_vid
        ORDER BY pr.RedemptionDate DESC;

    v_grand_redemptions NUMBER := 0;
    v_grand_points      NUMBER := 0;
    v_voucher_claim_cnt NUMBER := 0;
    v_voucher_pts_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('                 88 SPEEDMART - VOUCHER CAMPAIGN UTILIZATION & ROI REPORT');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    IF p_voucher_type IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('                              Filtered Voucher Type: ' || UPPER(p_voucher_type));
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));

    FOR vch IN c_vouchers LOOP
        v_voucher_claim_cnt := 0;
        v_voucher_pts_total := 0;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(' CAMPAIGN: [' || vch.VoucherID || '] ' || vch.VoucherName || ' (' || vch.VoucherType || ')');
        DBMS_OUTPUT.PUT_LINE(' Terms   : Discount: RM ' || TO_CHAR(vch.DiscountValue, 'FM990.00') || 
                             ' | Min Spend: RM ' || TO_CHAR(vch.MinimumSpend, 'FM990.00') || 
                             ' | Required Points: ' || vch.RequiredPoint || ' pts');
        DBMS_OUTPUT.PUT_LINE(' Window  : ' || TO_CHAR(vch.StartDate, 'YYYY-MM-DD') || ' to ' || 
                             TO_CHAR(vch.ExpiryDate, 'YYYY-MM-DD') || ' | Status: ' || vch.VoucherStatus);
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('  Redemp ID', 13) || 
            RPAD('Date', 12) || 
            RPAD('Member Name (ID)', 30) || 
            RPAD('Tier', 8) || 
            RPAD('Order ID', 12) || 
            RPAD('Points Used', 14) || 
            RPAD('Status', 16)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

        FOR claim IN c_voucher_claims(vch.VoucherID) LOOP
            v_voucher_claim_cnt := v_voucher_claim_cnt + 1;
            v_voucher_pts_total := v_voucher_pts_total + claim.PointUsed;

            DBMS_OUTPUT.PUT_LINE(
                RPAD('  ' || claim.PointRedemptionID, 13) || 
                RPAD(TO_CHAR(claim.RedemptionDate, 'YYYY-MM-DD'), 12) || 
                RPAD(SUBSTR(claim.MemberName || ' (#' || claim.MemberID || ')', 1, 28), 30) || 
                RPAD(claim.MembershipType, 8) || 
                RPAD(claim.OrderID, 12) || 
                RPAD(claim.PointUsed || ' pts', 14) || 
                RPAD(claim.RedemptionStatus, 16)
            );
        END LOOP;

        IF v_voucher_claim_cnt = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  >>> No customer claims recorded for this campaign.');
        ELSE
            DBMS_OUTPUT.PUT_LINE(RPAD('.', 105, '.'));
            DBMS_OUTPUT.PUT_LINE('  >> Campaign Subtotal: ' || v_voucher_claim_cnt || ' claims | ' || 
                                 v_voucher_pts_total || ' points burned.');
        END IF;

        v_grand_redemptions := v_grand_redemptions + v_voucher_claim_cnt;
        v_grand_points      := v_grand_points + v_voucher_pts_total;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' EXECUTIVE SUMMARY TOTALS:');
    DBMS_OUTPUT.PUT_LINE(' Total Redemptions Across All Campaigns : ' || v_grand_redemptions);
    DBMS_OUTPUT.PUT_LINE(' Total Customer Loyalty Points Liquidated: ' || v_grand_points || ' pts');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
END sp_rpt_voucher_performance_summary;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_member_annual_statement (Member ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_member_annual_statement(1);

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_voucher_performance_summary
PROMPT ============================================================================
EXEC sp_rpt_voucher_performance_summary;
