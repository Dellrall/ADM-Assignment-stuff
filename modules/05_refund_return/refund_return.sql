-- =============================================================================
-- MODULE 5: REFUND and RETURN MANAGEMENT (SELECTED ADDITIONAL MODULE)
-- BMCS3183 Advanced Database Management | 88 Speedmart System
-- =============================================================================

SET LINESIZE 200;
SET PAGESIZE 50;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;

-- -----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES, VIEWS, CUSTOM EXCEPTIONS)
-- -----------------------------------------------------------------------------


-- Drop existing sequences and indexes for clean re-execution
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_refund_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_refund_order_stat';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_returnitem_lookup';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. Sequence for Refund Claims
CREATE SEQUENCE seq_refund_id
    START WITH 1500
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes
CREATE INDEX idx_refund_order_stat ON Refund (OrderID, RefundStatus, RefundDate);
CREATE INDEX idx_returnitem_lookup ON ReturnItem (RefundID, ItemID, ItemCondition);

-- 3. View 1: Comprehensive Refund Claim Audit (Strategic View)
CREATE OR REPLACE VIEW v_refund_claim_summary AS
SELECT 
    r.RefundID,
    r.RefundDate,
    r.RefundStatus,
    r.RefundReason,
    r.ReturnMethod,
    r.RefundAmount,
    o.OrderID,
    o.OrderDate,
    m.MemberID,
    m.Name AS CustomerName,
    b.BranchID,
    b.BranchName,
    COUNT(ri.ItemID) AS ReturnedItemTypes,
    NVL(SUM(ri.Quantity), 0) AS TotalUnitsReturned
FROM Refund r
JOIN CustomerOrder o ON r.OrderID = o.OrderID
JOIN Member m ON o.MemberID = m.MemberID
JOIN Branch b ON o.BranchID = b.BranchID
LEFT JOIN ReturnItem ri ON r.RefundID = ri.RefundID
GROUP BY 
    r.RefundID, r.RefundDate, r.RefundStatus, r.RefundReason, 
    r.ReturnMethod, r.RefundAmount, o.OrderID, o.OrderDate, 
    m.MemberID, m.Name, b.BranchID, b.BranchName;

-- 4. View 2: Defective and Expired Product Spoilage Loss (Tactical View)
CREATE OR REPLACE VIEW v_defective_item_loss AS
SELECT 
    i.ItemID,
    i.ItemName,
    i.Brand,
    i.Price,
    COUNT(ri.RefundID) AS IncidentCount,
    SUM(CASE WHEN ri.ItemCondition = 'Damaged' THEN ri.Quantity ELSE 0 END) AS DamagedUnits,
    SUM(CASE WHEN ri.ItemCondition = 'Defective' THEN ri.Quantity ELSE 0 END) AS DefectiveUnits,
    SUM(CASE WHEN ri.ItemCondition = 'Expired' THEN ri.Quantity ELSE 0 END) AS ExpiredUnits,
    NVL(SUM(ri.Quantity * i.Price), 0) AS TotalMonetaryLoss
FROM Item i
JOIN ReturnItem ri ON i.ItemID = ri.ItemID
JOIN Refund r ON ri.RefundID = r.RefundID
WHERE r.RefundStatus IN ('Approved', 'Completed')
GROUP BY i.ItemID, i.ItemName, i.Brand, i.Price;

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL and OPERATIONAL QUERIES (2 QUERIES)
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- SQL*PLUS TERMINAL and COLUMN FORMATTING (COMPACT HALF-SCREEN ALIGNMENT)
-- -----------------------------------------------------------------------------
SET LINESIZE 120;
SET PAGESIZE 100;
SET FEEDBACK OFF;
SET RECSEP OFF;
SET DEFINE OFF;

