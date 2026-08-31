-- ============================================================================
-- MODULE 2: INVENTORY & PURCHASING MANAGEMENT
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 2
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 2: INVENTORY & PURCHASING MANAGEMENT - MANAGEMENT REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_branch_inventory_audit
-- CLASSIFICATION: On-Demand Detail Audit Report
-- COMPLEXITY: Parameterized Nested Cursors (Branch -> Stock Items -> Audit Write-offs)
-- SCENARIO: Branch managers and internal stock auditors generate a complete
--   physical inventory audit listing shelf quantities, reorder risks, and recent write-offs.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_branch_inventory_audit (
    p_branch_id IN NUMBER
) AS
    -- 1. Parent Cursor: Branch Information
    CURSOR c_branch IS
        SELECT BranchID, BranchName, Address, City, State, BranchPhoneNo, BranchStatus
        FROM Branch
        WHERE BranchID = p_branch_id;

    -- 2. Parameterized Child Cursor 1: Stock on Hand with Reorder Status
    CURSOR c_stock(p_bid NUMBER) IS
        SELECT 
            s.ItemID,
            i.ItemName,
            i.Brand,
            s.ShelfLocation,
            s.Quantity,
            s.ReorderLevel,
            s.MaximumStock,
            i.Price AS RetailPrice,
            (s.Quantity * i.Price) AS TotalValuation,
            CASE 
                WHEN s.Quantity = 0 THEN 'OUT OF STOCK'
                WHEN s.Quantity <= s.ReorderLevel THEN 'REORDER REQUIRED'
                ELSE 'OPTIMAL'
            END AS StockHealthStatus
        FROM Stock s
        JOIN Item i ON s.ItemID = i.ItemID
        WHERE s.BranchID = p_bid
        ORDER BY s.Quantity ASC;

    -- 3. Parameterized Child Cursor 2: Recent Stock Write-offs / Logs
    CURSOR c_logs(p_bid NUMBER) IS
        SELECT 
            sl.StockLogID,
            sl.AdjustmentDate,
            i.ItemName,
            sl.AdjustmentType,
            sl.QuantityChanged,
            e.EmployeeName,
            sl.Remarks
        FROM StockLog sl
        JOIN Item i ON sl.ItemID = i.ItemID
        JOIN Employee e ON sl.EmployeeID = e.EmployeeID
        WHERE sl.BranchID = p_bid
        ORDER BY sl.AdjustmentDate DESC;

    v_br c_branch%ROWTYPE;
    v_total_sku_count NUMBER := 0;
    v_critical_count  NUMBER := 0;
    v_total_valuation NUMBER := 0;
    v_log_count       NUMBER := 0;
