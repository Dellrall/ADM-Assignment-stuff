# 88 Speedmart System — Member Presentation & Marking Rubric Guide
**BMCS3183 Advanced Database Management | Team Practical Assignment**

---

## 📋 Executive Overview & Member Module Allocations

This guide details the exact marking pointers, live demonstration scripts, and Q&A strategies for all **5 Team Members**. Each member is assigned one distinct, non-overlapping module covering **Tasks 4 through 9** (individually assessed components totaling 65% of the grade).

| Member | Assigned Domain | Source Code File | Mental Model Reference |
| :---: | :--- | :--- | :--- |
| **Member 1** | **Module 1: Member & Loyalty Management** | `modules/01_member_loyalty/member_loyalty.sql` | [`member_loyalty_mental_model.md`](modules/01_member_loyalty/member_loyalty_mental_model.md) |
| **Member 2** | **Module 2: Inventory & Purchasing Management** | `modules/02_inventory_purchasing/inventory_purchasing.sql` | [`inventory_purchasing_mental_model.md`](modules/02_inventory_purchasing/inventory_purchasing_mental_model.md) |
| **Member 3** | **Module 3: Order, Payment & Fulfillment** | `modules/03_order_fulfillment/order_fulfillment.sql` | [`order_fulfillment_mental_model.md`](modules/03_order_fulfillment/order_fulfillment_mental_model.md) |
| **Member 4** | **Module 4: Promotion & Marketing Management** | `modules/04_promotions/promotions.sql` | [`promotions_mental_model.md`](modules/04_promotions/promotions_mental_model.md) |
| **Member 5** | **Module 5: Refund & Return (Selected Extra Module)** | `modules/05_refund_return/refund_return.sql` | [`refund_return_mental_model.md`](modules/05_refund_return/refund_return_mental_model.md) |

---

## 🎯 Individual Marks Pointer Checklist (Tasks 4 to 8)

