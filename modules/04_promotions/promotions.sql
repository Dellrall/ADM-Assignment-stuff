-- =============================================================================
-- MODULE 4: PROMOTION & MARKETING MANAGEMENT
-- BMCS3183 Advanced Database Management | 88 Speedmart System
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- -----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES, VIEWS, CUSTOM EXCEPTIONS)
-- -----------------------------------------------------------------------------


-- Drop existing sequences & indexes for clean re-execution
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_promo_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_promo_date_range';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_promo_item_lookup';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. Sequence for Promotion Campaigns
CREATE SEQUENCE seq_promo_id
    START WITH 300
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes
CREATE INDEX idx_promo_date_range ON Promotion (StartDate, EndDate);
CREATE INDEX idx_promo_item_lookup ON PromotionItem (ItemID, PromotionID);

-- 3. View 1: Active Promotion Item Catalog (Strategic View)
CREATE OR REPLACE VIEW v_active_promotion_catalog AS
SELECT 
    p.PromotionID,
    p.DiscountAmount AS SavingsPerUnit,
    p.StartDate,
    p.EndDate,
    ROUND(p.EndDate - SYSDATE) AS DaysRemaining,
    i.ItemID,
    i.ItemName,
    i.Brand,
    i.Price AS OriginalPrice,
    GREATEST(i.Price - p.DiscountAmount, 0) AS PromotionalPrice,
    ROUND((p.DiscountAmount / NULLIF(i.Price, 0)) * 100, 2) AS DiscountPercentage
FROM Promotion p
JOIN PromotionItem pi ON p.PromotionID = pi.PromotionID
JOIN Item i ON pi.ItemID = i.ItemID
WHERE SYSDATE BETWEEN p.StartDate AND p.EndDate;

-- 4. View 2: Promotion Campaign Sales & Uplift (Tactical View)
CREATE OR REPLACE VIEW v_promotion_sales_performance AS
SELECT 
    p.PromotionID,
    p.DiscountAmount,
    p.StartDate,
    p.EndDate,
    COUNT(DISTINCT pi.ItemID) AS PromotedItemCount,
    NVL(SUM(od.Quantity), 0) AS TotalUnitsSold,
    NVL(SUM(od.Quantity * (od.UnitPrice - od.Discount)), 0) AS CampaignRevenue,
    NVL(SUM(od.Quantity * od.Discount), 0) AS TotalDiscountsAbsorbed
FROM Promotion p
JOIN PromotionItem pi ON p.PromotionID = pi.PromotionID
LEFT JOIN OrderDetail od ON pi.ItemID = od.ItemID
LEFT JOIN CustomerOrder co ON od.OrderID = co.OrderID 
    AND co.OrderStatus = 'Completed'
    AND co.OrderDate BETWEEN p.StartDate AND p.EndDate
GROUP BY p.PromotionID, p.DiscountAmount, p.StartDate, p.EndDate;

-- -----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL & OPERATIONAL QUERIES (2 QUERIES)
-- -----------------------------------------------------------------------------

-- Query 1 (Strategic): Promotion Campaign Revenue & Discount Absorption Analysis
-- Analyzes campaign efficiency and margin impact across all promotional campaigns.
SELECT 
    v.PromotionID AS "Campaign ID",
    TO_CHAR(v.StartDate, 'YYYY-MM-DD') AS "Start Date",
    TO_CHAR(v.EndDate, 'YYYY-MM-DD') AS "End Date",
    v.PromotedItemCount AS "Items Included",
    v.TotalUnitsSold AS "Units Sold",
    TO_CHAR(v.CampaignRevenue, 'FM99,990.00') AS "Gross Sales",
    TO_CHAR(v.TotalDiscountsAbsorbed, 'FM99,990.00') AS "Discounts Given",
    CASE 
        WHEN v.CampaignRevenue > 5000 THEN 'HIGH PERFORMING CAMPAIGN'
        WHEN v.CampaignRevenue > 1000 THEN 'MODERATE SALES UPLIFT'
        ELSE 'LOW CONVERSION'
    END AS "Performance Category"
FROM v_promotion_sales_performance v
ORDER BY v.CampaignRevenue DESC;

