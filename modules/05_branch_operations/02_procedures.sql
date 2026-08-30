-- ============================================================================
-- MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT
-- SECTION: TASK 5 & TASK 8 (STORED PROCEDURES & EXCEPTION HANDLING)
-- AUTHOR : Member 5
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT >>> MODULE 5: BRANCH OPERATIONS & EMPLOYEE MANAGEMENT - STORED PROCEDURES
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_register_new_branch
-- SCENARIO: Handles opening and onboarding of a new retail store branch.
--   Fulfills Mandatory Module 4: "Manage the registration of the new branches".
--   Task 8 Features: Sequence (seq_branch_id), Regex validation, 
--                    Custom Exceptions, RAISE_APPLICATION_ERROR.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_register_new_branch (
    p_branch_name   IN  VARCHAR2,
    p_address       IN  VARCHAR2,
    p_city          IN  VARCHAR2,
    p_state         IN  VARCHAR2,
    p_postcode      IN  VARCHAR2,
    p_email         IN  VARCHAR2,
    p_phone_no      IN  VARCHAR2,
    p_new_branch_id OUT NUMBER,
    p_status_msg    OUT VARCHAR2
) AS
    -- Custom User Exceptions
    e_empty_name     EXCEPTION;
    e_invalid_email  EXCEPTION;
    e_invalid_phone  EXCEPTION;
    e_duplicate_branch EXCEPTION;

    v_dup_count NUMBER := 0;
BEGIN
    -- 1. Input Parameter Validation
    IF TRIM(p_branch_name) IS NULL THEN
        RAISE e_empty_name;
    END IF;

    IF p_email IS NOT NULL AND NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$') THEN
        RAISE e_invalid_email;
    END IF;

    IF p_phone_no IS NOT NULL AND NOT REGEXP_LIKE(p_phone_no, '^0[0-9]{1,2}-[0-9]{7,8}$') THEN
        RAISE e_invalid_phone;
    END IF;

    -- 2. Check for Duplicate Branch Name in the same City
    SELECT COUNT(*) INTO v_dup_count
    FROM Branch
    WHERE UPPER(TRIM(BranchName)) = UPPER(TRIM(p_branch_name))
      AND UPPER(TRIM(City)) = UPPER(TRIM(p_city));

    IF v_dup_count > 0 THEN
        RAISE e_duplicate_branch;
    END IF;

    -- 3. Generate Branch ID via Sequence and Insert
    p_new_branch_id := seq_branch_id.NEXTVAL;

    INSERT INTO Branch (
        BranchID, BranchName, Address, City, State,
        PostCode, BranchEmail, BranchPhoneNo, BranchStatus
    ) VALUES (
        p_new_branch_id,
        TRIM(p_branch_name),
        TRIM(p_address),
        TRIM(p_city),
        TRIM(p_state),
        TRIM(p_postcode),
        LOWER(TRIM(p_email)),
        TRIM(p_phone_no),
        'Active'
    );

    COMMIT;
    p_status_msg := 'SUCCESS: Branch registered with ID #' || p_new_branch_id || 
                    ' (' || TRIM(p_branch_name) || ', ' || TRIM(p_city) || ').';

EXCEPTION
    WHEN e_empty_name THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Branch name cannot be blank.';
        RAISE_APPLICATION_ERROR(-20051, p_status_msg);

    WHEN e_invalid_email THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Invalid branch email format: ' || p_email;
        RAISE_APPLICATION_ERROR(-20052, p_status_msg);

    WHEN e_invalid_phone THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Invalid branch phone format (Expected: 0X-XXXXXXXX or 0XX-XXXXXXXX): ' || p_phone_no;
        RAISE_APPLICATION_ERROR(-20053, p_status_msg);

    WHEN e_duplicate_branch THEN
        ROLLBACK;
        p_status_msg := 'FAILED: A branch named "' || p_branch_name || '" already exists in ' || p_city;
        RAISE_APPLICATION_ERROR(-20054, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20055, p_status_msg);
END sp_register_new_branch;
/


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_transfer_or_promote_employee
-- SCENARIO: Handles staff career progression, salary increment, or branch transfer.
--   Enforces business rules: employee and destination branch must be active,
--   promotions cannot reduce salary, and minimum statutory wage (RM1500) enforced.
--   Task 8 Features: PRAGMA EXCEPTION_INIT(-2290), Row locking FOR UPDATE.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_transfer_or_promote_employee (
    p_employee_id   IN  NUMBER,
    p_new_position  IN  VARCHAR2,
    p_new_salary    IN  NUMBER,
    p_new_branch_id IN  NUMBER,
    p_status_msg    OUT VARCHAR2
) AS
    -- PRAGMA Binding for Oracle Check Constraint Violation (ORA-02290)
    e_chk_constraint EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_chk_constraint, -2290);

    -- Custom Exceptions
    e_inactive_employee    EXCEPTION;
    e_inactive_branch      EXCEPTION;
    e_salary_reduction     EXCEPTION;
    e_below_minimum_wage   EXCEPTION;

    v_curr_salary   NUMBER;
    v_curr_pos      VARCHAR2(30);
    v_emp_status    VARCHAR2(20);
    v_branch_status VARCHAR2(20);
    v_branch_name   VARCHAR2(100);