Each member must demonstrate and explain the following items to secure full marks:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   MAXIMUM SCORE RUBRIC CHECKLIST                                 │
├─────────────────────────┬───────────────┬────────────────────────────────────────────────────────┤
│ Rubric Category         │ Mark Weight   │ Key Deliverables to Show & Explain                     │
├─────────────────────────┼───────────────┼────────────────────────────────────────────────────────┤
│ Task 4: Queries         │ 10% (CLO 3)   │ 2 Multi-Table Queries (Strategic + Tactical levels).   │
│ Task 5: Procedures      │ 10% (CLO 2)   │ 2 Stored Procedures with Validation & Transactions.    │
│ Task 6: Triggers        │ 10% (CLO 2)   │ 2 Conditional Triggers (with WHEN condition).          │
│ Task 7: Reports         │ 20% (CLO 3)   │ 2 Nested Cursor Reports (Highest tier: 8 marks+).      │
│ Task 8: Extra Efforts   │ 10% (CLO 2)   │ 1 Sequence, 2 Views, 2 Indexes, 2 Formatting,          │
│                         │               │ 2 Exception Types (PRAGMA, RAISE_APPLICATION_ERROR).   │
│ Task 9: Presentation    │ 15% (CLO 3)   │ Live Demo, Fluent Explanation, and Q&A defense.       │
└─────────────────────────┴───────────────┴────────────────────────────────────────────────────────┘
```

---

## 👤 MEMBER 1: Member & Loyalty Management

### 1. Rubric Mapping & Marks Pointers
- **Task 8 Extra Efforts (10%)**:
  - **Sequence**: `seq_member_id` (starts at 1000).
  - **Indexes (2)**: `idx_member_status_type` on `Member(MemberStatus, MembershipType)`, `idx_redemption_member_order` on `PointRedemption(MemberID, OrderID, RedemptionStatus)`.
  - **Views (2)**: `v_member_loyalty_summary` (Strategic), `v_voucher_utilization` (Tactical).
  - **Formatting (2)**: `TO_CHAR(..., 'FM99,990.00')`, `RPAD`, `LPAD`.
  - **Exceptions (2 Types)**: Custom user exceptions (`e_insufficient_points`, `e_invalid_email`) + System constraint binding via `PRAGMA EXCEPTION_INIT(e_foreign_key_violation, -2291)`.
- **Task 4 Queries (10%)**:
  - **Query 1 (Strategic)**: Inactivity risk matrix flagging churning members (>6 months, >12 months).
  - **Query 2 (Tactical)**: High-value voucher campaign conversion & point burn rates.
- **Task 5 Stored Procedures (10%)**:
  - `sp_register_or_renew_member`: Validates email, types, and computes VIP 1-year expiration.
  - `sp_process_point_redemption`: Validates order/voucher, deducts points, and records redemption.
- **Task 6 Triggers (10%)**:
  - `trg_guard_point_redemption`: Prevents inactive members or insufficient points from inserting into `PointRedemption`.
  - `trg_enforce_vip_expiration`: Automatically sets 12-month expiry date when `MembershipType` changes to `VIP`.
- **Task 7 Reports (20% - Nested Cursors)**:
  - `rpt_member_annual_statement(p_member_id)`: Parent: Member $ightarrow$ Child 1: Orders $ightarrow$ Child 2: Redemptions.
  - `rpt_voucher_performance_summary`: Parent: Voucher $ightarrow$ Child: Member claims & retail branches.

### 2. Live Demo Script (Run in SQL*Plus / SQL Developer)
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- A. Show Task 4 Queries
SELECT * FROM (
    SELECT MemberID, RPAD(MemberName, 20) AS "Member", MembershipType, TO_CHAR(LifetimeSpend, 'FM99,990.00') AS "Spend", MonthsSinceLastActivity FROM v_member_loyalty_summary ORDER BY MonthsSinceLastActivity DESC
) WHERE ROWNUM <= 5;

-- B. Demonstrate Task 5 Procedures (Normal Flow & Error Triggering)
VARIABLE v_new_mem NUMBER;
EXEC sp_register_or_renew_member('Alice Walker', 'alice.w@example.com', 'pwd123', '012-1122334', 'VIP', '14 Jalan Ampang, KL', :v_new_mem);
PRINT v_new_mem;

-- Trigger Validation Error (Duplicate Email / Invalid Type):
-- EXEC sp_register_or_renew_member('Alice Walker', 'alice.w@example.com', 'pwd123', '012-1122334', 'INVALID', '...', :v_new_mem);

-- C. Demonstrate Task 7 Nested Cursor Reports
EXEC rpt_member_annual_statement(1);
EXEC rpt_voucher_performance_summary;
```

### 3. Expected Lecturer Questions & Defense
- **Q**: *Why use `PRAGMA EXCEPTION_INIT` in `sp_process_point_redemption`?*
  - **A**: It intercepts Oracle's low-level `ORA-02291` foreign key integrity violation and translates it into a clean, business-friendly error message without terminating unhandled.
- **Q**: *How does your nested cursor avoid resource leaks?*
  - **A**: In `rpt_member_annual_statement`, we use explicit `OPEN/FETCH/CLOSE` for the parent cursor and PL/SQL `FOR ... IN` cursor loops for child cursors, which automatically open and close the cursor after iteration.

---

## 👤 MEMBER 2: Inventory & Purchasing Management

### 1. Rubric Mapping & Marks Pointers
- **Task 8 Extra Efforts (10%)**:
  - **Sequences (2)**: `seq_po_id` (starts at 500), `seq_stock_log_id` (starts at 2000).
  - **Indexes (2)**: `idx_stock_branch_reorder` on `Stock(BranchID, Quantity, ReorderLevel)`, `idx_batch_item_expiry` on `StockBatch(ItemID, ExpiryDate, BranchID)`.
  - **Views (2)**: `v_branch_inventory_health` (Strategic), `v_supplier_procurement_summary` (Tactical).
  - **Exceptions (2 Types)**: Custom exceptions (`e_po_not_approved`, `e_insufficient_stock`) + `PRAGMA EXCEPTION_INIT(e_check_constraint_violated, -2290)`.
