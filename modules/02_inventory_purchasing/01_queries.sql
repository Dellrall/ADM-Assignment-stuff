-- ============================================================================
-- MODULE 2: INVENTORY & PURCHASING MANAGEMENT
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 2
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 2: INVENTORY & PURCHASING MANAGEMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- >>> [TASK 8 EXTRA EFFORT: SEQUENCE]
-- 1. Sequences for Procurement and Audit Logging
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_po_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_po_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_stock_log_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_stock_log_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- >>> [TASK 8 EXTRA EFFORT: PERFORMANCE INDEXES]
-- 2. Performance Indexes for Inventory Monitoring & Perishables Tracking
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_stock_reorder_alert';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_stock_reorder_alert 
    ON Stock(BranchID, Quantity, ReorderLevel);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_batch_expiry_branch';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_batch_expiry_branch 
    ON StockBatch(BranchID, ExpiryDate, ItemID);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_branch_reorder_deficit
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 1 -> v_branch_reorder_deficit]
-- SCENARIO: The Supply Chain Director requires a multi-branch replenishment
--   and procurement capital forecast. Under Business Rule 18, stock reorder 
--   alerts trigger when Quantity <= ReorderLevel. This query calculates stock 
--   deficits up to MaximumStock and projects capital required using recent PO costs.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_branch_reorder_deficit AS
WITH LatestItemCost AS (
    SELECT 
        ItemID,
        AVG(CostPrice) AS EstimatedUnitCost
    FROM PurchaseOrderItem
    GROUP BY ItemID
)
SELECT 
    b.BranchID,
    b.BranchName,
    b.State,
    i.ItemID,
    i.ItemName,
    i.Brand,
    s.Quantity AS CurrentQty,
    s.ReorderLevel,
    s.MaximumStock,
    (s.MaximumStock - s.Quantity) AS RestockUnitsNeeded,
    NVL(lic.EstimatedUnitCost, i.Price * 0.70) AS EstimatedUnitCost,
    ROUND((s.MaximumStock - s.Quantity) * NVL(lic.EstimatedUnitCost, i.Price * 0.70), 2) AS RequiredProcurementBudget,
    DENSE_RANK() OVER (PARTITION BY b.BranchID ORDER BY (s.MaximumStock - s.Quantity) DESC) AS BranchDeficitRank
FROM Stock s
JOIN Branch b ON s.BranchID = b.BranchID
JOIN Item i ON s.ItemID = i.ItemID
LEFT JOIN LatestItemCost lic ON i.ItemID = lic.ItemID
WHERE s.Quantity <= s.ReorderLevel;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 1]
-- Format and Execute Query 1
COLUMN BranchID FORMAT 9999 HEADING "Br ID"
COLUMN BranchName FORMAT A24 HEADING "Branch Name"
COLUMN State FORMAT A20 HEADING "State"
COLUMN ItemID FORMAT 9999 HEADING "Item ID"
COLUMN ItemName FORMAT A28 HEADING "Item Name"
COLUMN Brand FORMAT A12 HEADING "Brand"
COLUMN CurrentQty FORMAT 999 HEADING "Qty"
COLUMN ReorderLevel FORMAT 999 HEADING "Min"
COLUMN MaximumStock FORMAT 999 HEADING "Max"
COLUMN RestockUnitsNeeded FORMAT 999 HEADING "Deficit"
COLUMN EstimatedUnitCost FORMAT $990.00 HEADING "Unit Cost"
COLUMN RequiredProcurementBudget FORMAT $999,990.00 HEADING "Est. Budget"
COLUMN BranchDeficitRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC REORDER DEFICIT & PROCUREMENT BUDGET FORECAST
PROMPT ============================================================================
SELECT * FROM v_branch_reorder_deficit
WHERE ROWNUM <= 15
ORDER BY RequiredProcurementBudget DESC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_batch_spoilage_exposure
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 2 -> v_batch_spoilage_exposure]
-- SCENARIO: The Quality Assurance (QA) Manager tracks perishable batch expiry 
--   across branches. Business Rule 19 requires write-off of expired goods.
--   This tactical query identifies batches expiring in 30/60/90 days and 
--   calculates financial inventory at risk.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_batch_spoilage_exposure AS
SELECT 
    b.BranchID,
    b.BranchName,
    sb.BatchID,
    i.ItemID,
    i.ItemName,
    sb.Quantity AS BatchQuantity,
    TO_CHAR(sb.ReceivedDate, 'YYYY-MM-DD') AS ReceivedDate,
    TO_CHAR(sb.ExpiryDate, 'YYYY-MM-DD') AS ExpiryDate,
    ROUND(sb.ExpiryDate - SYSDATE) AS DaysUntilExpiry,
    ROUND(sb.Quantity * i.Price, 2) AS RetailValueAtRisk,
    CASE 
        WHEN sb.ExpiryDate < SYSDATE THEN 'EXPIRED (Action Required: Rule 19)'
        WHEN sb.ExpiryDate <= SYSDATE + 30 THEN 'CRITICAL (<30 Days Clearance)'
        WHEN sb.ExpiryDate <= SYSDATE + 60 THEN 'MODERATE (30-60 Days Promo)'
        ELSE 'SAFE (>60 Days)'
    END AS SpoilageRiskStatus
FROM StockBatch sb
JOIN Branch b ON sb.BranchID = b.BranchID
JOIN Item i ON sb.ItemID = i.ItemID
WHERE sb.ExpiryDate IS NOT NULL;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 2]
-- Format and Execute Query 2
COLUMN BranchID FORMAT 9999 HEADING "Br ID"
COLUMN BranchName FORMAT A20 HEADING "Branch Name"
COLUMN BatchID FORMAT 9999 HEADING "Batch"
COLUMN ItemID FORMAT 9999 HEADING "Item ID"
COLUMN ItemName FORMAT A28 HEADING "Perishable Product"
COLUMN BatchQuantity FORMAT 999 HEADING "Batch Qty"
COLUMN ReceivedDate FORMAT A10 HEADING "Received"
COLUMN ExpiryDate FORMAT A10 HEADING "Expiry"
COLUMN DaysUntilExpiry FORMAT 9990 HEADING "Days Left"
COLUMN RetailValueAtRisk FORMAT $999,990.00 HEADING "Value at Risk"
COLUMN SpoilageRiskStatus FORMAT A30 HEADING "Spoilage Risk Classification"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL PERISHABLE BATCH EXPIRY & SPOILAGE RISK
PROMPT ============================================================================
SELECT * FROM v_batch_spoilage_exposure
WHERE DaysUntilExpiry <= 90 AND ROWNUM <= 15
ORDER BY DaysUntilExpiry ASC;