-- Query 2 (Tactical): Deepest Discount Deals & Markdown Margin Analysis
-- Evaluates discount percentages on active items to identify key promotional drivers.
SELECT 
    apc.PromotionID AS "Promo #",
    apc.ItemID AS "Item #",
    RPAD(apc.ItemName, 24) AS "Item Name",
    RPAD(NVL(apc.Brand, 'Generic'), 16) AS "Brand",
    TO_CHAR(apc.OriginalPrice, 'FM90.00') AS "Base Price",
    TO_CHAR(apc.PromotionalPrice, 'FM90.00') AS "Promo Price",
    apc.DiscountPercentage || '%' AS "Margin Cut",
    apc.DaysRemaining || ' days' AS "Time Remaining"
FROM v_active_promotion_catalog apc
ORDER BY apc.DiscountPercentage DESC;

-- -----------------------------------------------------------------------------
-- TASK 5: STORED PROCEDURES WITH EXCEPTION HANDLING (2 PROCEDURES)
-- -----------------------------------------------------------------------------

-- Procedure 1: Launch New Promotional Campaign with Item Enrollment
CREATE OR REPLACE PROCEDURE sp_create_promotional_campaign (
    p_discount_amt IN Promotion.DiscountAmount%TYPE,
    p_start_date   IN Promotion.StartDate%TYPE,
    p_end_date     IN Promotion.EndDate%TYPE,
    p_item_id      IN Item.ItemID%TYPE,
    p_new_promo_id OUT Promotion.PromotionID%TYPE
) AS
    -- Custom Exceptions
    e_invalid_dates    EXCEPTION;
    e_negative_discount EXCEPTION;
    e_item_unavailable EXCEPTION;

    v_item_price  Item.Price%TYPE;
    v_item_status Item.ItemStatus%TYPE;
BEGIN
    -- 0. Input Parameter Validation
    IF p_item_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20312, 'Validation Error: Item ID must be a positive integer.');
    END IF;

    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE_APPLICATION_ERROR(-20313, 'Validation Error: Campaign StartDate and EndDate cannot be NULL.');
    END IF;

    -- 1. Date Validation
    IF p_end_date <= p_start_date THEN
        RAISE e_invalid_dates;
    END IF;

    IF p_discount_amt <= 0 THEN
        RAISE e_negative_discount;
    END IF;

    -- 2. Verify Item
    SELECT Price, ItemStatus INTO v_item_price, v_item_status
    FROM Item
    WHERE ItemID = p_item_id;

    IF v_item_status <> 'Available' THEN
        RAISE e_item_unavailable;
    END IF;

    IF p_discount_amt >= v_item_price THEN
        RAISE_APPLICATION_ERROR(-20301, 'Discount Error: Discount amount (MYR ' || p_discount_amt || ') exceeds item base price (MYR ' || v_item_price || ').');
    END IF;

    -- 3. Create Promotion Record
    p_new_promo_id := seq_promo_id.NEXTVAL;

    INSERT INTO Promotion (
        PromotionID, DiscountAmount, StartDate, EndDate
    ) VALUES (
        p_new_promo_id, p_discount_amt, p_start_date, p_end_date
    );

    -- 4. Enroll Item
    INSERT INTO PromotionItem (PromotionID, ItemID)
    VALUES (p_new_promo_id, p_item_id);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: Campaign #' || p_new_promo_id || ' created with Item #' || p_item_id || ' enrolled.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20302, 'Lookup Error: Item #' || p_item_id || ' does not exist.');
    WHEN e_invalid_dates THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20303, 'Validation Error: EndDate must be strictly after StartDate.');
    WHEN e_negative_discount THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20304, 'Validation Error: Discount amount must be greater than zero.');
    WHEN e_item_unavailable THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20305, 'Eligibility Error: Unavailable items cannot be enrolled in promotions.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20300, 'System Error in sp_create_promotional_campaign: ' || SQLERRM);
END sp_create_promotional_campaign;
/

-- Procedure 2: Batch Refresh Order Line Discounts from Active Promotions
CREATE OR REPLACE PROCEDURE sp_apply_order_promo_discount (
    p_order_id IN CustomerOrder.OrderID%TYPE
) AS
    -- PRAGMA Exception for numeric overflow (-1438)
    e_numeric_overflow EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_numeric_overflow, -1438);

    -- Custom Exception
    e_order_not_pending EXCEPTION;

    v_order_status CustomerOrder.OrderStatus%TYPE;
    v_updated_lines NUMBER := 0;

    CURSOR c_promo_lines IS
        SELECT od.ItemID, p.DiscountAmount
        FROM OrderDetail od
        JOIN PromotionItem pi ON od.ItemID = pi.ItemID
        JOIN Promotion p ON pi.PromotionID = p.PromotionID
        WHERE od.OrderID = p_order_id
          AND SYSDATE BETWEEN p.StartDate AND p.EndDate;