- **Task 4 Queries (10%)**:
  - **Query 1 (Strategic)**: Branch stock replenishment forecast & estimated capital required.
  - **Query 2 (Tactical)**: Perishable batch expiration risk (<90 days) & spoilage exposure.
- **Task 5 Stored Procedures (10%)**:
  - `sp_receive_purchase_order`: Verifies employee branch authorization, updates PO status to Received, upserts branch stock using `MERGE`, generates batch entries, and creates audit log.
  - `sp_adjust_damaged_stock`: Decrements stock quantity, records write-off in `StockLog`.
- **Task 6 Triggers (10%)**:
  - `trg_guard_po_item_integrity`: Prohibits zero or negative cost prices/quantities on purchase orders.
  - `trg_guard_maximum_stock_capacity`: Prevents inventory updates from exceeding branch warehouse capacity.
- **Task 7 Reports (20% - Nested Cursors)**:
  - `rpt_branch_inventory_audit(p_branch_id)`: Parent: Branch $ightarrow$ Child 1: Stock levels with reorder alerts $ightarrow$ Child 2: Historical write-offs.
  - `rpt_supplier_procurement_audit(p_supplier_id)`: Parent: Supplier $ightarrow$ Child 1: POs $ightarrow$ Child 2: PO Line items & subtotals.

### 2. Live Demo Script
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- A. Show Task 4 Queries
SELECT * FROM (
    SELECT BranchID, RPAD(BranchName, 20) AS "Branch", TotalTrackedItems, LowStockItemCount, TO_CHAR(TotalInventoryValue, 'FM99,990.00') AS "Value" FROM v_branch_inventory_health ORDER BY LowStockItemCount DESC
) WHERE ROWNUM <= 5;

-- B. Demonstrate Task 5 Procedures
-- Receive PO #1 by Branch 1 Manager (Staff #7)
EXEC sp_receive_purchase_order(1, 7, 1);

-- Record damaged goods
EXEC sp_adjust_damaged_stock(1, 1, 7, 3, 'Damaged', 'Carton dropped during transit');

