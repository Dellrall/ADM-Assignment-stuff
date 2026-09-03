# Member 4: Promotion & Marketing Management

## 📌 Module Overview
This module governs marketing campaigns, grocery product markdown enrollment (`PromotionItem`), and dynamic cart discount calculation during customer checkout across 88 Speedmart.

---

## 📁 Showcase Files Breakdown

| Task | File Name | Description & Complexity Highlights |
| :--- | :--- | :--- |
| **Task 4 & 8** | [`01_queries.sql`](01_queries.sql) | • **Query 1 (Strategic):** Promotion campaign ROI & margin absorption analysis evaluating gross GMV, discount absorbed, and net yield.<br>• **Query 2 (Tactical):** Markdown depth & basket penetration ranking using `DENSE_RANK()`.<br>• **Extra Efforts:** Sequence `seq_promo_id`, 2 Indexes, 2 Views (`v_promo_campaign_margin_roi`, `v_markdown_basket_depth`). |
| **Task 5 & 8** | [`02_procedures.sql`](02_procedures.sql) | • **Procedure 1:** `sp_create_promotional_campaign` (Date chronology validation, discount ceiling vs base price check, item enrollment).<br>• **Procedure 2:** `sp_apply_order_promo_discount` (Cart repricing cursor, `PRAGMA EXCEPTION_INIT(-1438)`). |
| **Task 6** | [`03_triggers.sql`](03_triggers.sql) | • **Trigger 1:** `trg_guard_promotion_dates` (`WHEN (NEW.EndDate <= NEW.StartDate)` enforces calendar sanity).<br>• **Trigger 2:** `trg_guard_promo_item_discount` (Guards against negative retail prices by blocking discounts $\ge$ base item price). |
| **Task 7** | [`04_reports.sql`](04_reports.sql) | • **Report 1:** `sp_rpt_active_promo_catalog` (Nested cursors: Active Campaigns $\rightarrow$ Enrolled Grocery Items & Savings %).<br>• **Report 2:** `sp_rpt_promotion_sales_impact` (Nested cursors: Campaign Header $\rightarrow$ Order Transactions & Customer Net Revenue). |

---

## 🚀 Live Presentation Execution Commands

```sql
-- Step 1: Execute Queries & Views
@modules/04_promotions/01_queries.sql

-- Step 2: Compile & Test Stored Procedures
@modules/04_promotions/02_procedures.sql

-- Step 3: Compile & Verify Triggers
@modules/04_promotions/03_triggers.sql

-- Step 4: Run Nested Cursor Reports
@modules/04_promotions/04_reports.sql
```
