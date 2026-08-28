# 88 Speedmart System (Oracle PL/SQL)
**Course:** BMCS3183 Advanced Database Management  
**Selected Additional Module:** Module 3 — Refund/Return Management  

---

## 📁 Project Structure & Deliverables

```
.
├── 1. Assignment Instruction.pdf          # Official Course Assignment Brief
├── BusinessLogic.pdf                      # Task 1 (ERD & 33 Business Rules) & Task 2 (DDL)
├── Dataset.txt                            # Task 2 (DDL) & Task 3 (3,000+ Sample INSERT records)
├── ExtraModule.md                         # Group Selected Module Record
├── run_all_modules.sql                    # Master Oracle PL/SQL Module Runner
└── modules/
    ├── 01_member_loyalty/
    │   ├── member_loyalty.sql             # Tasks 4-8 SQL & PL/SQL Implementation
    │   └── member_loyalty_mental_model.md # Developer Mental Model & Documentation
    ├── 02_inventory_purchasing/
    │   ├── inventory_purchasing.sql       # Tasks 4-8 SQL & PL/SQL Implementation
    │   └── inventory_purchasing_mental_model.md
    ├── 03_order_fulfillment/
    │   ├── order_fulfillment.sql          # Tasks 4-8 SQL & PL/SQL Implementation
    │   └── order_fulfillment_mental_model.md
    ├── 04_promotions/
    │   ├── promotions.sql                 # Tasks 4-8 SQL & PL/SQL Implementation
    │   └── promotions_mental_model.md
    └── 05_refund_return/
        ├── refund_return.sql              # Tasks 4-8 SQL & PL/SQL Implementation
        └── refund_return_mental_model.md
```

---

## 🚀 Module Mapping & Assignment Rubric Compliance

Each of the **5 Modules** is self-contained and comprehensively implements:
- **Task 4 (Queries)**: 2 multi-table strategic & tactical analytical queries.
- **Task 5 (Stored Procedures)**: 2 stored procedures with robust transaction handling and custom/system error raising.
- **Task 6 (Conditional Triggers)**: 2 triggers with `WHEN` conditions enforcing database integrity.
- **Task 7 (Reports)**: 2 on-demand parameterized reports using **Nested Cursors** (max score category: 8 marks +-).
- **Task 8 (Extra Efforts)**: Sequences, custom performance indexes, multi-table views, output formatting, and diverse exception types (`RAISE_APPLICATION_ERROR`, `PRAGMA EXCEPTION_INIT`, custom user exceptions).

---

## 📖 Developer Mental Models

- [Module 1: Member & Loyalty Management](modules/01_member_loyalty/member_loyalty_mental_model.md)
- [Module 2: Inventory & Purchasing Management](modules/02_inventory_purchasing/inventory_purchasing_mental_model.md)
- [Module 3: Order, Payment & Fulfillment Management](modules/03_order_fulfillment/order_fulfillment_mental_model.md)
- [Module 4: Promotion & Marketing Management](modules/04_promotions/promotions_mental_model.md)
- [Module 5: Refund & Return Management](modules/05_refund_return/refund_return_mental_model.md)