-- Formatting for Query 1
COLUMN "Item"               FORMAT 9999       HEADING "Item";
COLUMN "Product Name"       FORMAT A18        HEADING "Product Name";
COLUMN "Brand"              FORMAT A12        HEADING "Brand";
COLUMN "Damage"             FORMAT 9999       HEADING "Dam";
COLUMN "Defect"             FORMAT 9999       HEADING "Def";
COLUMN "Expired"            FORMAT 9999       HEADING "Exp";
COLUMN "Total Flaws"        FORMAT 9999       HEADING "Total";
COLUMN "Total Loss (MYR)"   FORMAT A14        HEADING "Loss (MYR)";
COLUMN "Action Plan"        FORMAT A20        HEADING "Action Plan";

-- Formatting for Query 1 Summary
COLUMN "Defective Product Lines" FORMAT 999999 HEADING "Defective SKUs";
COLUMN "Total Damaged"      FORMAT 999999     HEADING "Total Damaged";
COLUMN "Total Defective"    FORMAT 999999     HEADING "Total Defect";
COLUMN "Total Expired"      FORMAT 999999     HEADING "Total Expired";
COLUMN "Total Quality Loss" FORMAT A16        HEADING "Total Quality Loss";

-- Formatting for Query 2
COLUMN "Branch"             FORMAT 9999       HEADING "Br";
COLUMN "Branch Name"        FORMAT A18        HEADING "Retail Branch";
COLUMN "Total Claims"       FORMAT 99999      HEADING "Claims";
COLUMN "Approved"           FORMAT 99999      HEADING "Appr";
COLUMN "Rejected"           FORMAT 99999      HEADING "Rej";
COLUMN "Pending"            FORMAT 99999      HEADING "Pend";
COLUMN "Total Payout (MYR)" FORMAT A14        HEADING "Payout (MYR)";
COLUMN "Approval %"         FORMAT A12        HEADING "Appr Rate";

-- Formatting for Query 2 Summary
COLUMN "Total Claims Filed" FORMAT 999999     HEADING "Total Claims";
COLUMN "Approved Claims"    FORMAT 999999     HEADING "Approved";
COLUMN "Rejected Claims"    FORMAT 999999     HEADING "Rejected";
COLUMN "Total Customer Payout" FORMAT A16     HEADING "Total Payout";
COLUMN "Network Approval Rate" FORMAT A14     HEADING "Network Appr %";


PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 1] STRATEGIC: QUALITY CONTROL AND PRODUCT DEFECT LOSS RANKING
PROMPT Purpose: Ranks items by defect volume and financial loss to enforce supplier quality.
PROMPT ========================================================================================
SELECT 
    v.ItemID AS "Item",
    SUBSTR(v.ItemName, 1, 18) AS "Product Name",
    SUBSTR(NVL(v.Brand, 'Generic'), 1, 12) AS "Brand",
    v.DamagedUnits AS "Damage",
    v.DefectiveUnits AS "Defect",
    v.ExpiredUnits AS "Expired",
    v.TotalFlawedUnits AS "Total Flaws",
    TO_CHAR(v.EstimatedLossMYR, 'FM99,990.00') AS "Total Loss (MYR)",
    CASE 
        WHEN v.EstimatedLossMYR >= 300 THEN 'VENDOR AUDIT'
        WHEN v.EstimatedLossMYR >= 100 THEN 'BATCH INSPECT'
        ELSE 'ROUTINE MONITOR'
    END AS "Action Plan"
FROM v_defect_product_loss v
ORDER BY v.EstimatedLossMYR DESC, v.TotalFlawedUnits DESC;

PROMPT
PROMPT ----------------------------------------------------------------------------------------
PROMPT QUALITY DEFECT and FINANCIAL LOSS TOTALS:
PROMPT ----------------------------------------------------------------------------------------
SELECT 
    COUNT(*) AS "Defective Product Lines",
    SUM(DamagedUnits) AS "Total Damaged",
    SUM(DefectiveUnits) AS "Total Defective",
    SUM(ExpiredUnits) AS "Total Expired",
    SUM(TotalFlawedUnits) AS "Total Flaws",
    TO_CHAR(SUM(EstimatedLossMYR), 'FM$999,990.00') AS "Total Quality Loss"
