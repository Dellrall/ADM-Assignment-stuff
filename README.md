# 88 Speedmart System (Oracle PL/SQL)
**Course:** BMCS3183 Advanced Database Management (TAR UMT)  
**Selected Additional Module:** Module 3 — Refund & Return Management  

---

## Project Structure

```
.
├── AssignmentInstruction.pdf              # Assignment brief & rubrics
├── BusinessLogic.pdf                      # Task 1 (ERD & business rules) + Task 2 (DDL)
├── Dataset.txt                            # Task 2 (DDL) + Task 3 (2,816 sample INSERT records)
├── ExtraModule.md                         # Group selection record (Refund/Return)
├── run_all_modules.sql                    # Master runner script
├── guides/
│   ├── Presentation_and_Grading_Guide.pdf # Presentation & live demo guide (PDF)
│   ├── PRESENTATION_AND_GRADING_GUIDE.md  # Presentation & live demo guide (Markdown)
│   ├── Report_Writing_and_Submission_Guide.pdf # Report formatting & checklist (PDF)
│   └── Report_Writing_and_Submission_Guide.md  # Report formatting & checklist (Markdown)
└── modules/
    ├── 01_member_loyalty/                 # Member 1: Loyalty, Points & Vouchers
    │   ├── member_loyalty.sql             # SQL & PL/SQL implementation
    │   └── member_loyalty_mental_model.md # Module documentation
    ├── 02_inventory_purchasing/           # Member 2: Stock, Batches & Suppliers
    │   ├── inventory_purchasing.sql       # SQL & PL/SQL implementation
    │   └── inventory_purchasing_mental_model.md
    ├── 03_order_fulfillment/              # Member 3: Orders, Payments & Fulfillment
    │   ├── order_fulfillment.sql          # SQL & PL/SQL implementation
    │   └── order_fulfillment_mental_model.md
    ├── 04_promotions/                     # Member 4: Promotions & Discounts
    │   ├── promotions.sql                 # SQL & PL/SQL implementation
    │   └── promotions_mental_model.md
    └── 05_refund_return/                  # Member 5: Refund & Return Management (Extra)
        ├── refund_return.sql              # SQL & PL/SQL implementation
        └── refund_return_mental_model.md
```

---

## Guides

- **Presentation Guide:** [PDF](guides/Presentation_and_Grading_Guide.pdf) | [Markdown](guides/PRESENTATION_AND_GRADING_GUIDE.md) — Live demo script, marks pointers, and Q&A defense for each member.
- **Report Writing Guide:** [PDF](guides/Report_Writing_and_Submission_Guide.pdf) | [Markdown](guides/Report_Writing_and_Submission_Guide.md) — Formatting rules (11pt Times New Roman, 1.0 spacing), chapter outline, and screenshot checklist.

---

## Team Module Allocations

| Member | Assigned Module | SQL Script | Documentation |
| :---: | :--- | :--- | :--- |
| **Member 1** | Module 1: Member & Loyalty Management | [`member_loyalty.sql`](modules/01_member_loyalty/member_loyalty.sql) | [`Mental Model`](modules/01_member_loyalty/member_loyalty_mental_model.md) |
| **Member 2** | Module 2: Inventory & Purchasing Management | [`inventory_purchasing.sql`](modules/02_inventory_purchasing/inventory_purchasing.sql) | [`Mental Model`](modules/02_inventory_purchasing/inventory_purchasing_mental_model.md) |
| **Member 3** | Module 3: Order, Payment & Fulfillment | [`order_fulfillment.sql`](modules/03_order_fulfillment/order_fulfillment.sql) | [`Mental Model`](modules/03_order_fulfillment/order_fulfillment_mental_model.md) |
| **Member 4** | Module 4: Promotion & Marketing Management | [`promotions.sql`](modules/04_promotions/promotions.sql) | [`Mental Model`](modules/04_promotions/promotions_mental_model.md) |
| **Member 5** | Module 5: Refund & Return Management (Extra) | [`refund_return.sql`](modules/05_refund_return/refund_return.sql) | [`Mental Model`](modules/05_refund_return/refund_return_mental_model.md) |

---

## How to Run in Oracle (SQL Developer / SQL*Plus)

### 1. Build Entire Database & All Modules
```sql
-- 1. Create tables and insert sample records (Tasks 2 & 3)
@Dataset.txt

-- 2. Compile all procedures, triggers, views, indexes, sequences (Tasks 4–8)
@run_all_modules.sql
```

### 2. Run a Single Module
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;
@modules/01_member_loyalty/member_loyalty.sql
```