BEGIN
    -- 1. Validate Employee Existence & Current State
    SELECT Position, Salary, EmployeeStatus 
    INTO v_curr_pos, v_curr_salary, v_emp_status
    FROM Employee
    WHERE EmployeeID = p_employee_id
    FOR UPDATE;

    IF v_emp_status != 'Active' THEN
        RAISE e_inactive_employee;
    END IF;

    -- 2. Validate Destination Branch State
    SELECT BranchStatus, BranchName 
    INTO v_branch_status, v_branch_name
    FROM Branch
    WHERE BranchID = p_new_branch_id;

    IF v_branch_status != 'Active' THEN
        RAISE e_inactive_branch;
    END IF;

    -- 3. Validate Compensation Thresholds
    IF p_new_salary < 1500 THEN
        RAISE e_below_minimum_wage;
    END IF;

    IF p_new_salary < v_curr_salary THEN
        RAISE e_salary_reduction;
    END IF;

    -- 4. Update Employee Position, Compensation, and Branch Location
    UPDATE Employee
    SET Position = TRIM(p_new_position),
        Salary   = p_new_salary,
        BranchID = p_new_branch_id
    WHERE EmployeeID = p_employee_id;

    COMMIT;
    p_status_msg := 'SUCCESS: Employee #' || p_employee_id || ' updated to ' || 
                    TRIM(p_new_position) || ' (Salary: RM ' || TO_CHAR(p_new_salary, 'FM99,990.00') || 
                    ') at Branch #' || p_new_branch_id || ' (' || v_branch_name || ').';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Employee ID #' || p_employee_id || ' or Branch ID #' || p_new_branch_id || ' does not exist.';
        RAISE_APPLICATION_ERROR(-20056, p_status_msg);

    WHEN e_inactive_employee THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Cannot modify inactive or terminated employee record.';
        RAISE_APPLICATION_ERROR(-20057, p_status_msg);

    WHEN e_inactive_branch THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Destination branch #' || p_new_branch_id || ' is inactive or closed.';
        RAISE_APPLICATION_ERROR(-20058, p_status_msg);

    WHEN e_below_minimum_wage THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Proposed salary (RM ' || TO_CHAR(p_new_salary, 'FM990.00') || 
                        ') is below Malaysian statutory minimum wage of RM 1,500.00.';
        RAISE_APPLICATION_ERROR(-20059, p_status_msg);

    WHEN e_salary_reduction THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Proposed salary (RM ' || TO_CHAR(p_new_salary, 'FM990.00') || 
                        ') is lower than current salary (RM ' || TO_CHAR(v_curr_salary, 'FM990.00') || ').';
        RAISE_APPLICATION_ERROR(-20060, p_status_msg);

    WHEN e_chk_constraint THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Check constraint violation on employee salary or status (ORA-02290).';
        RAISE_APPLICATION_ERROR(-20061, p_status_msg);

    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'FAILED: Unexpected system error - ' || SQLERRM;
        RAISE_APPLICATION_ERROR(-20062, p_status_msg);
END sp_transfer_or_promote_employee;
/


-- ----------------------------------------------------------------------------
-- VERIFICATION & DEMONSTRATION SUITE
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ============================================================================
PROMPT >>> VERIFYING PROCEDURE 1: sp_register_new_branch
PROMPT ============================================================================

DECLARE
    v_new_brid NUMBER;
    v_msg      VARCHAR2(400);
BEGIN
    -- Test 1: Successful New Branch Registration
    sp_register_new_branch(
        p_branch_name   => '88 Speedmart Cyberjaya Flagship',
        p_address       => 'Lot 10-12, Shaftsbury Square, Persiaran Multimedia',
        p_city          => 'Cyberjaya',
        p_state         => 'Selangor',
        p_postcode      => '63000',
        p_email         => 'cyberjaya.store@speedmart88.my',
        p_phone_no      => '03-83229988',
        p_new_branch_id => v_new_brid,
        p_status_msg    => v_msg
    );
    DBMS_OUTPUT.PUT_LINE(v_msg);

    -- Test 2: Intentional Invalid Phone Number (Demonstrating Exception)
    BEGIN
        sp_register_new_branch(
            p_branch_name   => 'Invalid Branch Outlet',
            p_address       => 'Jalan Test',
            p_city          => 'Kuala Lumpur',
            p_state         => 'Wilayah Persekutuan',
            p_postcode      => '50000',
            p_email         => 'invalid.test@speedmart88.my',
            p_phone_no      => '123-INVALID-PHONE', -- Bad format
            p_new_branch_id => v_new_brid,
            p_status_msg    => v_msg
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caught Expected Exception: ' || SQLERRM);
    END;
END;
/