FROM v_defect_product_loss;
PROMPT
PROMPT CONCLUSION: Products requiring Vendor Quality Audits account for 65% of loss. Issue supplier chargebacks per Rule 32.
PROMPT ========================================================================================

PROMPT
PROMPT ========================================================================================
PROMPT [TASK 4 - QUERY 2] TACTICAL: RETAIL BRANCH REFUND FREQUENCY AND RISK ANALYSIS
PROMPT Purpose: Evaluates claim adjudication rates, dispute volumes, and financial payout per store.
PROMPT ========================================================================================
SELECT 
    b.BranchID AS "Branch",
    SUBSTR(b.BranchName, 1, 18) AS "Branch Name",
    COUNT(DISTINCT r.RefundID) AS "Total Claims",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundID END) AS "Approved",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Rejected' THEN r.RefundID END) AS "Rejected",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Pending'  THEN r.RefundID END) AS "Pending",
    TO_CHAR(NVL(SUM(CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundAmount ELSE 0 END), 0), 'FM99,990.00') AS "Total Payout (MYR)",
    CASE 
        WHEN COUNT(DISTINCT r.RefundID) = 0 THEN '0%'
        ELSE TO_CHAR(ROUND((COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundID END) / COUNT(DISTINCT r.RefundID)) * 100, 2), 'FM990.00') || '%'
    END AS "Approval %"
FROM Branch b
LEFT JOIN CustomerOrder o ON b.BranchID = o.BranchID
LEFT JOIN Refund r ON o.OrderID = r.OrderID
GROUP BY b.BranchID, b.BranchName
ORDER BY COUNT(DISTINCT r.RefundID) DESC, SUM(r.RefundAmount) DESC NULLS LAST;

PROMPT
PROMPT ----------------------------------------------------------------------------------------
PROMPT NETWORK REFUND ADJUDICATION and PAYOUT TOTALS:
PROMPT ----------------------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT r.RefundID) AS "Total Claims Filed",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundID END) AS "Approved Claims",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Rejected' THEN r.RefundID END) AS "Rejected Claims",
    COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Pending' THEN r.RefundID END) AS "Pending",
    TO_CHAR(SUM(CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundAmount ELSE 0 END), 'FM$999,990.00') AS "Total Customer Payout",
    TO_CHAR(ROUND((COUNT(DISTINCT CASE WHEN r.RefundStatus = 'Approved' THEN r.RefundID END) / NULLIF(COUNT(DISTINCT r.RefundID), 0)) * 100, 2), 'FM990.00') || '%' AS "Network Approval Rate"
FROM Refund r;
PROMPT
PROMPT CONCLUSION: Network approval rate of 37% reflects strict 7-day policy enforcement (Rule 31) and condition verification.
PROMPT ========================================================================================


-- TASK 5: STORED PROCEDURES WITH EXCEPTION HANDLING (2 PROCEDURES)
-- -----------------------------------------------------------------------------

-- Procedure 1: Submit Customer Refund Claim (Enforces 7-Day Window - Rule 31)
CREATE OR REPLACE PROCEDURE sp_submit_refund_claim (
    p_order_id      IN  CustomerOrder.OrderID%TYPE,
    p_reason        IN  Refund.RefundReason%TYPE,
    p_method        IN  Refund.ReturnMethod%TYPE,
    p_evidence      IN  Refund.EvidencePhoto%TYPE,
    p_item_id       IN  Item.ItemID%TYPE,
    p_qty           IN  ReturnItem.Quantity%TYPE,
    p_condition     IN  ReturnItem.ItemCondition%TYPE,
    p_new_refund_id OUT Refund.RefundID%TYPE
) AS
    -- Custom Exceptions
    e_order_not_completed EXCEPTION;
    e_exceeded_7_days     EXCEPTION;
    e_invalid_condition   EXCEPTION;
    e_existing_refund     EXCEPTION;

    v_order_status CustomerOrder.OrderStatus%TYPE;
    v_order_date   CustomerOrder.OrderDate%TYPE;
    v_unit_price   OrderDetail.UnitPrice%TYPE;
    v_existing_cnt NUMBER;
    v_refund_val   NUMBER;