BEGIN
    OPEN c_branch;
    FETCH c_branch INTO v_br;

    IF c_branch%NOTFOUND THEN
        CLOSE c_branch;
        DBMS_OUTPUT.PUT_LINE('Error: Branch ID ' || p_branch_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_branch;

    -- Report Header
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
    DBMS_OUTPUT.PUT_LINE('                  88 SPEEDMART - BRANCH INVENTORY & STOCK AUDIT REPORT');
    DBMS_OUTPUT.PUT_LINE('                              Audit Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
    DBMS_OUTPUT.PUT_LINE(' Branch ID : ' || RPAD(v_br.BranchID, 6) || ' Branch Name : ' || v_br.BranchName);
    DBMS_OUTPUT.PUT_LINE(' Address   : ' || RPAD(v_br.Address || ', ' || v_br.City || ', ' || v_br.State, 60));
    DBMS_OUTPUT.PUT_LINE(' Contact   : ' || RPAD(NVL(v_br.BranchPhoneNo, 'N/A'), 20) || ' Status      : ' || v_br.BranchStatus);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

    -- Child Section 1: Stock Inventory Listing
    DBMS_OUTPUT.PUT_LINE(' SECTION 1: LIVE INVENTORY ON HAND & REORDER STATUS');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Item ID', 8) || 
        RPAD('Product Description', 24) || 
        RPAD('Shelf', 12) || 
        LPAD('Qty', 6) || 
        LPAD('Min', 6) || 
        LPAD('Max', 6) || 
        LPAD('Price(RM)', 12) || 
        LPAD('Value(RM)', 12) || 
        LPAD('Status', 14)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

    FOR stk IN c_stock(v_br.BranchID) LOOP
        v_total_sku_count := v_total_sku_count + 1;
        v_total_valuation := v_total_valuation + stk.TotalValuation;

        IF stk.StockHealthStatus IN ('OUT OF STOCK', 'REORDER REQUIRED') THEN
            v_critical_count := v_critical_count + 1;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(stk.ItemID, 8) || 
            RPAD(SUBSTR(stk.ItemName, 1, 22), 24) || 
            RPAD(NVL(stk.ShelfLocation, 'N/A'), 12) || 
            LPAD(stk.Quantity, 6) || 
            LPAD(stk.ReorderLevel, 6) || 
            LPAD(stk.MaximumStock, 6) || 
            LPAD(TO_CHAR(stk.RetailPrice, 'FM990.00'), 12) || 
            LPAD(TO_CHAR(stk.TotalValuation, 'FM999,990.00'), 12) || 
            LPAD(stk.StockHealthStatus, 14)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
    DBMS_OUTPUT.PUT_LINE(' Summary: ' || v_total_sku_count || ' SKUs Stocked | ' || 
                         v_critical_count || ' Reorder Alerts | Total Branch Valuation: RM ' || 
                         TO_CHAR(v_total_valuation, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));

    -- Child Section 2: Recent Stock Write-offs
    DBMS_OUTPUT.PUT_LINE(' SECTION 2: RECENT STOCK WRITE-OFFS & ADJUSTMENTS (RULE 19/20 AUDIT)');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Log ID', 8) || 
        RPAD('Date', 12) || 
        RPAD('Product Name', 22) || 
        RPAD('Adj Type', 12) || 
        LPAD('Delta', 7) || 
        RPAD(' Staff Auditor', 18) || 
        RPAD('Remarks', 21)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

    FOR lg IN c_logs(v_br.BranchID) LOOP
        v_log_count := v_log_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(lg.StockLogID, 8) || 
            RPAD(TO_CHAR(lg.AdjustmentDate, 'YYYY-MM-DD'), 12) || 
            RPAD(SUBSTR(lg.ItemName, 1, 20), 22) || 
            RPAD(lg.AdjustmentType, 12) || 
            LPAD(lg.QuantityChanged, 7) || ' ' ||
            RPAD(SUBSTR(lg.EmployeeName, 1, 16), 17) || 
            RPAD(SUBSTR(NVL(lg.Remarks, 'None'), 1, 20), 21)
        );
    END LOOP;

    IF v_log_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No historical adjustment logs on record for this branch.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 100, '='));
    DBMS_OUTPUT.PUT_LINE(' [END OF BRANCH INVENTORY AUDIT REPORT]');
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_branch_inventory_audit;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_supplier_procurement_dossier
-- CLASSIFICATION: Procurement Summary & PO Hierarchy Report
-- COMPLEXITY: 3-Tier Parameterized Nested Cursor (Supplier -> POs -> PO Items)
-- SCENARIO: Procurement executives review historical purchasing orders and item-level
--   expenditures associated with each authorized supplier.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_supplier_procurement_dossier (
    p_supplier_id IN NUMBER
) AS
    -- 1. Parent Cursor: Supplier Profile
    CURSOR c_supplier IS
        SELECT SupplierID, CompanyName, PhoneNo, Email, Address, City, SupplierStatus
        FROM Supplier
        WHERE SupplierID = p_supplier_id;

    -- 2. Parameterized Child Cursor 1: Purchase Orders
    CURSOR c_pos(p_sid NUMBER) IS
        SELECT PurchaseOrderID, OrderDate, Status
        FROM PurchaseOrder
        WHERE SupplierID = p_sid
        ORDER BY OrderDate DESC;

    -- 3. Parameterized Grandchild Cursor 2: Line Items for each PO
    CURSOR c_po_items(p_poid NUMBER) IS
        SELECT 
            poi.ItemID,
            i.ItemName,
            i.Brand,
            poi.Quantity,
            poi.CostPrice,
            (poi.Quantity * poi.CostPrice) AS LineCostTotal
        FROM PurchaseOrderItem poi
        JOIN Item i ON poi.ItemID = i.ItemID
        WHERE poi.PurchaseOrderID = p_poid;

    v_sup c_supplier%ROWTYPE;
    v_po_count NUMBER := 0;
    v_supplier_total_spend NUMBER := 0;
    v_po_total NUMBER := 0;
