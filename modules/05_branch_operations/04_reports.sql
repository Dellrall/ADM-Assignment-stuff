-- ============================================================================
-- MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT
-- SECTION: TASK 7 (NESTED CURSOR MANAGEMENT REPORTS - 8+ MARKS TIER)
-- AUTHOR : Member 5
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT - REPORTS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: sp_rpt_branch_staffing_payroll_dossier
-- CLASSIFICATION: On-Demand Branch Staffing & Payroll Audit Dossier
-- COMPLEXITY: Parameterized Nested Cursors (Branch Master -> Employee Roster)
-- SCENARIO: HR Executives and Area Managers generate a comprehensive staffing
--   and monthly compensation breakdown for a specific retail branch.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_branch_staffing_payroll_dossier (
    p_branch_id IN NUMBER
) AS
    -- 1. Parent Cursor: Branch Details
    CURSOR c_branch IS
        SELECT BranchID, BranchName, Address, City, State, PostCode, BranchEmail, BranchPhoneNo, BranchStatus
        FROM Branch
        WHERE BranchID = p_branch_id;

    -- 2. Parameterized Child Cursor: Employees at this Branch
    CURSOR c_employees(p_bid NUMBER) IS
        SELECT 
            EmployeeID,
            EmployeeName,
            Position,
            PhoneNo,
            Email,
            Salary,
            EmployeeStatus
        FROM Employee
        WHERE BranchID = p_bid
        ORDER BY Salary DESC, EmployeeID ASC;

    v_br c_branch%ROWTYPE;
    v_staff_count   NUMBER := 0;
    v_active_count  NUMBER := 0;
    v_payroll_total NUMBER := 0;
    v_avg_salary    NUMBER := 0;
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
    DBMS_OUTPUT.PUT_LINE('               88 SPEEDMART - BRANCH STAFFING ROSTER & PAYROLL DOSSIER');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' Branch Outlet : [' || v_br.BranchID || '] ' || v_br.BranchName);
    DBMS_OUTPUT.PUT_LINE(' Location      : ' || v_br.Address || ', ' || v_br.City || ', ' || v_br.State || ' (' || NVL(v_br.PostCode, 'N/A') || ')');
    DBMS_OUTPUT.PUT_LINE(' Contact Phone : ' || RPAD(NVL(v_br.BranchPhoneNo, 'N/A'), 20) || ' Email  : ' || NVL(v_br.BranchEmail, 'N/A'));
    DBMS_OUTPUT.PUT_LINE(' Store Status  : ' || v_br.BranchStatus);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Emp ID', 8) || 
        RPAD('Employee Name', 24) || 
        RPAD('Job Position', 20) || 
        RPAD('Phone No', 16) || 
        RPAD('Status', 12) || 
        LPAD('Monthly Salary(RM)', 22)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

    FOR emp IN c_employees(v_br.BranchID) LOOP
        v_staff_count := v_staff_count + 1;
        
        IF emp.EmployeeStatus = 'Active' THEN
            v_active_count  := v_active_count + 1;
            v_payroll_total := v_payroll_total + emp.Salary;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(emp.EmployeeID, 8) || 
            RPAD(SUBSTR(emp.EmployeeName, 1, 22), 24) || 
            RPAD(SUBSTR(emp.Position, 1, 18), 20) || 
            RPAD(NVL(emp.PhoneNo, 'N/A'), 16) || 
            RPAD(emp.EmployeeStatus, 12) || 
            LPAD(TO_CHAR(emp.Salary, 'FM999,990.00'), 22)
        );
    END LOOP;

    IF v_staff_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   >>> No staff members currently assigned to this branch.');
    END IF;

    IF v_active_count > 0 THEN
        v_avg_salary := ROUND(v_payroll_total / v_active_count, 2);
    END IF;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
    DBMS_OUTPUT.PUT_LINE(' BRANCH PAYROLL & STAFFING SUMMARY:');
    DBMS_OUTPUT.PUT_LINE(' Total Assigned Staff  : ' || v_staff_count || ' (' || v_active_count || ' Active)');
    DBMS_OUTPUT.PUT_LINE(' Total Monthly Payroll : RM ' || TO_CHAR(v_payroll_total, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(' Average Staff Salary  : RM ' || TO_CHAR(v_avg_salary, 'FM999,990.00') || ' / month');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' [END OF BRANCH STAFFING DOSSIER]');
    DBMS_OUTPUT.PUT_LINE('');
END sp_rpt_branch_staffing_payroll_dossier;
/


-- ----------------------------------------------------------------------------
-- REPORT 2: sp_rpt_nationwide_branch_performance_summary
-- CLASSIFICATION: Nationwide Regional Operational Summary Report
-- COMPLEXITY: Parameterized Nested Cursors (State Region -> Retail Branches)
-- SCENARIO: Board of Directors and Operations Executives review commercial 
--   performance, staffing strength, and GMV revenue across all Malaysian states.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_rpt_nationwide_branch_performance_summary AS
    -- 1. Parent Cursor: Distinct States
    CURSOR c_states IS
        SELECT DISTINCT State
        FROM Branch
        ORDER BY State ASC;

    -- 2. Parameterized Child Cursor: Branches in that State
    CURSOR c_branches(p_state VARCHAR2) IS
        SELECT 
            b.BranchID,
            b.BranchName,
            b.City,
            b.BranchStatus,
            COUNT(DISTINCT e.EmployeeID) AS ActiveStaff,
            COUNT(DISTINCT co.OrderID) AS OrdersCompleted,
            NVL(SUM(p.AmountPaid), 0) AS TotalRevenue
        FROM Branch b
        LEFT JOIN Employee e ON b.BranchID = e.BranchID AND e.EmployeeStatus = 'Active'
        LEFT JOIN CustomerOrder co ON b.BranchID = co.BranchID AND co.OrderStatus = 'Completed'
        LEFT JOIN Payment p ON co.OrderID = p.OrderID AND p.PaymentStatus = 'Paid'
        WHERE b.State = p_state
        GROUP BY b.BranchID, b.BranchName, b.City, b.BranchStatus
        ORDER BY TotalRevenue DESC;

    v_nationwide_branches NUMBER := 0;
    v_nationwide_staff    NUMBER := 0;
    v_nationwide_orders   NUMBER := 0;
    v_nationwide_revenue  NUMBER := 0;

    v_state_branches NUMBER := 0;
    v_state_revenue  NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE('           88 SPEEDMART - NATIONWIDE REGIONAL BRANCH PERFORMANCE SUMMARY');
    DBMS_OUTPUT.PUT_LINE('                              Generated Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));

    FOR st IN c_states LOOP
        v_state_branches := 0;
        v_state_revenue  := 0;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(' REGION / STATE: ' || UPPER(st.State));
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('  Br ID', 9) || 
            RPAD('Branch Outlet Name', 30) || 
            RPAD('City', 18) || 
            RPAD('Status', 10) || 
            LPAD('Staff', 7) || 
            LPAD('Orders', 9) || 
            LPAD('Gross GMV(RM)', 18)
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 105, '-'));

        FOR br IN c_branches(st.State) LOOP
            v_state_branches := v_state_branches + 1;
            v_state_revenue  := v_state_revenue + br.TotalRevenue;

            v_nationwide_branches := v_nationwide_branches + 1;
            v_nationwide_staff    := v_nationwide_staff + br.ActiveStaff;
            v_nationwide_orders   := v_nationwide_orders + br.OrdersCompleted;
            v_nationwide_revenue  := v_nationwide_revenue + br.TotalRevenue;

            DBMS_OUTPUT.PUT_LINE(
                RPAD('  ' || br.BranchID, 9) || 
                RPAD(SUBSTR(br.BranchName, 1, 28), 30) || 
                RPAD(SUBSTR(br.City, 1, 16), 18) || 
                RPAD(br.BranchStatus, 10) || 
                LPAD(br.ActiveStaff, 7) || 
                LPAD(br.OrdersCompleted, 9) || 
                LPAD(TO_CHAR(br.TotalRevenue, 'FM999,990.00'), 18)
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(RPAD('.', 105, '.'));
        DBMS_OUTPUT.PUT_LINE('  >> State Subtotal: ' || v_state_branches || ' Outlets | Gross Sales: RM ' || 
                             TO_CHAR(v_state_revenue, 'FM999,990.00'));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
    DBMS_OUTPUT.PUT_LINE(' NATIONWIDE ENTERPRISE TOTALS:');
    DBMS_OUTPUT.PUT_LINE(' Total Retail Branches Operating : ' || v_nationwide_branches);
    DBMS_OUTPUT.PUT_LINE(' Total Active Workforce Strength : ' || v_nationwide_staff || ' employees');
    DBMS_OUTPUT.PUT_LINE(' Total Completed Transactions   : ' || v_nationwide_orders || ' orders');
    DBMS_OUTPUT.PUT_LINE(' Total Enterprise Gross Revenue  : RM ' || TO_CHAR(v_nationwide_revenue, 'FM999,990.00'));
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 105, '='));
END sp_rpt_nationwide_branch_performance_summary;
/


-- ----------------------------------------------------------------------------
-- REPORT EXECUTION & PRESENTATION DEMO
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 1: sp_rpt_branch_staffing_payroll_dossier (Branch ID: 1)
PROMPT ============================================================================
EXEC sp_rpt_branch_staffing_payroll_dossier(1);

PROMPT
PROMPT ============================================================================
PROMPT >>> EXECUTING REPORT 2: sp_rpt_nationwide_branch_performance_summary
PROMPT ============================================================================
EXEC sp_rpt_nationwide_branch_performance_summary;
