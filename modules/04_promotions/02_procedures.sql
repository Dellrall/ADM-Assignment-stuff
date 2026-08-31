-- ============================================================================
-- MODULE 4: PROMOTION & MARKETING MANAGEMENT
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 4
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 4: PROMOTION & MARKETING MANAGEMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_create_promotional_campaign
-- SCENARIO: Sets up a marketing campaign and enrolls grocery items.
--   Enforces valid date chronology (EndDate > StartDate) and pricing bounds
--   (DiscountAmount < Item.Price).
--   Task 8 Features: Sequence (seq_promo_id), Custom Exceptions, 
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
--                    Multi-table atomic inserts, RAISE_APPLICATION_ERROR.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_create_promotional_campaign (
    p_discount_amount IN  NUMBER,
    p_start_date      IN  DATE,
    p_end_date        IN  DATE,
    p_item_id         IN  NUMBER,
    p_new_promo_id    OUT NUMBER,
    p_status_msg      OUT VARCHAR2
) AS
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - CUSTOM USER EXCEPTION]
    -- Custom Exceptions
    e_invalid_dates      EXCEPTION;
    e_negative_discount  EXCEPTION;
    e_excessive_discount EXCEPTION;
    e_item_unavailable   EXCEPTION;

    v_item_price  NUMBER;
    v_item_status VARCHAR2(20);
    v_item_name   VARCHAR2(100);
