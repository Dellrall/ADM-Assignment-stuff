-- ============================================================================
-- MODULE 1: MEMBER & LOYALTY MANAGEMENT
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 1
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 1: MEMBER & LOYALTY MANAGEMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- >>> [TASK 8 EXTRA EFFORT: SEQUENCE]
-- 1. Sequence for Member Registration
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_member_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_member_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- >>> [TASK 8 EXTRA EFFORT: PERFORMANCE INDEXES]
-- 2. Performance Indexes for Loyalty & Redemption Analytics
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_member_status_type';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_member_status_type 
    ON Member(MemberStatus, MembershipType, JoinDate);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_redemption_member_order';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_redemption_member_order 
    ON PointRedemption(MemberID, OrderID, RedemptionStatus);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_member_churn_risk
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 1 -> v_member_churn_risk]
-- SCENARIO: The Chief Marketing Officer (CMO) requires an enterprise-level
--   churn and inactivity risk matrix. Under Business Rule 14, members without 
--   order activity for 12 months are flagged 'Inactive'. This strategic query 
--   analyzes recency of purchase, unspent point liability, and lifetime spend
--   to classify members into actionable retention tiers.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_member_churn_risk AS
WITH MemberOrderSummary AS (
    SELECT 
        m.MemberID,
        m.Name AS MemberName,
        m.MembershipType,
        m.MemberStatus,
        m.MemberPoint,
        m.JoinDate,
        m.ExpiryDate,
        COUNT(co.OrderID) AS TotalOrders,
        NVL(MAX(co.OrderDate), m.JoinDate) AS LastOrderDate,
        ROUND(MONTHS_BETWEEN(SYSDATE, NVL(MAX(co.OrderDate), m.JoinDate)), 1) AS MonthsSinceLastActivity,
        NVL(SUM(CASE WHEN co.OrderStatus = 'Completed' THEN p.AmountPaid ELSE 0 END), 0) AS LifetimeSpend
    FROM Member m
    LEFT JOIN CustomerOrder co ON m.MemberID = co.MemberID
    LEFT JOIN Payment p ON co.OrderID = p.OrderID AND p.PaymentStatus = 'Paid'
    GROUP BY 
        m.MemberID, m.Name, m.MembershipType, m.MemberStatus, 
        m.MemberPoint, m.JoinDate, m.ExpiryDate
)
SELECT 
    MemberID,
    MemberName,
    MembershipType,
    MemberStatus,
    MemberPoint AS CurrentPoints,
    TotalOrders,
    TO_CHAR(LastOrderDate, 'YYYY-MM-DD') AS LastActiveDate,
    MonthsSinceLastActivity AS InactiveMonths,
    LifetimeSpend,
    CASE 
        WHEN MonthsSinceLastActivity >= 12 THEN 'HIGH CHURN RISK (Rule 14 Trigger)'
        WHEN MonthsSinceLastActivity >= 6  THEN 'MEDIUM RISK (Re-engagement Offer)'
        WHEN LifetimeSpend >= 500          THEN 'HIGH VALUE LOYAL VIP'
        ELSE 'ACTIVE NORMAL'
    END AS RetentionTier,
    DENSE_RANK() OVER (ORDER BY LifetimeSpend DESC) AS SpendRank
FROM MemberOrderSummary;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 1]
-- Format and Execute Query 1
COLUMN MemberID FORMAT 9999 HEADING "Mem ID"
COLUMN MemberName FORMAT A20 HEADING "Member Name"
COLUMN MembershipType FORMAT A6 HEADING "Tier"
COLUMN MemberStatus FORMAT A8 HEADING "Status"
COLUMN CurrentPoints FORMAT 999,990 HEADING "Points"
COLUMN TotalOrders FORMAT 999 HEADING "Orders"
COLUMN LastActiveDate FORMAT A10 HEADING "Last Active"
COLUMN InactiveMonths FORMAT 990.0 HEADING "Idle(Mo)"
COLUMN LifetimeSpend FORMAT $999,990.00 HEADING "Lifetime Spend"
COLUMN RetentionTier FORMAT A35 HEADING "Strategic Retention Tier"
COLUMN SpendRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC CUSTOMER CHURN & INACTIVITY RISK ANALYSIS
PROMPT ============================================================================
SELECT * FROM v_member_churn_risk
WHERE ROWNUM <= 15
ORDER BY SpendRank ASC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_voucher_conversion_roi
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 2 -> v_voucher_conversion_roi]
-- SCENARIO: The Loyalty Program Director needs to evaluate voucher conversion 
--   efficiency and points burn rate across campaigns. Business Rules 8, 10, and 12
--   stipulate 1 pt per RM1, single voucher per order, and minimum spend rules.
--   This query aggregates redemption volumes, points liquidated, and basket lift.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_voucher_conversion_roi AS
SELECT 
    v.VoucherID,
    v.VoucherName,
    v.VoucherType,
    v.DiscountValue,
    v.MinimumSpend,
    v.RequiredPoint,
    COUNT(pr.PointRedemptionID) AS TotalRedemptions,
    NVL(SUM(pr.PointUsed), 0) AS TotalPointsBurned,
    NVL(SUM(p.AmountPaid), 0) AS TotalRevenueGenerated,
    NVL(ROUND(AVG(p.AmountPaid), 2), 0.00) AS AvgBasketSize,
    ROUND(RATIO_TO_REPORT(NVL(SUM(p.AmountPaid), 0)) OVER () * 100, 2) AS PctRevenueContribution
FROM Voucher v
LEFT JOIN PointRedemption pr ON v.VoucherID = pr.VoucherID AND pr.RedemptionStatus = 'Completed'
LEFT JOIN CustomerOrder co ON pr.OrderID = co.OrderID
LEFT JOIN Payment p ON co.OrderID = p.OrderID AND p.PaymentStatus = 'Paid'
GROUP BY 
    v.VoucherID, v.VoucherName, v.VoucherType, 
    v.DiscountValue, v.MinimumSpend, v.RequiredPoint;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 2]
-- Format and Execute Query 2
COLUMN VoucherID FORMAT 999 HEADING "Vch ID"
COLUMN VoucherName FORMAT A20 HEADING "Voucher Campaign"
COLUMN VoucherType FORMAT A20 HEADING "Voucher Type"
COLUMN DiscountValue FORMAT $990.00 HEADING "Discount"
COLUMN MinimumSpend FORMAT $990.00 HEADING "Min Spend"
COLUMN RequiredPoint FORMAT 9,990 HEADING "Req Pts"
COLUMN TotalRedemptions FORMAT 999 HEADING "Redeemed"
COLUMN TotalPointsBurned FORMAT 999,990 HEADING "Pts Burned"
COLUMN TotalRevenueGenerated FORMAT $999,990.00 HEADING "Gross GMV"
COLUMN AvgBasketSize FORMAT $990.00 HEADING "Avg Basket"
COLUMN PctRevenueContribution FORMAT 990.00 HEADING "GMV Share %"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL VOUCHER ROI & POINTS BURN RATE ANALYSIS
PROMPT ============================================================================
SELECT * FROM v_voucher_conversion_roi
ORDER BY TotalRevenueGenerated DESC;
