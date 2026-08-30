# Member 5: Refund & Return Management (Selected Extra Module)

## 📌 Module Overview
This module governs customer return claims, quality defect validation, and financial refund reversals for 88 Speedmart. It enforces the strict 7-day claim window (Rule 31), validates defect conditions (`'Damaged'`, `'Defective'`, `'Expired'` under Rule 33), and manages managerial claim adjudication with payment reversals (Rule 32).

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Defect write-off loss ranking & supplier quality liability tracing using CTEs, `DENSE_RANK()`, and multi-table joins (`Refund`, `ReturnItem`, `Item`, `PurchaseOrderItem`, `PurchaseOrder`, `Supplier`).<br>• **Query 2 (Tactical):** Branch refund risk & claim adjudication turnaround audit.<br>• **Extra Efforts:** Sequence `seq_refund_id`, 2 Indexes, 2 Views (`v_defective_supplier_liability`, `v_branch_refund_risk_audit`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_submit_refund_claim` (Enforces 7-day window, defect condition check, atomic claim insertion).<br>• **Procedure 2:** `sp_adjudicate_refund_claim` (Managerial approval/rejection, payment status reversal to `'Refunded'`, `PRAGMA EXCEPTION_INIT(-2290)`). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_return_item_condition` (`WHEN (NEW.ItemCondition NOT IN ('Damaged', 'Defective', 'Expired'))` strictly enforces Rule 33 at database level).<br>• **Trigger 2:** `trg_guard_refund_amount_ceiling` (Prevents refund payout from exceeding original order transaction value). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_refund_claim_dossier` (Nested cursors: Refund Ticket $\rightarrow$ Returned Items with photo proof and line-level losses).<br>• **Report 2:** `sp_rpt_branch_spoilage_quality_audit` (3-Tier Nested cursors: Branch $\rightarrow$ Refund Incidents $\rightarrow$ Defective Items & Defect Types). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/05_refund_return/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/05_refund_return/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/05_refund_return/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/05_refund_return/04_reports.sql
```
