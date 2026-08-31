-- ============================================================================
-- MODULE 3: ORDER, PAYMENT & FULFILLMENT MANAGEMENT
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 3
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 3: ORDER, PAYMENT & FULFILLMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- >>> [TASK 8 EXTRA EFFORT: SEQUENCE]
-- 1. Sequences for Orders and Payments
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_order_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_order_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_payment_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_payment_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- >>> [TASK 8 EXTRA EFFORT: PERFORMANCE INDEXES]
-- 2. Performance Indexes for Order Fulfillment & Payment Reconciliation
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_order_branch_date';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_order_branch_date 
    ON CustomerOrder(BranchID, OrderDate, OrderStatus);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_payment_order_method';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_payment_order_method 
    ON Payment(OrderID, PaymentMethod, PaymentStatus);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_omnichannel_fulfillment_rev
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 1 -> v_omnichannel_fulfillment_rev]
-- SCENARIO: The Operations Director needs to evaluate omnichannel performance.
--   Business Rules 2 & 22 allow online/walk-in purchases fulfilled either via 
--   In-Store Pickup (free) or Third-Party Delivery (delivery surcharge).
--   This strategic query classifies fulfillment channels, computes gross 
--   merchandise value (GMV), delivery surcharge earnings, and average basket sizes.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_omnichannel_fulfillment_rev AS
WITH FulfillmentClassification AS (
    SELECT 
        co.OrderID,
        co.BranchID,
        co.OrderDate,
        co.OrderStatus,
        CASE 
            WHEN d.DeliveryID IS NOT NULL THEN 'Delivery'
            WHEN pk.PickupID IS NOT NULL THEN 'In-Store Pickup'
            ELSE 'Counter Direct'
        END AS FulfillmentChannel,
        NVL(p.AmountPaid, 0) AS AmountPaid,
        NVL(ds.DeliveryCharge, 0) AS DeliverySurcharge
    FROM CustomerOrder co
    LEFT JOIN Delivery d ON co.OrderID = d.OrderID
    LEFT JOIN DeliveryService ds ON d.DeliveryServiceID = ds.DeliveryServiceID
    LEFT JOIN Pickup pk ON co.OrderID = pk.OrderID
    LEFT JOIN Payment p ON co.OrderID = p.OrderID AND p.PaymentStatus = 'Paid'
)
SELECT 
    b.BranchID,
    b.BranchName,
    fc.FulfillmentChannel,
    COUNT(fc.OrderID) AS TotalOrders,
    SUM(fc.AmountPaid) AS TotalGrossRevenue,
    SUM(fc.DeliverySurcharge) AS TotalDeliveryFeesCollected,
    ROUND(AVG(fc.AmountPaid), 2) AS AvgBasketSize,
    ROUND(RATIO_TO_REPORT(SUM(fc.AmountPaid)) OVER (PARTITION BY b.BranchID) * 100, 2) AS BranchChannelSharePct
FROM FulfillmentClassification fc
JOIN Branch b ON fc.BranchID = b.BranchID
GROUP BY b.BranchID, b.BranchName, fc.FulfillmentChannel;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 1]
-- Format and Execute Query 1
COLUMN BranchID FORMAT 9999 HEADING "Br ID"
COLUMN BranchName FORMAT A26 HEADING "Branch Name"
COLUMN FulfillmentChannel FORMAT A18 HEADING "Fulfillment Channel"
COLUMN TotalOrders FORMAT 999 HEADING "Orders"
COLUMN TotalGrossRevenue FORMAT $999,990.00 HEADING "Gross GMV"
COLUMN TotalDeliveryFeesCollected FORMAT $990.00 HEADING "Freight Fees"
COLUMN AvgBasketSize FORMAT $990.00 HEADING "Avg Basket"
COLUMN BranchChannelSharePct FORMAT 990.00 HEADING "Channel Share %"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC OMNICHANNEL REVENUE & FULFILLMENT CONTRIBUTION
PROMPT ============================================================================
SELECT * FROM v_omnichannel_fulfillment_rev
WHERE ROWNUM <= 15
ORDER BY BranchID ASC, TotalGrossRevenue DESC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_courier_sla_performance
-- >>> [TASK 8 EXTRA EFFORT: ENTERPRISE VIEW 2 -> v_courier_sla_performance]
-- SCENARIO: The Logistics Coordinator needs to track 3rd-party logistics (3PL)
--   courier partner SLA performance (Rule 3). This query measures delivery 
--   completion rates, active backlog, and logistics surcharge volume.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_courier_sla_performance AS
SELECT 
    ds.DeliveryServiceID,
    ds.CompanyName AS CourierName,
    ds.ContactNo,
    ds.DeliveryCharge AS StandardFee,
    COUNT(d.DeliveryID) AS TotalDispatched,
    SUM(CASE WHEN d.DeliveryStatus = 'Delivered' THEN 1 ELSE 0 END) AS DeliveredCount,
    SUM(CASE WHEN d.DeliveryStatus = 'In Transit' THEN 1 ELSE 0 END) AS InTransitCount,
    SUM(CASE WHEN d.DeliveryStatus = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledCount,
    ROUND(
        (SUM(CASE WHEN d.DeliveryStatus = 'Delivered' THEN 1 ELSE 0 END) / NULLIF(COUNT(d.DeliveryID), 0)) * 100, 
        2
    ) AS CompletionRatePct,
    SUM(CASE WHEN d.DeliveryStatus = 'Delivered' THEN ds.DeliveryCharge ELSE 0 END) AS TotalEarnedFreight
FROM DeliveryService ds
LEFT JOIN Delivery d ON ds.DeliveryServiceID = d.DeliveryServiceID
GROUP BY ds.DeliveryServiceID, ds.CompanyName, ds.ContactNo, ds.DeliveryCharge;

-- >>> [TASK 8 EXTRA EFFORT: SQL*PLUS OUTPUT FORMATTING 2]
-- Format and Execute Query 2
COLUMN DeliveryServiceID FORMAT 999 HEADING "3PL ID"
COLUMN CourierName FORMAT A25 HEADING "Courier Partner"
COLUMN StandardFee FORMAT $990.00 HEADING "Base Fee"
COLUMN TotalDispatched FORMAT 999 HEADING "Dispatched"
COLUMN DeliveredCount FORMAT 999 HEADING "Delivered"
COLUMN InTransitCount FORMAT 999 HEADING "In-Transit"
COLUMN CancelledCount FORMAT 999 HEADING "Cancelled"
COLUMN CompletionRatePct FORMAT 990.00 HEADING "SLA Rate %"
COLUMN TotalEarnedFreight FORMAT $999,990.00 HEADING "Total Freight"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL 3PL COURIER PARTNER SLA & EFFICIENCY AUDIT
PROMPT ============================================================================
SELECT * FROM v_courier_sla_performance
ORDER BY TotalDispatched DESC;
