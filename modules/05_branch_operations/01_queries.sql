-- ============================================================================
-- MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT
-- SECTION: TASK 4 & TASK 8 (QUERIES, VIEWS, SEQUENCES & INDEXES)
-- AUTHOR : Member 5
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT - QUERIES & VIEWS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TASK 8: EXTRA EFFORTS (SEQUENCES, INDEXES & VIEWS)
-- ----------------------------------------------------------------------------

-- 1. Sequences for Branch Registration and Employee Onboarding
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_branch_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_branch_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_employee_id';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE seq_employee_id
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 2. Performance Indexes for Branch Operations and Employee Audits
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_employee_branch_status';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_employee_branch_status 
    ON Employee(BranchID, EmployeeStatus, Position);

BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_stocklog_emp_date';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
CREATE INDEX idx_stocklog_emp_date 
    ON StockLog(EmployeeID, AdjustmentDate, AdjustmentType);


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 1 (STRATEGIC LEVEL)
-- VIEW  : v_branch_labor_efficiency
-- SCENARIO: The Chief Operating Officer (COO) and CFO need to evaluate the financial
--   health and labor cost efficiency across all retail branches nationwide.
--   Joining Branch, Employee, CustomerOrder, and Payment, this query computes:
--   1. Total active staff headcount per branch.
--   2. Total monthly payroll commitment (SUM(Salary)).
--   3. Total gross merchandise value (GMV) revenue generated.
--   4. Labor Cost Efficiency Ratio = (Monthly Payroll / Gross Revenue) * 100.
--   5. Branch Profitability Ranking using DENSE_RANK().
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_branch_labor_efficiency AS
WITH BranchPayrollCTE AS (
    SELECT 
        BranchID,
        COUNT(EmployeeID) AS ActiveStaffCount,
        NVL(SUM(Salary), 0) AS TotalMonthlyPayroll
    FROM Employee
    WHERE EmployeeStatus = 'Active'
    GROUP BY BranchID
),
BranchRevenueCTE AS (
    SELECT 
        co.BranchID,
        COUNT(DISTINCT co.OrderID) AS TotalOrdersCompleted,
        NVL(SUM(p.AmountPaid), 0) AS TotalGrossRevenue
    FROM CustomerOrder co
    JOIN Payment p ON co.OrderID = p.OrderID AND p.PaymentStatus = 'Paid'
    WHERE co.OrderStatus = 'Completed'
    GROUP BY co.BranchID
)
SELECT 
    b.BranchID,
    b.BranchName,
    b.State,
    b.BranchStatus,
    NVL(bp.ActiveStaffCount, 0) AS StaffHeadcount,
    NVL(bp.TotalMonthlyPayroll, 0) AS MonthlyPayrollCost,
    NVL(br.TotalOrdersCompleted, 0) AS OrdersCompleted,
    NVL(br.TotalGrossRevenue, 0) AS GrossRevenueGenerated,
    ROUND(
        (NVL(bp.TotalMonthlyPayroll, 0) / NULLIF(NVL(br.TotalGrossRevenue, 0), 0)) * 100, 
        2
    ) AS LaborCostRatioPct,
    CASE 
        WHEN NVL(br.TotalGrossRevenue, 0) >= 3000 THEN 'HIGH PROFITABILITY OUTLET'
        WHEN NVL(br.TotalGrossRevenue, 0) >= 1000 THEN 'MODERATE PERFORMANCE'
        ELSE 'LOW REVENUE / EXPANSION PHASE'
    END AS BranchPerformanceBand,
    DENSE_RANK() OVER (ORDER BY NVL(br.TotalGrossRevenue, 0) DESC) AS RevenueRank
FROM Branch b
LEFT JOIN BranchPayrollCTE bp ON b.BranchID = bp.BranchID
LEFT JOIN BranchRevenueCTE br ON b.BranchID = br.BranchID;