BEGIN
    IF p_order_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20314, 'Validation Error: Order ID must be a positive integer.');
    END IF;

    SELECT OrderStatus INTO v_order_status
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_order_status <> 'Pending' THEN
        RAISE e_order_not_pending;
    END IF;

    FOR r_pl IN c_promo_lines LOOP
        UPDATE OrderDetail
        SET Discount = r_pl.DiscountAmount
        WHERE OrderID = p_order_id AND ItemID = r_pl.ItemID;

        v_updated_lines := v_updated_lines + 1;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Discounts refreshed: ' || v_updated_lines || ' line items updated with active promo prices for Order #' || p_order_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20306, 'Lookup Error: Order #' || p_order_id || ' does not exist.');
    WHEN e_order_not_pending THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20307, 'State Error: Discounts can only be applied to Pending orders.');
    WHEN e_numeric_overflow THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20308, 'Arithmetic Error: Discount value caused a numeric overflow.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20300, 'System Error in sp_apply_order_promo_discount: ' || SQLERRM);
END sp_apply_order_promo_discount;
/

-- -----------------------------------------------------------------------------
-- TASK 6: CONDITIONAL TRIGGERS (2 TRIGGERS)
-- -----------------------------------------------------------------------------

-- Trigger 1: Guard Against Invalid Promotion Date Configurations
CREATE OR REPLACE TRIGGER trg_guard_promotion_date_range
BEFORE INSERT OR UPDATE ON Promotion
FOR EACH ROW
WHEN (NEW.EndDate <= NEW.StartDate)
BEGIN
    RAISE_APPLICATION_ERROR(-20310, 'Trigger Violation: Promotion EndDate must be strictly later than StartDate.');
END trg_guard_promotion_date_range;
/

-- Trigger 2: Prevent Promotion Item Discount Exceeding Item Base Price
CREATE OR REPLACE TRIGGER trg_guard_promo_item_discount
BEFORE INSERT ON PromotionItem
FOR EACH ROW
DECLARE
    v_item_price NUMBER;
    v_discount   NUMBER;
BEGIN
    SELECT Price INTO v_item_price FROM Item WHERE ItemID = :NEW.ItemID;
    SELECT DiscountAmount INTO v_discount FROM Promotion WHERE PromotionID = :NEW.PromotionID;

    IF v_discount >= v_item_price THEN
        RAISE_APPLICATION_ERROR(-20311, 'Trigger Violation: Discount (MYR ' || v_discount || ') exceeds item base price (MYR ' || v_item_price || ').');
    END IF;
END trg_guard_promo_item_discount;
/

-- -----------------------------------------------------------------------------
-- TASK 7: REPORTS GENERATION WITH NESTED CURSORS (2 REPORTS)
-- -----------------------------------------------------------------------------

