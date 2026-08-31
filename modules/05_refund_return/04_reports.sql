-- ============================================================================
-- MODULE 5: REFUND & RETURN MANAGEMENT (SELECTED ADDITIONAL MODULE)
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 5
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: REFUND & RETURN MANAGEMENT - REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_refund_claim_dossier
-- CLASSIFICATION: On-Demand Refund Investigation & Claim Dossier
-- COMPLEXITY: Parameterized Nested Cursors (Refund Ticket -> Returned Line Items)
-- SCENARIO: Customer service leads and branch managers investigate a specific
--   customer return request by pulling photo evidence, reason, and returned goods.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_refund_claim_dossier (
    p_refund_id IN NUMBER
) AS
    -- 1. Parent Cursor: Refund Ticket & Customer Context
    CURSOR c_refund IS
        SELECT 
            r.RefundID,
            r.RefundDate,
            r.RefundReason,
            r.ReturnMethod,
            r.EvidencePhoto,
            r.RefundAmount,
            r.RefundRemark,
            r.RefundStatus,
            co.OrderID,
            co.OrderDate,
            m.MemberID,
            m.Name AS CustomerName,
            m.PhoneNo,
            b.BranchName,
            p.PaymentMethod,
            p.AmountPaid
        FROM Refund r
        JOIN CustomerOrder co ON r.OrderID = co.OrderID
        JOIN Member m ON co.MemberID = m.MemberID
        JOIN Branch b ON co.BranchID = b.BranchID
        LEFT JOIN Payment p ON co.OrderID = p.OrderID
        WHERE r.RefundID = p_refund_id;

    -- 2. Parameterized Child Cursor: Line Items under this refund
    CURSOR c_items(p_rid NUMBER) IS
        SELECT 
            ri.ItemID,
            i.ItemName,
            i.Brand,
            ri.Quantity,
            ri.ItemCondition,
            i.Price AS UnitRetailPrice,
            (ri.Quantity * i.Price) AS EstimatedLineLoss,
            ri.ReturnRemark
        FROM ReturnItem ri
        JOIN Item i ON ri.ItemID = i.ItemID
        WHERE ri.RefundID = p_rid;

    v_ref c_refund%ROWTYPE;
    v_item_count NUMBER := 0;
    v_loss_total NUMBER := 0;
