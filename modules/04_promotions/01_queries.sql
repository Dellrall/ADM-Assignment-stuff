-- ============================================================================
-- MODULE 4: PROMOTION & MARKETING MANAGEMENT
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 4
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 4: PROMOTION & MARKETING MANAGEMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- 1. Sequence for Promotional Campaign Setup
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_promo_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_promo_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes for Promotion Date Filtering & Cart Repricing
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_promo_dates';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_promo_dates 
    ON Promotion(StartDate, EndDate);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_promoitem_item';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_promoitem_item 
    ON PromotionItem(ItemID, PromotionID);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_promo_campaign_margin_roi
-- SCENARIO: The Head of Marketing needs to measure campaign ROI and promotional 
--   margin absorption. Joining Promotion, PromotionItem, Item, OrderDetail, 
--   and CustomerOrder, this query calculates total orders touched, units sold, 
--   gross sales, promotional discount cost absorbed, and net revenue yield.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_promo_campaign_margin_roi AS
SELECT 
    p.PromotionID,
    TO_CHAR(p.StartDate, 'YYYY-MM-DD') AS StartDate,
    TO_CHAR(p.EndDate, 'YYYY-MM-DD') AS EndDate,
    p.DiscountAmount AS PromoDiscountPerUnit,
    COUNT(DISTINCT pi.ItemID) AS EnrolledSKUCount,
    COUNT(DISTINCT co.OrderID) AS AttributedOrderCount,
    NVL(SUM(od.Quantity), 0) AS TotalUnitsSold,
    NVL(SUM(od.Quantity * od.UnitPrice), 0) AS GrossSalesVolume,
    NVL(SUM(od.Quantity * od.Discount), 0) AS PromoMarginAbsorbed,
    NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) AS NetPromotionalYield,
    CASE 
        WHEN NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) >= 1000 THEN 'TIER 1 (High Yield Campaign)'
        WHEN NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) >= 400  THEN 'TIER 2 (Moderate Conversion)'
        ELSE 'TIER 3 (Low Yield / Clearance)'
    END AS CampaignPerformanceBand
FROM Promotion p
LEFT JOIN PromotionItem pi ON p.PromotionID = pi.PromotionID
LEFT JOIN OrderDetail od ON pi.ItemID = od.ItemID
LEFT JOIN CustomerOrder co ON od.OrderID = co.OrderID AND co.OrderStatus = 'Completed'
GROUP BY p.PromotionID, p.StartDate, p.EndDate, p.DiscountAmount;

-- Format and Execute Query 1
COLUMN PromotionID FORMAT 999 HEADING "Promo ID"
COLUMN StartDate FORMAT A10 HEADING "Start"
COLUMN EndDate FORMAT A10 HEADING "End"
COLUMN PromoDiscountPerUnit FORMAT $990.00 HEADING "Disc/Unit"
COLUMN EnrolledSKUCount FORMAT 999 HEADING "SKUs"
COLUMN AttributedOrderCount FORMAT 999 HEADING "Orders"
COLUMN TotalUnitsSold FORMAT 9999 HEADING "Units"
COLUMN GrossSalesVolume FORMAT $999,990.00 HEADING "Gross GMV"
COLUMN PromoMarginAbsorbed FORMAT $999,990.00 HEADING "Disc Cost"
COLUMN NetPromotionalYield FORMAT $999,990.00 HEADING "Net Yield"
COLUMN CampaignPerformanceBand FORMAT A28 HEADING "Performance Classification"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC PROMOTION CAMPAIGN ROI & MARGIN ABSORPTION
PROMPT ============================================================================
SELECT * FROM v_promo_campaign_margin_roi
WHERE ROWNUM <= 15
ORDER BY NetPromotionalYield DESC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_markdown_basket_depth
-- SCENARIO: The Merchandising Manager needs to evaluate markdown depth across 
--   enrolled items to ensure discounts stimulate sales without destroying margins.
--   This query calculates percentage markdown and remaining campaign duration.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_markdown_basket_depth AS
SELECT 
    p.PromotionID,
    i.ItemID,
    i.ItemName,
    i.Brand,
    i.Price AS OriginalRetailPrice,
    p.DiscountAmount AS PromoMarkdown,
    (i.Price - p.DiscountAmount) AS DiscountedPrice,
    ROUND((p.DiscountAmount / i.Price) * 100, 2) AS MarkdownPercentage,
    ROUND(p.EndDate - SYSDATE) AS DaysRemaining,
    CASE 
        WHEN (p.DiscountAmount / i.Price) >= 0.30 THEN 'DEEP DISCOUNT (>30% Cut)'
        WHEN (p.DiscountAmount / i.Price) >= 0.15 THEN 'STANDARD PROMO (15-30% Cut)'
        ELSE 'MINOR PROMO (<15% Cut)'
    END AS MarkdownTier,
    DENSE_RANK() OVER (ORDER BY (p.DiscountAmount / i.Price) DESC) AS MarkdownRank
FROM Promotion p
JOIN PromotionItem pi ON p.PromotionID = pi.PromotionID
JOIN Item i ON pi.ItemID = i.ItemID
WHERE p.EndDate >= SYSDATE;

-- Format and Execute Query 2
COLUMN PromotionID FORMAT 999 HEADING "Promo"
COLUMN ItemID FORMAT 9999 HEADING "Item"
COLUMN ItemName FORMAT A22 HEADING "Product Description"
COLUMN Brand FORMAT A16 HEADING "Brand"
COLUMN OriginalRetailPrice FORMAT $990.00 HEADING "Base Price"
COLUMN PromoMarkdown FORMAT $990.00 HEADING "Discount"
COLUMN DiscountedPrice FORMAT $990.00 HEADING "Promo Price"
COLUMN MarkdownPercentage FORMAT 990.00 HEADING "Markdown %"
COLUMN DaysRemaining FORMAT 999 HEADING "Days Left"
COLUMN MarkdownTier FORMAT A25 HEADING "Markdown Band"
COLUMN MarkdownRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL MARKDOWN DEPTH & ACTIVE DISCOUNT RANKING
PROMPT ============================================================================
SELECT * FROM v_markdown_basket_depth
WHERE ROWNUM <= 15
ORDER BY MarkdownPercentage DESC;