-- C. Demonstrate Task 7 Nested Cursor Reports
EXEC rpt_branch_inventory_audit(1);
EXEC rpt_supplier_procurement_audit(1);
```

### 3. Expected Lecturer Questions & Defense
- **Q**: *Why use `MERGE INTO` inside `sp_receive_purchase_order`?*
  - **A**: It atomically handles both existing stock (updating quantity and timestamp) and new items not yet stocked in that branch without requiring separate `SELECT` and `INSERT` steps.
- **Q**: *How do you enforce multi-branch security for staff?*
  - **A**: In `sp_receive_purchase_order`, we check `v_emp_branch <> p_branch_id` and throw `e_employee_unauthorized` if a staff member attempts to receive goods for a different store.

---

## 👤 MEMBER 3: Order, Payment & Fulfillment Management

### 1. Rubric Mapping & Marks Pointers
- **Task 8 Extra Efforts (10%)**:
  - **Sequences (2)**: `seq_order_id` (starts at 600), `seq_payment_id` (starts at 800).
  - **Indexes (2)**: `idx_order_date_status` on `CustomerOrder(OrderDate, OrderStatus, BranchID)`, `idx_payment_method_stat` on `Payment(PaymentMethod, PaymentStatus, OrderID)`.
  - **Views (2)**: `v_order_fulfillment_summary` (Strategic), `v_courier_delivery_efficiency` (Tactical).
  - **Exceptions (2 Types)**: Custom exceptions (`e_order_not_pending`, `e_invalid_amount`) + `PRAGMA EXCEPTION_INIT(e_duplicate_transaction, -1)` for unique transaction numbers.
- **Task 4 Queries (10%)**:
  - **Query 1 (Strategic)**: Omnichannel sales distribution (Delivery vs In-Store Pickup revenue per branch).
  - **Query 2 (Tactical)**: Courier partner SLA success rate and freight volume ranking.
- **Task 5 Stored Procedures (10%)**:
  - `sp_create_pickup_order`: Verifies member/branch, generates random 6-digit `PickupCode`, creates order and pickup records atomically.
  - `sp_settle_order_payment`: Verifies pending status, records payment, updates order to Completed, and automatically calculates and awards loyalty points (1 pt / RM 1.00).
- **Task 6 Triggers (10%)**:
  - `trg_guard_exclusive_delivery`: Enforces Assumption 2 (Single fulfillment mode: blocks Delivery insertion if Pickup exists for the same order).
  - `trg_guard_paid_payment_state`: Blocks updates that attempt to revert settled payments (`Paid`) back to `Pending`.
- **Task 7 Reports (20% - Nested Cursors)**:
  - `rpt_order_tax_invoice(p_order_id)`: Parent: Order & Customer & Store $ightarrow$ Child: Line items, prices, discounts, savings summary.
  - `rpt_branch_daily_manifest(p_branch_id)`: Parent: Branch $ightarrow$ Child 1: Pickup claim queue with codes $ightarrow$ Child 2: Outbound courier dispatches.

### 2. Live Demo Script
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- A. Show Task 4 Queries
SELECT * FROM (
    SELECT "Courier ID", "Courier Name", "Total Handled", "Success Rate", "Total Freight (MYR)" FROM (
        SELECT ds.DeliveryServiceID AS "Courier ID", RPAD(ds.CompanyName, 24) AS "Courier Name", ds.TotalDispatches AS "Total Handled", ROUND((ds.SuccessfulDeliveries / NULLIF(ds.TotalDispatches, 0)) * 100, 2) || '%' AS "Success Rate", TO_CHAR(ds.CumulativeFreightRevenue, 'FM99,990.00') AS "Total Freight (MYR)" FROM v_courier_delivery_efficiency ds
    )
) WHERE ROWNUM <= 5;

-- B. Demonstrate Task 5 Procedures
VARIABLE v_order_id NUMBER;
VARIABLE v_pickup_code VARCHAR2(10);
EXEC sp_create_pickup_order(1, 1, :v_order_id, :v_pickup_code);
PRINT v_order_id;
PRINT v_pickup_code;

-- Settle Payment for Order
EXEC sp_settle_order_payment(:v_order_id, 'Online Banking', 125.50, 'TXN-MBB-883921');

-- C. Demonstrate Task 7 Nested Cursor Reports
EXEC rpt_order_tax_invoice(:v_order_id);
EXEC rpt_branch_daily_manifest(1);
```

### 3. Expected Lecturer Questions & Defense
- **Q**: *How do you guarantee that an order is never fulfilled by both Pickup and Delivery?*
  - **A**: Through `trg_guard_exclusive_delivery`, which inspects the database before inserting into `Delivery` and raises `-20210` if a corresponding `Pickup` record exists.
- **Q**: *How is loyalty point accrual handled?*
  - **A**: In `sp_settle_order_payment`, upon successful payment commit, we calculate `TRUNC(p_amount_paid)` and update `Member.MemberPoint` in the same transactional unit.

---

## 👤 MEMBER 4: Promotion & Marketing Management

### 1. Rubric Mapping & Marks Pointers
- **Task 8 Extra Efforts (10%)**:
  - **Sequence**: `seq_promo_id` (starts at 300).
  - **Indexes (2)**: `idx_promo_date_range` on `Promotion(StartDate, EndDate)`, `idx_promo_item_lookup` on `PromotionItem(ItemID, PromotionID)`.
  - **Views (2)**: `v_active_promotion_catalog` (Strategic), `v_promotion_sales_performance` (Tactical).
  - **Exceptions (2 Types)**: Custom exceptions (`e_invalid_dates`, `e_negative_discount`) + `PRAGMA EXCEPTION_INIT(e_numeric_overflow, -1438)`.
- **Task 4 Queries (10%)**:
  - **Query 1 (Strategic)**: Promotion campaign revenue yield & absorbed discount margin analysis.
  - **Query 2 (Tactical)**: Deepest discount deals & markdown percentage ranking across products.
- **Task 5 Stored Procedures (10%)**:
  - `sp_create_promotional_campaign`: Validates date intervals, positive discount, checks item availability, and enrolls item.
  - `sp_apply_order_promo_discount`: Batch-refreshes pending order line item discounts matching currently active campaigns.
