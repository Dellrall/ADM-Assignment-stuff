-- ============================================================================
-- MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT
-- SECTION: TASK 6 (CONDITIONAL DATABASE TRIGGERS)
-- AUTHOR : Member 5
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT - DATABASE TRIGGERS
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_guard_employee_salary
-- SCENARIO: Enforces statutory minimum wage compliance (RM 1,500.00 / month).
--   Rejects any Employee insert or salary update where Salary < 1500.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_employee_salary
BEFORE INSERT OR UPDATE OF Salary ON Employee
FOR EACH ROW
WHEN (NEW.Salary < 1500)
BEGIN
    RAISE_APPLICATION_ERROR(-20055, 'Trigger Violation: Employee monthly salary (RM ' || 
                            TO_CHAR(:NEW.Salary, 'FM990.00') || 
                            ') violates Malaysian statutory minimum wage requirement of RM 1,500.00.');
END trg_guard_employee_salary;
/


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_guard_branch_deactivation
-- SCENARIO: Enforces Operational Continuity during store decommissioning.
--   A retail branch cannot be set to 'Inactive' if there are unresolved
--   'Pending' customer orders associated with that branch.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_guard_branch_deactivation
BEFORE UPDATE OF BranchStatus ON Branch
FOR EACH ROW
WHEN (NEW.BranchStatus = 'Inactive')
DECLARE
    v_pending_orders NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_pending_orders
    FROM CustomerOrder
    WHERE BranchID = :OLD.BranchID
      AND OrderStatus = 'Pending';

    IF v_pending_orders > 0 THEN
        RAISE_APPLICATION_ERROR(-20056, 'Trigger Violation: Cannot deactivate Branch #' || :OLD.BranchID || 
                                ' because there are ' || v_pending_orders || ' pending order(s) awaiting fulfillment.');
    END IF;
END trg_guard_branch_deactivation;
/


-- ----------------------------------------------------------------------------
-- TRIGGER DEMONSTRATION & VERIFICATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 1: trg_guard_employee_salary
PROMPT ============================================================================

BEGIN
    -- Attempt invalid employee salary below RM1500
    INSERT INTO Employee (
        EmployeeID, EmployeeName, PhoneNo, Email,
        Position, Salary, EmployeeStatus, BranchID
    ) VALUES (
        999905, 'Underpaid Staff', '012-1112233', 'underpaid@speedmart88.my',
        'Store Clerk', 950.00, 'Active', 1
    );
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Below Minimum Wage): ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING TRIGGER 2: trg_guard_branch_deactivation
PROMPT ============================================================================

DECLARE
    v_branch_with_pending NUMBER;
BEGIN
    -- Find a branch that has pending orders
    SELECT MIN(BranchID) INTO v_branch_with_pending
    FROM CustomerOrder
    WHERE OrderStatus = 'Pending';

    IF v_branch_with_pending IS NOT NULL THEN
        -- Attempt to deactivate this branch (Trigger should abort!)
        UPDATE Branch 
        SET BranchStatus = 'Inactive'
        WHERE BranchID = v_branch_with_pending;
        
        ROLLBACK;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught Expected Trigger Rejection (Pending Orders Conflict): ' || SQLERRM);
        ROLLBACK;
END;
/