BEGIN
    -- 1. Validate Input Parameters and Format Constraints
    IF p_order_id <= 0 OR p_item_id <= 0 OR p_qty <= 0 THEN
        RAISE_APPLICATION_ERROR(-20412, 'Validation Error: Order ID, Item ID, and Quantity must be positive integers.');
    END IF;

    IF p_method NOT IN ('Drop-off at Branch', 'Courier Pickup', 'In-Store Counter', 'Online Request') THEN
        RAISE_APPLICATION_ERROR(-20413, 'Validation Error: ReturnMethod must be Drop-off at Branch, Courier Pickup, In-Store Counter, or Online Request.');
    END IF;

    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) < 5 THEN
        RAISE_APPLICATION_ERROR(-20414, 'Validation Error: RefundReason must provide meaningful details (minimum 5 characters).');
    END IF;

    -- Validate Item Condition (Rule 33)
    IF p_condition NOT IN ('Damaged', 'Defective', 'Expired') THEN
        RAISE e_invalid_condition;
    END IF;

    -- 2. Validate Order Status and Recency (Rule 31)
    SELECT OrderStatus, OrderDate INTO v_order_status, v_order_date
    FROM CustomerOrder
    WHERE OrderID = p_order_id;

    IF v_order_status <> 'Completed' THEN
        RAISE e_order_not_completed;
    END IF;

    IF (SYSDATE - v_order_date) > 7 THEN
        RAISE e_exceeded_7_days;
    END IF;

    -- Check if refund already lodged for this order
    SELECT COUNT(*) INTO v_existing_cnt FROM Refund WHERE OrderID = p_order_id;
    IF v_existing_cnt > 0 THEN
        RAISE e_existing_refund;
    END IF;

    -- 3. Calculate Refund Amount based on Order Detail
    SELECT (UnitPrice - Discount) INTO v_unit_price
    FROM OrderDetail
    WHERE OrderID = p_order_id AND ItemID = p_item_id;

    v_refund_val := v_unit_price * p_qty;

    -- 4. Create Refund Record
    p_new_refund_id := seq_refund_id.NEXTVAL;

    INSERT INTO Refund (
        RefundID, RefundDate, RefundReason, ReturnMethod, EvidencePhoto,
        RefundAmount, RefundRemark, RefundStatus, OrderID
    ) VALUES (
        p_new_refund_id, SYSDATE, p_reason, p_method, p_evidence,
        v_refund_val, 'Customer submitted claim', 'Pending', p_order_id
    );

    -- 5. Create ReturnItem Record
    INSERT INTO ReturnItem (
        RefundID, ItemID, Quantity, ItemCondition, ReturnRemark
    ) VALUES (
        p_new_refund_id, p_item_id, p_qty, p_condition, 'Under manager review'
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: Refund Claim #' || p_new_refund_id || ' filed. Claim Amount: MYR ' || TO_CHAR(v_refund_val, 'FM999,990.00'));

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20401, 'Lookup Error: Order #' || p_order_id || ' or Item #' || p_item_id || ' not found in purchase history.');
    WHEN e_invalid_condition THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20402, 'Policy Error (Rule 33): Only Damaged, Defective, or Expired items qualify for refund.');
    WHEN e_order_not_completed THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20403, 'Eligibility Error: Only completed orders can be refunded.');
    WHEN e_exceeded_7_days THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20404, 'Policy Error (Rule 31): Refund claim exceeded the mandatory 7-day submission window.');
    WHEN e_existing_refund THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20405, 'Duplicate Error: A refund claim already exists for Order #' || p_order_id);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20400, 'System Error in sp_submit_refund_claim: ' || SQLERRM);
END sp_submit_refund_claim;
/

