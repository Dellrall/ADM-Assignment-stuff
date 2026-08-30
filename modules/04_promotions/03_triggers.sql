-- ============================================================================
-- MODULE 4: PROMOTION & MARKETING MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 4
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 4: PROMOTION & MARKETING MANAGEMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_promotion_dates
-- SCENARIO: Enforces Campaign Duration Integrity.
--   Rejects any promotion where EndDate is less than or equal to StartDate.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_promotion_dates
BEFORE INSERT OR UPDATE ON Promotion
FOR EACH ROW
WHEN (NEW.EndDate <= NEW.StartDate)
BEGIN
    RAISE_APPLICATION_ERROR(-20045, 'Trigger Violation: Promotion EndDate must be strictly later than StartDate.');
END trg_guard_promotion_dates;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_guard_promo_item_discount
-- SCENARIO: Enforces Commercial Margin Protection.
--   Prevents enrolling an item into a promotion if the campaign's discount amount
--   exceeds or equals the item's retail base price (preventing negative selling price).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_promo_item_discount
BEFORE INSERT OR UPDATE ON PromotionItem
FOR EACH ROW
DECLARE
    v_item_price   NUMBER;
    v_promo_disc   NUMBER;
BEGIN
    -- Query Item price
    SELECT Price INTO v_item_price
    FROM Item
    WHERE ItemID = :NEW.ItemID;

    -- Query Promotion discount
    SELECT DiscountAmount INTO v_promo_disc
    FROM Promotion
    WHERE PromotionID = :NEW.PromotionID;

    IF v_promo_disc >= v_item_price THEN
        RAISE_APPLICATION_ERROR(-20046, 'Trigger Violation: Promotion discount (RM ' || 
                                TO_CHAR(v_promo_disc, 'FM990.00') || ') cannot equal or exceed item retail price (RM ' || 
                                TO_CHAR(v_item_price, 'FM990.00') || ').');
    END IF;
END trg_guard_promo_item_discount;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_promotion_dates
PROMPT ============================================================================

BEGIN
    -- Attempt invalid promotion with EndDate earlier than StartDate
    INSERT INTO Promotion (PromotionID, DiscountAmount, StartDate, EndDate)
    VALUES (999903, 3.00, SYSDATE + 5, SYSDATE);
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Invalid Dates): ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_guard_promo_item_discount
PROMPT ============================================================================

DECLARE
    v_promo_id NUMBER := 999904;
    v_item_id  NUMBER;
    v_price    NUMBER;
BEGIN
    -- Find lowest priced item
    SELECT ItemID, Price INTO v_item_id, v_price 
    FROM Item 
    WHERE Price = (SELECT MIN(Price) FROM Item) AND ROWNUM = 1;

    -- Create a promotion with huge discount
    INSERT INTO Promotion (PromotionID, DiscountAmount, StartDate, EndDate)
    VALUES (v_promo_id, v_price + 10.00, SYSDATE, SYSDATE + 7);

    -- Attempt to attach this deep discount to the cheap item (Trigger should block!)
    INSERT INTO PromotionItem (PromotionID, ItemID)
    VALUES (v_promo_id, v_item_id);

    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Excessive Discount): ' || SQLERRM);
        ROLLBACK;
END;
/