BEGIN
    OPEN c_supplier;
    FETCH c_supplier INTO v_sup;

    IF c_supplier%NOTFOUND THEN
        CLOSE c_supplier;
        DBMS_OUTPUT.PUT_LINE('Error: Supplier ID ' || p_supplier_id || ' does not exist.');
        RETURN;
    END IF;
    CLOSE c_supplier;

    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('                  88 SPEEDMART - SUPPLIER PROCUREMENT DOSSIER');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Supplier ID : ' || RPAD(v_sup.SupplierID, 6) || ' Company  : ' || v_sup.CompanyName);
    DBMS_OUTPUT.PUT_LINE(' Contact     : ' || RPAD(NVL(v_sup.PhoneNo, 'N/A'), 20) || ' Email    : ' || NVL(v_sup.Email, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(' Status      : ' || RPAD(v_sup.SupplierStatus, 15) || ' Location : ' || v_sup.City);
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));

    FOR po IN c_pos(v_sup.SupplierID) LOOP
        v_po_count := v_po_count + 1;
        v_po_total := 0;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(' >> PURCHASE ORDER #' || po.PurchaseOrderID || ' | Date: ' || 
                             TO_CHAR(po.OrderDate, 'YYYY-MM-DD') || ' | Status: ' || po.Status);
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('    Item ID', 12) || 
            RPAD('Product Description', 30) || 
            RPAD('Brand', 20) || 
            LPAD('Qty', 8) || 
            LPAD('Unit Cost(RM)', 16) || 
            LPAD('Subtotal(RM)', 16)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

        FOR item IN c_po_items(po.PurchaseOrderID) LOOP
            v_po_total := v_po_total + item.LineCostTotal;

            DBMS_OUTPUT.PUT_LINE(
                RPAD('    ' || item.ItemID, 12) || 
                RPAD(SUBSTR(item.ItemName, 1, 28), 30) || 
                RPAD(SUBSTR(NVL(item.Brand, 'Generic'), 1, 18), 20) || 
                LPAD(item.Quantity, 8) || 
                LPAD(TO_CHAR(item.CostPrice, 'FM990.00'), 16) || 
                LPAD(TO_CHAR(item.LineCostTotal, 'FM999,990.00'), 16)
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(RPAD('.', 105, '.'));
        DBMS_OUTPUT.PUT_LINE('    >> PO Total Spend: RM ' || TO_CHAR(v_po_total, 'FM999,990.00'));
        v_supplier_total_spend := v_supplier_total_spend + v_po_total;
    END LOOP;

    IF v_po_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(' >>> No historical purchase orders found for this supplier.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' CUMULATIVE PROCUREMENT SUMMARY:');
    DBMS_OUTPUT.PUT_LINE(' Total Purchase Orders Issued: ' || v_po_count);
    DBMS_OUTPUT.PUT_LINE(' Total Spend Disbursed to Supplier: RM ' || TO_CHAR(v_supplier_total_spend, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
END sp_rpt_supplier_procurement_dossier;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_branch_inventory_audit (Branch ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_branch_inventory_audit(1);

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_supplier_procurement_dossier (Supplier ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_supplier_procurement_dossier(1);