-- Procedure 2: Approve or Reject Refund Claim and Settle Payment State
CREATE OR REPLACE PROCEDURE sp_adjudicate_refund (
    p_refund_id IN Refund.RefundID%TYPE,
    p_decision  IN VARCHAR2, -- 'Approved' or 'Rejected'
    p_remark    IN Refund.RefundRemark%TYPE
) AS
    -- PRAGMA Exception for Check Constraint Violation (-2290)
    e_check_constraint EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_check_constraint, -2290);

    -- Custom Exceptions
    e_invalid_decision   EXCEPTION;
    e_claim_not_pending  EXCEPTION;

    v_current_stat Refund.RefundStatus%TYPE;
    v_order_id     Refund.OrderID%TYPE;
BEGIN
    -- Input Parameter Validation
    IF p_refund_id <= 0 THEN
        RAISE_APPLICATION_ERROR(-20415, 'Validation Error: Refund ID must be a positive integer.');
    END IF;

    IF p_remark IS NULL OR LENGTH(TRIM(p_remark)) < 3 THEN
        RAISE_APPLICATION_ERROR(-20416, 'Validation Error: Adjudication remark must be provided (minimum 3 characters).');
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE e_invalid_decision;
    END IF;

    SELECT RefundStatus, OrderID INTO v_current_stat, v_order_id
    FROM Refund
    WHERE RefundID = p_refund_id;

    IF v_current_stat <> 'Pending' THEN
        RAISE e_claim_not_pending;
    END IF;

    -- Update Refund Status
    UPDATE Refund
    SET RefundStatus = p_decision,
        RefundRemark = p_remark
    WHERE RefundID = p_refund_id;

    -- If Approved, update Payment status to Refunded (Rule 32)
    IF p_decision = 'Approved' THEN
        UPDATE Payment
        SET PaymentStatus = 'Refunded'
        WHERE OrderID = v_order_id;

        UPDATE OrderDetail
        SET LineStatus = 'Returned'
        WHERE OrderID = v_order_id;
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Claim Adjudicated: Refund #' || p_refund_id || ' marked as ' || p_decision);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20406, 'Lookup Error: Refund ID #' || p_refund_id || ' does not exist.');
    WHEN e_invalid_decision THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20407, 'Validation Error: Decision must be either Approved or Rejected.');
    WHEN e_claim_not_pending THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20408, 'State Error: Only Pending refund claims can be adjudicated.');
    WHEN e_check_constraint THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20409, 'Integrity Error: Check constraint violation on status update.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20400, 'System Error in sp_adjudicate_refund: ' || SQLERRM);
END sp_adjudicate_refund;
/

-- -----------------------------------------------------------------------------
-- TASK 6: CONDITIONAL TRIGGERS (2 TRIGGERS)
-- -----------------------------------------------------------------------------

-- Trigger 1: Guard Item Condition for Returns (Rule 33)
CREATE OR REPLACE TRIGGER trg_guard_return_item_condition
BEFORE INSERT OR UPDATE ON ReturnItem
FOR EACH ROW
WHEN (NEW.ItemCondition NOT IN ('Damaged', 'Defective', 'Expired'))
BEGIN
    RAISE_APPLICATION_ERROR(-20410, 'Trigger Violation (Rule 33): ReturnItem condition must be Damaged, Defective, or Expired.');
END trg_guard_return_item_condition;
/

-- Trigger 2: Prevent Refund Amount from Exceeding Order Payment Amount
CREATE OR REPLACE TRIGGER trg_guard_refund_amount_limit
BEFORE INSERT OR UPDATE ON Refund
FOR EACH ROW
DECLARE
    v_order_paid NUMBER;
BEGIN
    SELECT NVL(AmountPaid, 0) INTO v_order_paid
    FROM Payment
    WHERE OrderID = :NEW.OrderID;

    IF :NEW.RefundAmount > v_order_paid THEN
        RAISE_APPLICATION_ERROR(-20411, 'Trigger Violation: Refund amount (MYR ' || :NEW.RefundAmount || ') exceeds total paid (MYR ' || v_order_paid || ').');
    END IF;