BEGIN
    -- 1. Validate Promotional Duration
    IF p_end_date <= p_start_date THEN
        RAISE e_invalid_dates;
    END IF;

    IF p_discount_amount <= 0 THEN
        RAISE e_negative_discount;
    END IF;

    -- 2. Validate Item Eligibility & Pricing Thresholds
    SELECT Price, ItemStatus, ItemName 
    INTO v_item_price, v_item_status, v_item_name
    FROM Item
    WHERE ItemID = p_item_id;

    IF v_item_status != 'Available' THEN
        RAISE e_item_unavailable;
    END IF;

    IF p_discount_amount >= v_item_price THEN
        RAISE e_excessive_discount;
    END IF;

    -- 3. Create Promotion & Enroll Item
    p_new_promo_id := seq_promo_id.NEXTVAL;

    INSERT INTO Promotion (
        PromotionID, DiscountAmount, StartDate, EndDate
    ) VALUES (
        p_new_promo_id,
        p_discount_amount,
        p_start_date,
        p_end_date
    );

    INSERT INTO PromotionItem (
        PromotionID, ItemID
    ) VALUES (
        p_new_promo_id,
        p_item_id
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Campaign #' || p_new_promo_id || ' launched (Discount RM ' || 
                    TO_CHAR(p_discount_amount, 'FM990.00') || ') for [' || v_item_name || '].';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Item ID #' || p_item_id || ' does not exist in catalog.';
        RAISE_APPLICATION_ERROR(-20041, p_status_msg);

    WHEN e_invalid_dates THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Promotion End Date must be strictly later than Start Date.';
        RAISE_APPLICATION_ERROR(-20042, p_status_msg);

    WHEN e_negative_discount THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Promotional discount must be strictly positive.';
        RAISE_APPLICATION_ERROR(-20043, p_status_msg);

    WHEN e_item_unavailable THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Item #' || p_item_id || ' is currently marked Unavailable.';
        RAISE_APPLICATION_ERROR(-20044, p_status_msg);

    WHEN e_excessive_discount THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Promotional discount (RM ' || TO_CHAR(p_discount_amount, 'FM990.00') || 
                        ') cannot equal or exceed item retail price (RM ' || TO_CHAR(v_item_price, 'FM990.00') || ').';
        RAISE_APPLICATION_ERROR(-20045, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20046, p_status_msg);
END sp_create_promotional_campaign;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_apply_order_promo_discount
-- SCENARIO: Dynamically evaluates and applies active promotional discounts 
--   to pending order lines before final checkout settlement.
--   Task 8 Features: PRAGMA EXCEPTION_INIT(-1438), Cursor update with FOR UPDATE.
-- >>> [TASK 8 EXTRA EFFORT: RAISE_APPLICATION_ERROR & EXCEPTION HANDLING SUITE]
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_apply_order_promo_discount (
    p_order_id           IN  NUMBER,
    p_discounts_updated  OUT NUMBER,
    p_total_savings      OUT NUMBER,
    p_status_msg         OUT VARCHAR2
) AS
    -- PRAGMA Binding for Oracle Numeric Overflow (ORA-01438)
    -- >>> [TASK 8 EXTRA EFFORT: EXCEPTION TYPE - PRAGMA EXCEPTION_INIT]
    e_numeric_overflow EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_numeric_overflow, -1438);

    -- Custom Exceptions
    e_order_not_pending EXCEPTION;

    v_order_status VARCHAR2(20);
    v_updated_cnt  NUMBER := 0;
    v_savings_sum  NUMBER := 0;

    -- Cursor to iterate through order items and match with active promotions
    CURSOR c_cart_items IS
        SELECT 
            od.ItemID,
            od.Quantity,
            od.UnitPrice,
            NVL(MAX(p.DiscountAmount), 0) AS BestPromoDiscount
        FROM OrderDetail od
        LEFT JOIN PromotionItem pi ON od.ItemID = pi.ItemID
        LEFT JOIN Promotion p ON pi.PromotionID = p.PromotionID
             AND SYSDATE BETWEEN p.StartDate AND p.EndDate
        WHERE od.OrderID = p_order_id
        GROUP BY od.ItemID, od.Quantity, od.UnitPrice;
BEGIN
    -- 1. Validate Order Status
    SELECT OrderStatus INTO v_order_status
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_order_status != 'Pending' THEN
        RAISE e_order_not_pending;
    END IF;

    -- 2. Apply highest active promotion discount per line item
    FOR item_rec IN c_cart_items LOOP
        IF item_rec.BestPromoDiscount > 0 THEN
            UPDATE OrderDetail
            SET Discount = item_rec.BestPromoDiscount
            WHERE OrderID = p_order_id AND ItemID = item_rec.ItemID;

            v_updated_cnt := v_updated_cnt + 1;
            v_savings_sum := v_savings_sum + (item_rec.Quantity * item_rec.BestPromoDiscount);
        END IF;
    END LOOP;

    p_discounts_updated := v_updated_cnt;
    p_total_savings     := v_savings_sum;

    COMMIT;
    p_status_msg := 'SUCCESS: Applied promotional discounts to ' || v_updated_cnt || 
                    ' line item(s). Total Customer Savings: RM ' || TO_CHAR(v_savings_sum, 'FM999,990.00');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Order ID #' || p_order_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20047, p_status_msg);

    WHEN e_order_not_pending THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Cannot re-price order #' || p_order_id || ' because it is already ' || v_order_status;
        RAISE_APPLICATION_ERROR(-20048, p_status_msg);

    WHEN e_numeric_overflow THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Numeric overflow during discount calculation (ORA-01438).';
        RAISE_APPLICATION_ERROR(-20049, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20050, p_status_msg);
END sp_apply_order_promo_discount;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 1: sp_create_promotional_campaign
PROMPT ============================================================================

DECLARE
    v_promo_id NUMBER;
    v_msg      VARCHAR2(400);
BEGIN
    -- Cleanup any existing test promotion records from prior runs
    DELETE FROM PromotionItem WHERE PromotionID >= 1000;
    DELETE FROM Promotion WHERE PromotionID >= 1000;
    COMMIT;

    -- Test 1: Successful Campaign Creation
    sp_create_promotional_campaign(
        p_discount_amount => 2.50,
        p_start_date      => SYSDATE,
        p_end_date        => SYSDATE + 14,
        p_item_id         => 1,
        p_new_promo_id    => v_promo_id,
        p_status_msg      => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional Invalid Date Range (Demonstrating Exception)
    BEGIN
        sp_create_promotional_campaign(
            p_discount_amount => 1.50,
            p_start_date      => SYSDATE + 10,
            p_end_date        => SYSDATE,     -- End before start!
            p_item_id         => 1,
            p_new_promo_id    => v_promo_id,
            p_status_msg      => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception: ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 2: sp_apply_order_promo_discount
PROMPT ============================================================================

DECLARE
    v_test_ord_id NUMBER := 999904;
    v_updated     NUMBER;
    v_savings     NUMBER;
    v_msg         VARCHAR2(400);
BEGIN
    -- Setup temporary test pending order with Item 1 (which has active promotion from Procedure 1)
    DELETE FROM OrderDetail WHERE OrderID = v_test_ord_id;
    DELETE FROM CustomerOrder WHERE OrderID = v_test_ord_id;

    INSERT INTO CustomerOrder (OrderID, OrderDate, OrderTime, OrderStatus, MemberID, BranchID)
    VALUES (v_test_ord_id, SYSDATE, '14:00', 'Pending', 1, 1);

    INSERT INTO OrderDetail (ItemID, OrderID, Quantity, UnitPrice, Discount, LineStatus)
    VALUES (1, v_test_ord_id, 3, 25.90, 0.00, 'Active');
    COMMIT;

    -- Test 1: Successful Order Promotion Discount Application
    sp_apply_order_promo_discount(
        p_order_id          => v_test_ord_id,
        p_discounts_updated => v_updated,
        p_total_savings     => v_savings,
        p_status_msg        => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional Repricing on Already Completed Order (Demonstrating Exception)
    BEGIN
        UPDATE CustomerOrder SET OrderStatus = 'Completed' WHERE OrderID = v_test_ord_id;
        COMMIT;

        sp_apply_order_promo_discount(
            p_order_id          => v_test_ord_id,
            p_discounts_updated => v_updated,
            p_total_savings     => v_savings,
            p_status_msg        => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception: ' || SQLERRM);
    END;
END;
/