-- Report 1: Active Promotional Campaigns & Product Markdown Catalog (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_active_promotions_catalog AS
    -- Parent Cursor: Active Promotions
    CURSOR c_promos IS
        SELECT PromotionID, DiscountAmount, StartDate, EndDate
        FROM Promotion
        WHERE SYSDATE BETWEEN StartDate AND EndDate
        ORDER BY PromotionID;

    -- Child Cursor: Enrolled Grocery Products
    CURSOR c_items (cp_promo_id NUMBER) IS
        SELECT i.ItemID, i.ItemName, i.Brand, i.Price,
               GREATEST(i.Price - p.DiscountAmount, 0) AS PromoPrice
        FROM PromotionItem pi
        JOIN Item i ON pi.ItemID = i.ItemID
        JOIN Promotion p ON pi.PromotionID = p.PromotionID
        WHERE pi.PromotionID = cp_promo_id;

    v_promo_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                     88 SPEEDMART ACTIVE PROMOTION CAMPAIGN CATALOG                     ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');

    FOR r_pr IN c_promos LOOP
        v_promo_count := v_promo_count + 1;
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '>> CAMPAIGN #' || r_pr.PromotionID || ' | Discount per unit: MYR ' || TO_CHAR(r_pr.DiscountAmount, 'FM990.00'));
        DBMS_OUTPUT.PUT_LINE('   Valid From: ' || TO_CHAR(r_pr.StartDate, 'YYYY-MM-DD') || ' to ' || TO_CHAR(r_pr.EndDate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('   ' || RPAD('Item ID', 9) || RPAD('Item Description', 26) || RPAD('Brand', 16) || LPAD('Normal (MYR)', 14) || LPAD('Promo (MYR)', 14));
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');

        FOR r_it IN c_items(r_pr.PromotionID) LOOP
            DBMS_OUTPUT.PUT_LINE('   ' ||
                RPAD('#' || r_it.ItemID, 9) ||
                RPAD(SUBSTR(r_it.ItemName, 1, 24), 26) ||
                RPAD(SUBSTR(NVL(r_it.Brand, 'N/A'), 1, 14), 16) ||
                LPAD(TO_CHAR(r_it.Price, 'FM990.00'), 14) ||
                LPAD(TO_CHAR(r_it.PromoPrice, 'FM990.00'), 14)
            );
        END LOOP;
    END LOOP;

    IF v_promo_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  * No active promotional campaigns at this time.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_active_promotions_catalog;
/

-- Report 2: Promotion Campaign Sales & Customer Uplift Audit (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_promotion_sales_audit (
    p_promo_id IN Promotion.PromotionID%TYPE
) AS
    -- Parent Cursor: Promotion Header
    CURSOR c_promo IS
        SELECT PromotionID, DiscountAmount, StartDate, EndDate
        FROM Promotion
        WHERE PromotionID = p_promo_id;

    -- Child Cursor: Orders where promoted items were purchased
    CURSOR c_promo_orders (cp_promo_id NUMBER) IS
        SELECT o.OrderID, o.OrderDate, m.Name AS CustomerName, i.ItemName, od.Quantity,
               (od.Quantity * od.Discount) AS TotalDiscountSaved
        FROM PromotionItem pi
        JOIN Item i ON pi.ItemID = i.ItemID
        JOIN OrderDetail od ON i.ItemID = od.ItemID
        JOIN CustomerOrder o ON od.OrderID = o.OrderID
        JOIN Member m ON o.MemberID = m.MemberID
        WHERE pi.PromotionID = cp_promo_id AND o.OrderStatus = 'Completed'
        ORDER BY o.OrderDate DESC;

    r_p c_promo%ROWTYPE;
    v_total_units NUMBER := 0;
    v_total_saved NUMBER := 0;
BEGIN
    IF p_promo_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Promotion ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_promo;
    FETCH c_promo INTO r_p;
    IF c_promo%NOTFOUND THEN
        CLOSE c_promo;
        DBMS_OUTPUT.PUT_LINE('Error: Promotion ID #' || p_promo_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_promo;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                  88 SPEEDMART PROMOTION IMPACT & CUSTOMER SAVINGS AUDIT                ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Campaign ID : #' || r_p.PromotionID || ' | Unit Discount: MYR ' || TO_CHAR(r_p.DiscountAmount, 'FM990.00'));
    DBMS_OUTPUT.PUT_LINE('Duration    : ' || TO_CHAR(r_p.StartDate, 'YYYY-MM-DD') || ' to ' || TO_CHAR(r_p.EndDate, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('Order ID', 12) || RPAD('Order Date', 14) || RPAD('Customer Name', 22) || RPAD('Item Purchased', 22) || LPAD('Qty', 6) || LPAD('Saved (MYR)', 14));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_ord IN c_promo_orders(r_p.PromotionID) LOOP
        v_total_units := v_total_units + r_ord.Quantity;
        v_total_saved := v_total_saved + r_ord.TotalDiscountSaved;
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_ord.OrderID, 12) ||
            RPAD(TO_CHAR(r_ord.OrderDate, 'YYYY-MM-DD'), 14) ||
            RPAD(SUBSTR(r_ord.CustomerName, 1, 20), 22) ||
            RPAD(SUBSTR(r_ord.ItemName, 1, 20), 22) ||
            LPAD(r_ord.Quantity, 6) ||
            LPAD(TO_CHAR(r_ord.TotalDiscountSaved, 'FM999,990.00'), 14)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('SUMMARY: Total Promoted Units Sold: ' || v_total_units || ' | Total Discounts Absorbed: MYR ' || TO_CHAR(v_total_saved, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_promotion_sales_audit;
/