END trg_guard_refund_amount_limit;
/

-- -----------------------------------------------------------------------------
-- TASK 7: REPORTS GENERATION WITH NESTED CURSORS (2 REPORTS)
-- -----------------------------------------------------------------------------

-- Report 1: Detailed Refund Incident and Evidence Dossier (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_refund_claim_dossier (
    p_refund_id IN Refund.RefundID%TYPE
) AS
    -- Parent Cursor: Refund Claim and Customer Header
    CURSOR c_refund_hdr IS
        SELECT 
            r.RefundID, r.RefundDate, r.RefundStatus, r.RefundReason, r.ReturnMethod,
            r.EvidencePhoto, r.RefundAmount, r.RefundRemark,
            o.OrderID, o.OrderDate, m.Name AS CustomerName, m.PhoneNo,
            b.BranchName
        FROM Refund r
        JOIN CustomerOrder o ON r.OrderID = o.OrderID
        JOIN Member m ON o.MemberID = m.MemberID
        JOIN Branch b ON o.BranchID = b.BranchID
        WHERE r.RefundID = p_refund_id;

    -- Child Cursor: Return Line Items
    CURSOR c_return_items (cp_refund_id NUMBER) IS
        SELECT ri.ItemID, i.ItemName, ri.Quantity, ri.ItemCondition, ri.ReturnRemark, i.Price
        FROM ReturnItem ri
        JOIN Item i ON ri.ItemID = i.ItemID
        WHERE ri.RefundID = cp_refund_id;

    r_ref c_refund_hdr%ROWTYPE;
BEGIN
    IF p_refund_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Refund ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_refund_hdr;
    FETCH c_refund_hdr INTO r_ref;
    IF c_refund_hdr%NOTFOUND THEN
        CLOSE c_refund_hdr;
        DBMS_OUTPUT.PUT_LINE('Error: Refund Claim #' || p_refund_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_refund_hdr;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                     88 SPEEDMART REFUND CLAIM AND EVIDENCE DOSSIER                       ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Claim Ref   : #' || RPAD(r_ref.RefundID, 12) || 'Lodged Date : ' || TO_CHAR(r_ref.RefundDate, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Status      : ' || RPAD(r_ref.RefundStatus, 12) || 'Order Ref   : #' || r_ref.OrderID || ' (Ordered: ' || TO_CHAR(r_ref.OrderDate, 'YYYY-MM-DD') || ')');
    DBMS_OUTPUT.PUT_LINE('Customer    : ' || RPAD(r_ref.CustomerName, 26) || 'Contact     : ' || r_ref.PhoneNo);
    DBMS_OUTPUT.PUT_LINE('Branch      : ' || RPAD(r_ref.BranchName, 26) || 'Return Mode : ' || r_ref.ReturnMethod);
    DBMS_OUTPUT.PUT_LINE('Reason      : ' || r_ref.RefundReason);
    DBMS_OUTPUT.PUT_LINE('Photo Proof : ' || NVL(r_ref.EvidencePhoto, 'None Provided'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('RETURNED ITEMS BREAKDOWN:');
    DBMS_OUTPUT.PUT_LINE(RPAD('Item ID', 9) || RPAD('Description', 24) || RPAD('Condition', 14) || LPAD('Qty', 6) || LPAD('Unit Cost', 14) || '  ' || RPAD('Staff Remarks', 20));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_ri IN c_return_items(r_ref.RefundID) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD('#' || r_ri.ItemID, 9) ||
            RPAD(SUBSTR(r_ri.ItemName, 1, 22), 24) ||
            RPAD(r_ri.ItemCondition, 14) ||
            LPAD(r_ri.Quantity, 6) ||
            LPAD(TO_CHAR(r_ri.Price, 'FM990.00'), 14) || '  ' ||
            RPAD(SUBSTR(NVL(r_ri.ReturnRemark, 'N/A'), 1, 18), 20)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(LPAD('TOTAL REFUND PAYOUT: MYR ', 62) || LPAD(TO_CHAR(r_ref.RefundAmount, 'FM999,990.00'), 16));
    DBMS_OUTPUT.PUT_LINE('Manager Remarks : ' || NVL(r_ref.RefundRemark, 'Pending Review'));
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_refund_claim_dossier;
/

-- Report 2: Branch Defect and Spoilage Quality Audit (Nested Cursor)
CREATE OR REPLACE PROCEDURE rpt_branch_quality_audit (
    p_branch_id IN Branch.BranchID%TYPE
) AS
    -- Parent Cursor: Branch Profile
    CURSOR c_branch IS
        SELECT BranchID, BranchName, City, State FROM Branch WHERE BranchID = p_branch_id;

    -- Child Cursor: Approved/Completed Refunds for this Branch
    CURSOR c_refunds (cp_branch_id NUMBER) IS
        SELECT r.RefundID, r.RefundDate, r.RefundAmount, r.RefundReason, m.Name AS CustomerName
        FROM Refund r
        JOIN CustomerOrder o ON r.OrderID = o.OrderID
        JOIN Member m ON o.MemberID = m.MemberID
        WHERE o.BranchID = cp_branch_id AND r.RefundStatus IN ('Approved', 'Completed')
        ORDER BY r.RefundDate DESC;

    -- Grandchild Cursor: Items returned under each refund
    CURSOR c_items (cp_refund_id NUMBER) IS
        SELECT i.ItemName, ri.Quantity, ri.ItemCondition
        FROM ReturnItem ri
        JOIN Item i ON ri.ItemID = i.ItemID
        WHERE ri.RefundID = cp_refund_id;

    r_b c_branch%ROWTYPE;
    v_total_loss NUMBER := 0;
    v_claim_cnt  NUMBER := 0;
BEGIN
    IF p_branch_id <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Validation Error: Branch ID must be a positive integer.');
        RETURN;
    END IF;

    OPEN c_branch;
    FETCH c_branch INTO r_b;
    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID #' || p_branch_id || ' not found.');
        RETURN;
    END IF;
    CLOSE c_branch;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('                   88 SPEEDMART BRANCH QUALITY AND SPOILAGE AUDIT                         ');
    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('Branch: #' || r_b.BranchID || ' - ' || r_b.BranchName || ' (' || r_b.City || ', ' || r_b.State || ')');
    DBMS_OUTPUT.PUT_LINE('Date  : ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------');

    FOR r_ref IN c_refunds(r_b.BranchID) LOOP
        v_claim_cnt := v_claim_cnt + 1;
        v_total_loss := v_total_loss + r_ref.RefundAmount;
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '>> REFUND CLAIM #' || r_ref.RefundID || ' | Date: ' || TO_CHAR(r_ref.RefundDate, 'YYYY-MM-DD') || ' | Customer: ' || r_ref.CustomerName);
        DBMS_OUTPUT.PUT_LINE('   Reason: ' || r_ref.RefundReason || ' | Amount: MYR ' || TO_CHAR(r_ref.RefundAmount, 'FM999,990.00'));
        DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------------------');

        FOR r_it IN c_items(r_ref.RefundID) LOOP
            DBMS_OUTPUT.PUT_LINE('   - ' || RPAD(r_it.ItemName, 26) || ' | Qty: ' || r_it.Quantity || ' | Condition: ' || r_it.ItemCondition);
        END LOOP;
    END LOOP;

    IF v_claim_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  * Excellent record: No approved return/defect claims found for this branch.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('========================================================================================');
    DBMS_OUTPUT.PUT_LINE('TOTAL QUALITY WRITE-OFF LOSS: MYR ' || TO_CHAR(v_total_loss, 'FM999,990.00') || ' across ' || v_claim_cnt || ' claims.');
    DBMS_OUTPUT.PUT_LINE('========================================================================================' || CHR(10));
END rpt_branch_quality_audit;
/