- **Task 6 Triggers (10%)**:
  - `trg_guard_promotion_date_range`: Prohibits campaigns where `EndDate <= StartDate`.
  - `trg_guard_promo_item_discount`: Blocks promotional discounts that exceed or equal the base price of the item.
- **Task 7 Reports (20% - Nested Cursors)**:
  - `rpt_active_promotions_catalog`: Parent: Active promotion campaign windows $ightarrow$ Child: Enrolled items with original vs promo prices.
  - `rpt_promotion_sales_audit(p_promo_id)`: Parent: Campaign metadata $ightarrow$ Child: Completed orders that bought items with discounts saved.

### 2. Live Demo Script
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- A. Show Task 4 Queries
SELECT * FROM (
    SELECT "Campaign ID", "Start Date", "End Date", "Items Included", "Units Sold", "Gross Sales", "Discounts Given", "Performance Category" FROM (
        SELECT v.PromotionID AS "Campaign ID", TO_CHAR(v.StartDate, 'YYYY-MM-DD') AS "Start Date", TO_CHAR(v.EndDate, 'YYYY-MM-DD') AS "End Date", v.PromotedItemCount AS "Items Included", v.TotalUnitsSold AS "Units Sold", TO_CHAR(v.CampaignRevenue, 'FM99,990.00') AS "Gross Sales", TO_CHAR(v.TotalDiscountsAbsorbed, 'FM99,990.00') AS "Discounts Given", CASE WHEN v.CampaignRevenue > 5000 THEN 'HIGH PERFORMING CAMPAIGN' WHEN v.CampaignRevenue > 1000 THEN 'MODERATE SALES UPLIFT' ELSE 'LOW CONVERSION' END AS "Performance Category" FROM v_promotion_sales_performance v
    )
) WHERE ROWNUM <= 5;

-- B. Demonstrate Task 5 Procedures
VARIABLE v_new_promo NUMBER;
EXEC sp_create_promotional_campaign(1.50, SYSDATE, SYSDATE + 30, 2, :v_new_promo);
PRINT v_new_promo;

EXEC sp_apply_order_promo_discount(1);

