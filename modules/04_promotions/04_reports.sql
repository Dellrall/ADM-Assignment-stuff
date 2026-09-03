-- ============================================================================
-- MODULE 4: PROMOTION & MARKETING MANAGEMENT
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 4
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 4: PROMOTION & MARKETING MANAGEMENT - MANAGEMENT REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_active_promo_catalog
-- CLASSIFICATION: Weekly Promotional Flyer & Markdown Catalog
-- COMPLEXITY: Parameterized Nested Cursors (Campaigns -> Enrolled Items)
-- SCENARIO: Weekly marketing circular distributed across retail stores detailing
--   active discounts, enrolled products, and customer savings margins.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_active_promo_catalog AS
    -- 1. Parent Cursor: Active Promotions
    CURSOR c_promos IS
        SELECT 
            p.PromotionID,
            p.DiscountAmount,
            p.StartDate,
            p.EndDate,
            ROUND(p.EndDate - SYSDATE) AS DaysLeft
        FROM Promotion p
        ORDER BY p.EndDate ASC;

    -- 2. Parameterized Child Cursor: Enrolled Items under this promotion
    CURSOR c_items(p_pid NUMBER, p_disc NUMBER) IS
        SELECT 
            i.ItemID,
            i.ItemName,
            i.Brand,
            i.Price AS BasePrice,
            (i.Price - p_disc) AS PromotionalPrice,
            ROUND((p_disc / i.Price) * 100, 1) AS PctSavings
        FROM PromotionItem pi
        JOIN Item i ON pi.ItemID = i.ItemID
        WHERE pi.PromotionID = p_pid
        ORDER BY i.Price DESC;

    v_active_campaign_cnt NUMBER := 0;
    v_total_items_on_sale NUMBER := 0;
    v_item_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
    DBMS_OUTPUT.PUT_LINE('              88 SPEEDMART - ACTIVE PROMOTIONS & WEEKLY SAVINGS CATALOG');
    DBMS_OUTPUT.PUT_LINE('                              Published: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));

    FOR promo IN c_promos LOOP
        v_active_campaign_cnt := v_active_campaign_cnt + 1;
        v_item_count := 0;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(' CAMPAIGN #' || promo.PromotionID || ' | Markdown: RM ' || 
                             TO_CHAR(promo.DiscountAmount, 'FM990.00') || ' OFF | Validity: ' || 
                             TO_CHAR(promo.StartDate, 'YYYY-MM-DD') || ' to ' || 
                             TO_CHAR(promo.EndDate, 'YYYY-MM-DD') || ' (' || promo.DaysLeft || ' days remaining)');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('  Item ID', 12) || 
            RPAD('Product Description', 30) || 
            RPAD('Brand', 20) || 
            LPAD('Base Price', 12) || 
            LPAD('Promo Price', 13) || 
            LPAD('Savings %', 13)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

        FOR itm IN c_items(promo.PromotionID, promo.DiscountAmount) LOOP
            v_item_count := v_item_count + 1;
            v_total_items_on_sale := v_total_items_on_sale + 1;

            DBMS_OUTPUT.PUT_LINE(
                RPAD('  ' || itm.ItemID, 12) || 
                RPAD(SUBSTR(itm.ItemName, 1, 28), 30) || 
                RPAD(SUBSTR(NVL(itm.Brand, 'Generic'), 1, 18), 20) || 
                LPAD('RM ' || TO_CHAR(itm.BasePrice, 'FM990.00'), 12) || 
                LPAD('RM ' || TO_CHAR(itm.PromotionalPrice, 'FM990.00'), 13) || 
                LPAD(itm.PctSavings || ' %', 13)
            );
        END LOOP;

        IF v_item_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  >>> No grocery items currently linked to this promotion ID.');
        ELSE
            DBMS_OUTPUT.PUT_LINE(RPAD('.', 100, '.'));
            DBMS_OUTPUT.PUT_LINE('  >> Total ' || v_item_count || ' product(s) discounted under this campaign.');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
    DBMS_OUTPUT.PUT_LINE(' CATALOG SUMMARY: ' || v_active_campaign_cnt || ' Active Campaigns | ' || 
                         v_total_items_on_sale || ' Discounted Products Nationwide.');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
END sp_rpt_active_promo_catalog;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_promotion_sales_impact
-- CLASSIFICATION: Post-Campaign Financial Audit Report
-- COMPLEXITY: Parameterized Nested Cursors (Promotion Master -> Order Lines)
-- SCENARIO: Marketing and finance executives audit the exact revenue, customer
--   uptake, and discount expenses generated by a specific marketing campaign.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_promotion_sales_impact (
    p_promo_id IN NUMBER
) AS
    -- 1. Parent Cursor: Campaign Metadata
    CURSOR c_promo IS
        SELECT PromotionID, DiscountAmount, StartDate, EndDate
        FROM Promotion
        WHERE PromotionID = p_promo_id;

    -- 2. Parameterized Child Cursor: Orders that purchased items under this promotion
    CURSOR c_orders(p_pid NUMBER) IS
        SELECT 
            co.OrderID,
            co.OrderDate,
            m.Name AS CustomerName,
            b.BranchName,
            i.ItemName,
            od.Quantity,
            od.UnitPrice,
            od.Discount,
            (od.Quantity * od.Discount) AS TotalDiscountGiven,
            (od.Quantity * (od.UnitPrice - od.Discount)) AS NetLineRevenue
        FROM OrderDetail od
        JOIN PromotionItem pi ON od.ItemID = pi.ItemID
        JOIN CustomerOrder co ON od.OrderID = co.OrderID
        JOIN Member m ON co.MemberID = m.MemberID
        JOIN Branch b ON co.BranchID = b.BranchID
        JOIN Item i ON od.ItemID = i.ItemID
        WHERE pi.PromotionID = p_pid
          AND co.OrderStatus = 'Completed'
        ORDER BY co.OrderDate DESC;

    v_p c_promo%ROWTYPE;
    v_order_count NUMBER := 0;
    v_units_total NUMBER := 0;
    v_disc_total  NUMBER := 0;
    v_net_total   NUMBER := 0;
BEGIN
    OPEN c_promo;
    FETCH c_promo INTO v_p;

    IF c_promo%NOTFOUND THEN
        CLOSE c_promo;
        DBMS_OUTPUT.PUT_LINE('Error: Promotion ID #' || p_promo_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_promo;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('                88 SPEEDMART - PROMOTION CAMPAIGN FINANCIAL IMPACT AUDIT');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Campaign ID   : ' || RPAD(v_p.PromotionID, 10) || ' Discount/Unit : RM ' || TO_CHAR(v_p.DiscountAmount, 'FM990.00'));
    DBMS_OUTPUT.PUT_LINE(' Active Period : ' || TO_CHAR(v_p.StartDate, 'YYYY-MM-DD') || ' to ' || TO_CHAR(v_p.EndDate, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Order ID', 10) || 
        RPAD('Date', 12) || 
        RPAD('Customer Name', 22) || 
        RPAD('Purchased Item', 22) || 
        LPAD('Qty', 5) || 
        LPAD('Disc(RM)', 15) || 
        LPAD('Net Rev(RM)', 16)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR ord IN c_orders(v_p.PromotionID) LOOP
        v_order_count := v_order_count + 1;
        v_units_total := v_units_total + ord.Quantity;
        v_disc_total  := v_disc_total + ord.TotalDiscountGiven;
        v_net_total   := v_net_total + ord.NetLineRevenue;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(ord.OrderID, 10) || 
            RPAD(TO_CHAR(ord.OrderDate, 'YYYY-MM-DD'), 12) || 
            RPAD(SUBSTR(ord.CustomerName, 1, 20), 22) || 
            RPAD(SUBSTR(ord.ItemName, 1, 20), 22) || 
            LPAD(ord.Quantity, 5) || 
            LPAD(TO_CHAR(ord.TotalDiscountGiven, 'FM999,990.00'), 15) || 
            LPAD(TO_CHAR(ord.NetLineRevenue, 'FM999,990.00'), 16)
        );
    END LOOP;

    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No completed customer orders recorded for this campaign.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' FINANCIAL AUDIT SUMMARY:');
    DBMS_OUTPUT.PUT_LINE(' Total Transactions Touched : ' || v_order_count);
    DBMS_OUTPUT.PUT_LINE(' Total Promotional Units Sold: ' || v_units_total);
    DBMS_OUTPUT.PUT_LINE(' Gross Margin Discount Cost  : RM ' || TO_CHAR(v_disc_total, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(' Net Promotional Sales Yield : RM ' || TO_CHAR(v_net_total, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
END sp_rpt_promotion_sales_impact;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_active_promo_catalog
PROMPT ============================================================================
EXEC sp_rpt_active_promo_catalog;

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_promotion_sales_impact (Promo ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_promotion_sales_impact(1);
