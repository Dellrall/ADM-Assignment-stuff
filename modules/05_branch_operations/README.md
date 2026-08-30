# Member 5: Branch Operations & Employee Management

## 📌 Module Overview
This module governs retail store branch operations and human resource management across 88 Speedmart. It manages the onboarding of new retail branch outlets (Mandatory Module 4), employee compensation and minimum wage compliance, staff transfers/promotions, and operational auditing (`StockLog`).

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Branch network profitability & labor cost efficiency ratio using CTEs, `DENSE_RANK()`, and multi-table joins (`Branch`, `Employee`, `CustomerOrder`, `Payment`).<br>• **Query 2 (Tactical):** Employee operational workload & stock audit activity tracking.<br>• **Extra Efforts:** Sequences `seq_branch_id` & `seq_employee_id`, 2 Indexes, 2 Views (`v_branch_labor_efficiency`, `v_employee_audit_workload`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_register_new_branch` (Regex validation for email/phone, duplicate store checks, sequence generation).<br>• **Procedure 2:** `sp_transfer_or_promote_employee` (Atomic position/salary update, statutory minimum wage enforcement, `PRAGMA EXCEPTION_INIT(-2290)`). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_employee_salary` (`WHEN (NEW.Salary < 1500)` enforces Malaysian statutory minimum wage of RM1,500).<br>• **Trigger 2:** `trg_guard_branch_deactivation` (`WHEN (NEW.BranchStatus = 'Inactive')` blocks store closure if pending orders exist). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_branch_staffing_payroll_dossier` (Nested cursors: Branch Profile $\rightarrow$ Employee Roster & Monthly Payroll totals).<br>• **Report 2:** `sp_rpt_nationwide_branch_performance_summary` (Nested cursors: State Region $\rightarrow$ Retail Branch Outlets & Enterprise Totals). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/05_branch_operations/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/05_branch_operations/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/05_branch_operations/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/05_branch_operations/04_reports.sql
```