-- C. Demonstrate Task 7 Nested Cursor Reports
EXEC rpt_active_promotions_catalog;
EXEC rpt_promotion_sales_audit(1);
```

### 3. Expected Lecturer Questions & Defense
- **Q**: *What prevents negative item prices during promotions?*
  - **A**: Both the stored procedure `sp_create_promotional_campaign` and the trigger `trg_guard_promo_item_discount` verify that `DiscountAmount < Item.Price`, raising `-20301` / `-20311` otherwise.
- **Q**: *Why use a view like `v_active_promotion_catalog`?*
  - **A**: It abstracts dynamic time window filtering (`SYSDATE BETWEEN StartDate AND EndDate`) and pre-computes promotional prices and discount percentages for customer-facing queries.

---

## 👤 MEMBER 5: Refund & Return Management (Selected Extra Module)

### 1. Rubric Mapping & Marks Pointers
- **Task 8 Extra Efforts (10%)**:
  - **Sequence**: `seq_refund_id` (starts at 1500).
  - **Indexes (2)**: `idx_refund_order_stat` on `Refund(OrderID, RefundStatus, RefundDate)`, `idx_returnitem_lookup` on `ReturnItem(RefundID, ItemID, ItemCondition)`.
  - **Views (2)**: `v_refund_claim_summary` (Strategic), `v_defective_item_loss` (Tactical).
  - **Exceptions (2 Types)**: Custom exceptions (`e_exceeded_7_days`, `e_invalid_condition`) + `PRAGMA EXCEPTION_INIT(e_check_constraint, -2290)`.
- **Task 4 Queries (10%)**:
  - **Query 1 (Strategic)**: Quality control & defective/expired item loss ranking (identifies critical supplier audit needs).
  - **Query 2 (Tactical)**: Branch refund claim frequencies and approval payout rates.
- **Task 5 Stored Procedures (10%)**:
  - `sp_submit_refund_claim`: Enforces the 7-day post-order policy (Rule 31) and condition verification (Rule 33), creating refund header and return line item records.
  - `sp_adjudicate_refund`: Processes manager decisions (Approved/Rejected), updates payment state to `Refunded` (Rule 32) and line status to `Returned`.
- **Task 6 Triggers (10%)**:
  - `trg_guard_return_item_condition`: Enforces Rule 33 directly at database level, prohibiting returns on items that are not `Damaged`, `Defective`, or `Expired`.
  - `trg_guard_refund_amount_limit`: Prevents refund payout amounts from exceeding the amount paid on the order.
- **Task 7 Reports (20% - Nested Cursors)**:
  - `rpt_refund_claim_dossier(p_refund_id)`: Parent: Claim & Customer & Proof $ightarrow$ Child: Returned items, unit cost, and staff remarks.
  - `rpt_branch_quality_audit(p_branch_id)`: Parent: Branch $ightarrow$ Child 1: Approved claims $ightarrow$ Child 2: Returned defective items list.

### 2. Live Demo Script
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- A. Show Task 4 Queries
SELECT * FROM (
    SELECT "Item #", "Product Name", "Damaged", "Defective", "Expired", "Total Loss (MYR)", "Action Plan" FROM (
        SELECT v.ItemID AS "Item #", RPAD(v.ItemName, 24) AS "Product Name", v.DamagedUnits AS "Damaged", v.DefectiveUnits AS "Defective", v.ExpiredUnits AS "Expired", TO_CHAR(v.TotalMonetaryLoss, 'FM99,990.00') AS "Total Loss (MYR)", CASE WHEN v.TotalMonetaryLoss > 200 THEN 'CRITICAL SUPPLIER AUDIT' WHEN v.TotalMonetaryLoss > 50 THEN 'MONITOR BATCH QUALITY' ELSE 'ACCEPTABLE VARIANCE' END AS "Action Plan" FROM v_defective_item_loss v
    )
) WHERE ROWNUM <= 5;

-- B. Demonstrate Task 5 Procedures
VARIABLE v_refund_id NUMBER;
EXEC sp_submit_refund_claim(2, 'Packaging torn and milk leaked', 'Drop-off at Branch', 'http://img.freshmart/proof.jpg', 1, 1, 'Damaged', :v_refund_id);
PRINT v_refund_id;

-- Adjudicate / Approve Claim
EXEC sp_adjudicate_refund(:v_refund_id, 'Approved', 'Verified physical damage at counter; refund granted');

-- C. Demonstrate Task 7 Nested Cursor Reports
EXEC rpt_refund_claim_dossier(:v_refund_id);
EXEC rpt_branch_quality_audit(1);
```

### 3. Expected Lecturer Questions & Defense
- **Q**: *How do you enforce the 7-day refund policy?*
  - **A**: In `sp_submit_refund_claim`, we evaluate `(SYSDATE - v_order_date) > 7`. If true, the procedure throws `e_exceeded_7_days` mapped to `-20404`.
- **Q**: *What happens to the financial payment record upon refund approval?*
  - **A**: In `sp_adjudicate_refund`, approving a refund triggers an update on `Payment.PaymentStatus` to `'Refunded'` and `OrderDetail.LineStatus` to `'Returned'` to maintain clean ledger integrity.

---

## 🏆 Presentation Day Checklist & Tips

1. **Pre-Presentation Setup**:
   - Open Oracle SQL Developer or terminal SQL*Plus.
   - Run `@Dataset.txt` to ensure all 22 tables and sample rows are fresh.
   - Run `@run_all_modules.sql` to compile all procedures, triggers, views, and indexes.
   - Type `SET SERVEROUTPUT ON SIZE UNLIMITED;`.
2. **Transition Between Members**:
   - Member 1 introduces the system architecture and ERD.
   - Each member runs their own live procedure, demonstrates the nested cursor report output, and deliberately triggers an error condition to show exception handling.
   - Member 5 concludes with the Refund/Return quality audit.
