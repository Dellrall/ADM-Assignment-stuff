# Member 2: Inventory & Purchasing Management

## 📌 Module Overview
This module underpins the supply chain of 88 Speedmart. It manages multi-branch stock levels, critical reorder thresholds, batch-level perishable expiration (FEFO tracking), supplier purchase order intake verification, and inventory write-offs (`StockLog`).

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Multi-branch reorder deficit & capital expenditure forecast using `DENSE_RANK()`, joins on `Stock`, `Item`, and `PurchaseOrderItem`.<br>• **Query 2 (Tactical):** Perishable batch expiry exposure analysis with date math and risk classification.<br>• **Extra Efforts:** Sequences `seq_po_id` & `seq_stock_log_id`, 2 Indexes, 2 Views (`v_branch_reorder_deficit`, `v_batch_spoilage_exposure`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_receive_purchase_order` (`MERGE INTO Stock`, atomic batch creation, audit logging, PO status change).<br>• **Procedure 2:** `sp_adjust_damaged_stock` (Stock deduction, write-off logging, `PRAGMA EXCEPTION_INIT(-2290)`). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_po_item_integrity` (`WHEN (NEW.Quantity <= 0 OR NEW.CostPrice <= 0)` blocks invalid PO line pricing).<br>• **Trigger 2:** `trg_guard_maximum_stock_capacity` (`WHEN (NEW.Quantity > OLD.MaximumStock)` prevents warehouse overfilling). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_branch_inventory_audit` (Nested cursors: Branch $\rightarrow$ Live Inventory $\rightarrow$ Recent Stock Logs).<br>• **Report 2:** `sp_rpt_supplier_procurement_dossier` (3-Tier Nested cursors: Supplier $\rightarrow$ POs $\rightarrow$ Itemized Line Costs). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/02_inventory_purchasing/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/02_inventory_purchasing/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/02_inventory_purchasing/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/02_inventory_purchasing/04_reports.sql
```