-- Format and Execute Query 1
COLUMN BranchID FORMAT 9999 HEADING "Br ID"
COLUMN BranchName FORMAT A22 HEADING "Branch Name"
COLUMN State FORMAT A12 HEADING "State"
COLUMN StaffHeadcount FORMAT 999 HEADING "Staff"
COLUMN MonthlyPayrollCost FORMAT $99,990.00 HEADING "Payroll/Mo"
COLUMN OrdersCompleted FORMAT 999 HEADING "Orders"
COLUMN GrossRevenueGenerated FORMAT $999,990.00 HEADING "Gross GMV"
COLUMN LaborCostRatioPct FORMAT 990.00 HEADING "Labor %"
COLUMN BranchPerformanceBand FORMAT A28 HEADING "Operational Classification"
COLUMN RevenueRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 1: STRATEGIC BRANCH LABOR EFFICIENCY & REVENUE RANKING
PROMPT ============================================================================
SELECT * FROM v_branch_labor_efficiency
WHERE ROWNUM <= 15
ORDER BY RevenueRank ASC;


-- ----------------------------------------------------------------------------
-- TASK 4: ANALYTICAL QUERY 2 (TACTICAL LEVEL)
-- VIEW  : v_employee_audit_workload
-- SCENARIO: The Human Resources (HR) and Internal Audit Director assess employee
--   operational productivity and audit trail accountability (Rules 19 & 20).
--   Joining Employee, Branch, and StockLog, this query aggregates:
--   1. Number of stock write-offs / restock actions logged by each employee.
--   2. Total net quantity of physical goods adjusted.
--   3. Average salary by position and staff accountability status.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_employee_audit_workload AS
SELECT 
    e.EmployeeID,
    e.EmployeeName,
    e.Position,
    b.BranchName,
    e.Salary AS MonthlySalary,
    COUNT(sl.StockLogID) AS TotalStockActionsLogged,
    NVL(SUM(ABS(sl.QuantityChanged)), 0) AS TotalUnitsAdjusted,
    NVL(MAX(sl.AdjustmentDate), SYSDATE - 365) AS LastActionDate,
    CASE 
        WHEN COUNT(sl.StockLogID) >= 5 THEN 'HIGH ACTIVITY AUDITOR'
        WHEN COUNT(sl.StockLogID) >= 1 THEN 'ACTIVE OPERATOR'
        ELSE 'INACTIVE / NO AUDIT LOGS'
    END AS OperationalActivityStatus,
    DENSE_RANK() OVER (PARTITION BY e.Position ORDER BY COUNT(sl.StockLogID) DESC) AS PositionActivityRank
FROM Employee e
JOIN Branch b ON e.BranchID = b.BranchID
LEFT JOIN StockLog sl ON e.EmployeeID = sl.EmployeeID
WHERE e.EmployeeStatus = 'Active'
GROUP BY e.EmployeeID, e.EmployeeName, e.Position, b.BranchName, e.Salary;

-- Format and Execute Query 2
COLUMN EmployeeID FORMAT 9999 HEADING "Emp ID"
COLUMN EmployeeName FORMAT A20 HEADING "Employee Name"
COLUMN Position FORMAT A16 HEADING "Job Position"
COLUMN BranchName FORMAT A20 HEADING "Assigned Branch"
COLUMN MonthlySalary FORMAT $99,990.00 HEADING "Salary"
COLUMN TotalStockActionsLogged FORMAT 999 HEADING "Logs"
COLUMN TotalUnitsAdjusted FORMAT 9999 HEADING "Units Adj"
COLUMN OperationalActivityStatus FORMAT A26 HEADING "Workload Classification"
COLUMN PositionActivityRank FORMAT 99 HEADING "Rank"

PROMPT
PROMPT ============================================================================
PROMPT >>> QUERY 2: TACTICAL EMPLOYEE OPERATIONAL WORKLOAD & AUDIT METRICS
PROMPT ============================================================================
SELECT * FROM v_employee_audit_workload
WHERE ROWNUM <= 15
ORDER BY TotalStockActionsLogged DESC;