BEGIN
    OPEN c_refund;
    FETCH c_refund INTO v_ref;

    IF c_refund%NOTFOUND THEN
        CLOSE c_refund;
        DBMS_OUTPUT.PUT_LINE('Error: Refund Claim ID #' || p_refund_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_refund;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('               88 SPEEDMART - RETURN & REFUND CLAIM INVESTIGATION DOSSIER');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Claim Ticket  : [' || v_ref.RefundID || '] Date: ' || TO_CHAR(v_ref.RefundDate, 'YYYY-MM-DD') || 
                         '   Claim Status : ' || v_ref.RefundStatus);
    DBMS_OUTPUT.PUT_LINE(' Order Ref     : Order #' || v_ref.OrderID || ' (Placed: ' || TO_CHAR(v_ref.OrderDate, 'YYYY-MM-DD') || ')');
    DBMS_OUTPUT.PUT_LINE(' Customer Name : ' || RPAD(v_ref.CustomerName || ' (#' || v_ref.MemberID || ')', 35) || ' Contact : ' || NVL(v_ref.PhoneNo, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(' Retail Outlet : ' || RPAD(v_ref.BranchName, 35) || ' Method  : ' || v_ref.ReturnMethod);
    DBMS_OUTPUT.PUT_LINE(' Return Reason : ' || v_ref.RefundReason);
    DBMS_OUTPUT.PUT_LINE(' Photo Proof   : ' || NVL(v_ref.EvidencePhoto, 'None Provided'));
    DBMS_OUTPUT.PUT_LINE(' Staff Remark  : ' || NVL(v_ref.RefundRemark, 'Pending Manager Review'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Item ID', 8) || 
        RPAD('Returned Product Name', 28) || 
        RPAD('Brand', 16) || 
        LPAD('Qty', 6) || 
        RPAD('   Condition', 14) || 
        LPAD('Unit(RM)', 12) || 
        LPAD('Line Total(RM)', 16)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR itm IN c_items(v_ref.RefundID) LOOP
        v_item_count := v_item_count + 1;
        v_loss_total := v_loss_total + itm.EstimatedLineLoss;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(itm.ItemID, 8) || 
            RPAD(SUBSTR(itm.ItemName, 1, 26), 28) || 
            RPAD(SUBSTR(NVL(itm.Brand, 'Generic'), 1, 14), 16) || 
            LPAD(itm.Quantity, 6) || 
            '   ' || RPAD(itm.ItemCondition, 11) || 
            LPAD(TO_CHAR(itm.UnitRetailPrice, 'FM990.00'), 12) || 
            LPAD(TO_CHAR(itm.EstimatedLineLoss, 'FM999,990.00'), 16)
        );
    END LOOP;

    IF v_item_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No item records attached to this claim ticket.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(LPAD('Original Order Paid Amount: RM ', 75) || LPAD(TO_CHAR(NVL(v_ref.AmountPaid, 0), 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(LPAD('TOTAL REFUND PAYOUT CLAIM : RM ', 75) || LPAD(TO_CHAR(v_ref.RefundAmount, 'FM999,990.00'), 15));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' [END OF REFUND CLAIM DOSSIER]');
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_refund_claim_dossier;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_branch_spoilage_quality_audit
-- CLASSIFICATION: Branch Quality Defect & Return Summary Audit
-- COMPLEXITY: 3-Tier Parameterized Nested Cursor (Branch -> Refund Incidents -> Return Items)
-- SCENARIO: Quality control executives monitor damaged and expired grocery returns
--   across physical retail outlets to identify store handling failures or bad batches.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_branch_spoilage_quality_audit (
    p_branch_id IN NUMBER
) AS
    -- 1. Parent Cursor: Branch Information
    CURSOR c_branch IS
        SELECT BranchID, BranchName, Address, City, State, BranchPhoneNo
        FROM Branch
        WHERE BranchID = p_branch_id;

    -- 2. Parameterized Child Cursor 1: Refund Incidents at this Branch
    CURSOR c_claims(p_bid NUMBER) IS
        SELECT 
            r.RefundID,
            r.RefundDate,
            r.RefundStatus,
            r.RefundAmount,
            r.RefundReason,
            m.Name AS CustomerName,
            co.OrderID
        FROM Refund r
        JOIN CustomerOrder co ON r.OrderID = co.OrderID
        JOIN Member m ON co.MemberID = m.MemberID
        WHERE co.BranchID = p_bid
        ORDER BY r.RefundDate DESC;

    -- 3. Parameterized Grandchild Cursor 2: Defective Items under each claim
    CURSOR c_defective_items(p_rid NUMBER) IS
        SELECT 
            ri.ItemID,
            i.ItemName,
            ri.Quantity,
            ri.ItemCondition
        FROM ReturnItem ri
        JOIN Item i ON ri.ItemID = i.ItemID
        WHERE ri.RefundID = p_rid;

    v_br c_branch%ROWTYPE;
    v_claim_count NUMBER := 0;
    v_refund_grand_total NUMBER := 0;
BEGIN
    OPEN c_branch;
    FETCH c_branch INTO v_br;

    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID #' || p_branch_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_branch;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('              88 SPEEDMART - BRANCH SPOILAGE & RETURN QUALITY AUDIT');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Branch Outlet : [' || v_br.BranchID || '] ' || v_br.BranchName);
    DBMS_OUTPUT.PUT_LINE(' Location      : ' || v_br.Address || ', ' || v_br.City || ', ' || v_br.State);
    DBMS_OUTPUT.PUT_LINE(' Contact Phone : ' || NVL(v_br.BranchPhoneNo, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR clm IN c_claims(v_br.BranchID) LOOP
        v_claim_count := v_claim_count + 1;
        v_refund_grand_total := v_refund_grand_total + clm.RefundAmount;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(' >> REFUND TICKET #' || clm.RefundID || ' | Order #' || clm.OrderID || 
                             ' | Date: ' || TO_CHAR(clm.RefundDate, 'YYYY-MM-DD') || 
                             ' | Status: ' || clm.RefundStatus || 
                             ' | Refund: RM ' || TO_CHAR(clm.RefundAmount, 'FM990.00'));
        DBMS_OUTPUT.PUT_LINE('    Customer: ' || clm.CustomerName || ' | Reason: ' || clm.RefundReason);
        DBMS_OUTPUT.PUT_LINE(RPAD('    -', 105, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('      Item ID', 14) || 
            RPAD('Defective Product Name', 35) || 
            LPAD('Qty', 6) || 
            RPAD('     Condition', 20)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('    -', 105, '-'));

        FOR def IN c_defective_items(clm.RefundID) LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD('      ' || def.ItemID, 14) || 
                RPAD(SUBSTR(def.ItemName, 1, 33), 35) || 
                LPAD(def.Quantity, 6) || 
                '     ' || RPAD(def.ItemCondition, 15)
            );
        END LOOP;
    END LOOP;

    IF v_claim_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(' >>> No customer refund incidents recorded for this branch.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' BRANCH DEFECT SUMMARY:');
    DBMS_OUTPUT.PUT_LINE(' Total Return Claims Filed : ' || v_claim_count);
    DBMS_OUTPUT.PUT_LINE(' Cumulative Refund Value   : RM ' || TO_CHAR(v_refund_grand_total, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
END sp_rpt_branch_spoilage_quality_audit;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_refund_claim_dossier (Refund ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_refund_claim_dossier(1);

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_branch_spoilage_quality_audit (Branch ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_branch_spoilage_quality_audit(1);
