-- ============================================================================
-- MODULE 5: REFUND & RETURN MANAGEMENT (SELECTED ADDITIONAL MODULE)
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 5
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: REFUND & RETURN MANAGEMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- >>> [TASK 8 EXTRA EFFORT: SEQUENCE]
-- 1. Sequence for Refund Claim Tickets
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_refund_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_refund_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- >>> [TASK 8 EXTRA EFFORT: PERFORMANCE INDEXES]
-- 2. Performance Indexes for Dispute Tracking & Defect Quality Control
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_refund_status_date';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_refund_status_date 
    ON Refund(RefundStatus, RefundDate, OrderID);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_returnitem_condition';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_returnitem_condition 
    ON ReturnItem(ItemCondition, ItemID, RefundID);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_defective_supplier_liability
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 1 -> v_defective_supplier_liability]
-- SCENARIO: The Quality Assurance & Supplier Relations Director needs to identify
--   problematic grocery items and hold suppliers liable for defective or expired
--   shipments (Rules 31 & 33). This strategic query aggregates refund write-offs
--   by product, defects ('Damaged', 'Defective', 'Expired'), and traces liability 
--   back to primary suppliers.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_defective_supplier_liability AS
WITH DefectiveItemsCTE AS (
    SELECT 
        ri.ItemID,
        i.ItemName,
        i.Brand,
        ri.ItemCondition,
        COUNT(ri.RefundID) AS ReturnIncidentCount,
        SUM(ri.Quantity) AS TotalDefectiveUnits,
        SUM(ri.Quantity * i.Price) AS TotalDefectLoss
    FROM ReturnItem ri
    JOIN Item i ON ri.ItemID = i.ItemID
    JOIN Refund r ON ri.RefundID = r.RefundID
    WHERE r.RefundStatus IN ('Approved', 'Completed')
    GROUP BY ri.ItemID, i.ItemName, i.Brand, ri.ItemCondition
),
SupplierTraceCTE AS (
    SELECT 
        poi.ItemID,
        s.SupplierID,
        s.CompanyName AS PrimarySupplier,
        s.ContactNo AS SupplierPhone
    FROM PurchaseOrderItem poi
    JOIN PurchaseOrder po ON poi.PurchaseOrderID = po.PurchaseOrderID
    JOIN Supplier s ON po.SupplierID = s.SupplierID
    GROUP BY poi.ItemID, s.SupplierID, s.CompanyName, s.ContactNo
)
SELECT 
    d.ItemID,
    d.ItemName,
    d.Brand,
    d.ItemCondition AS DefectType,
    d.ReturnIncidentCount,
    d.TotalDefectiveUnits,
    d.TotalDefectLoss,
    NVL(st.PrimarySupplier, 'Unassigned Supplier') AS LiableSupplier,
    NVL(st.SupplierPhone, 'N/A') AS SupplierContact,
    DENSE_RANK() OVER (ORDER BY d.TotalDefectLoss DESC) AS DefectSeverityRank
FROM DefectiveItemsCTE d
LEFT JOIN SupplierTraceCTE st ON d.ItemID = st.ItemID;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 1]
-- Format and Execute Query 1
COLUMN ItemID FORMAT 9999 HEADING "Item"
COLUMN ItemName FORMAT A20 HEADING "Product Description"
COLUMN Brand FORMAT A15 HEADING "Brand"
COLUMN DefectType FORMAT A12 HEADING "Defect Type"
COLUMN ReturnIncidentCount FORMAT 999 HEADING "Claims"
COLUMN TotalDefectiveUnits FORMAT 999 HEADING "Units"
COLUMN TotalDefectLoss FORMAT $999,990.00 HEADING "Total Defect Loss"
COLUMN LiableSupplier FORMAT A22 HEADING "Liable Supplier"
COLUMN DefectSeverityRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC DEFECT LOSS RANKING & SUPPLIER QUALITY AUDIT
PROMPT ============================================================================
SELECT * FROM v_defective_supplier_liability
WHERE ROWNUM <= 15
ORDER BY DefectSeverityRank ASC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_branch_refund_risk_audit
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 2 -> v_branch_refund_risk_audit]
-- SCENARIO: The Retail Audit Manager needs to evaluate claim trends across 
--   physical branches. Joining Branch, CustomerOrder, and Refund, this query 
--   computes total claims submitted, approval rate %, rejection rate %, and 
--   total funds reimbursed per branch.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_branch_refund_risk_audit AS
SELECT 
    b.BranchID,
    b.BranchName,
    b.State,
    COUNT(r.RefundID) AS TotalClaimsLodged,
    SUM(CASE WHEN r.RefundStatus IN ('Approved', 'Completed') THEN 1 ELSE 0 END) AS ApprovedCount,
    SUM(CASE WHEN r.RefundStatus = 'Rejected' THEN 1 ELSE 0 END) AS RejectedCount,
    SUM(CASE WHEN r.RefundStatus = 'Pending' THEN 1 ELSE 0 END) AS PendingCount,
    ROUND(
        (SUM(CASE WHEN r.RefundStatus IN ('Approved', 'Completed') THEN 1 ELSE 0 END) / 
        NULLIF(COUNT(r.RefundID), 0)) * 100, 
        1
    ) AS ApprovalRatePct,
    NVL(SUM(CASE WHEN r.RefundStatus IN ('Approved', 'Completed') THEN r.RefundAmount ELSE 0 END), 0) AS TotalRefundedAmount
FROM Branch b
LEFT JOIN CustomerOrder co ON b.BranchID = co.BranchID
LEFT JOIN Refund r ON co.OrderID = r.OrderID
GROUP BY b.BranchID, b.BranchName, b.State;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 2]
-- Format and Execute Query 2
COLUMN BranchID FORMAT 9999 HEADING "Br ID"
COLUMN BranchName FORMAT A22 HEADING "Branch Name"
COLUMN State FORMAT A12 HEADING "State"
COLUMN TotalClaimsLodged FORMAT 999 HEADING "Claims"
COLUMN ApprovedCount FORMAT 999 HEADING "Approved"
COLUMN RejectedCount FORMAT 999 HEADING "Rejected"
COLUMN PendingCount FORMAT 999 HEADING "Pending"
COLUMN ApprovalRatePct FORMAT 990.0 HEADING "Appr %"
COLUMN TotalRefundedAmount FORMAT $999,990.00 HEADING "Total Reimbursed"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL BRANCH REFUND RISK & CLAIM ADJUDICATION AUDIT
PROMPT ============================================================================
SELECT * FROM v_branch_refund_risk_audit
ORDER BY TotalClaimsLodged DESC;
