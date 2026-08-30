# 88 Speedmart System (Oracle PL/SQL)
**Course:** BMCS3183 Advanced Database Management (TAR UMT)  
**System Domain:** Omnichannel Convenience Store Management  

---

## 📁 Modular Presentation Architecture

Each team member has a dedicated, self-contained subfolder containing their 4 individual presentation showcase scripts (**Queries**, **Procedures**, **Triggers**, and **Reports**) along with their **Task 8 Extra Efforts** (Sequences, Indexes, Views, PRAGMA Exceptions).

```
.
├── Dataset.txt                               # Tasks 2 & 3 (DDL + 2,816 Sample Data Records)
├── BusinessLogic.pdf                         # Task 1 (ERD & Business Rules)
├── AssignmentInstruction.pdf                 # Assignment Brief & Rubrics
└── modules/
    ├── 01_member_loyalty/                    # Member 1: Loyalty, Points & Vouchers
    │   ├── 01_queries.sql                    # Task 4 & 8: Churn Risk & Voucher ROI
    │   ├── 02_procedures.sql                 # Task 5 & 8: Member Registration & Point Redemption
    │   ├── 03_triggers.sql                   # Task 6: Points Balance & VIP Expiry Guards
    │   ├── 04_reports.sql                    # Task 7: Annual Statement & Voucher Summary
    │   └── README.md                         # Presentation & Verification Guide
    │
    ├── 02_inventory_purchasing/              # Member 2: Stock, Batches & Procurement
    │   ├── 01_queries.sql                    # Task 4 & 8: Reorder Deficit & Spoilage Risk
    │   ├── 02_procedures.sql                 # Task 5 & 8: PO Intake & Damaged Write-offs
    │   ├── 03_triggers.sql                   # Task 6: Positive PO Cost & Max Stock Guards
    │   ├── 04_reports.sql                    # Task 7: Branch Stock Audit & Supplier Dossier
    │   └── README.md                         # Presentation & Verification Guide
    │
    ├── 03_order_fulfillment/                 # Member 3: Orders, Payments & Dispatches
    │   ├── 01_queries.sql                    # Task 4 & 8: Omnichannel GMV & Courier SLA
    │   ├── 02_procedures.sql                 # Task 5 & 8: Pickup Booking & Payment Settlement
    │   ├── 03_triggers.sql                   # Task 6: Exclusive Pickup/Delivery & Paid Guard
    │   ├── 04_reports.sql                    # Task 7: Official Tax Invoice & Daily Manifest
    │   └── README.md                         # Presentation & Verification Guide
    │
    ├── 04_promotions/                        # Member 4: Promotions & Discounts
    │   ├── 01_queries.sql                    # Task 4 & 8: Promotion ROI & Markdown Depth
    │   ├── 02_procedures.sql                 # Task 5 & 8: Campaign Launch & Cart Re-pricing
    │   ├── 03_triggers.sql                   # Task 6: Date Chronology & Discount Ceiling Guards
    │   ├── 04_reports.sql                    # Task 7: Active Promo Catalog & Financial Audit
    │   └── README.md                         # Presentation & Verification Guide
    │
    └── 05_branch_operations/                 # Member 5: Branch Network & Staffing
        ├── 01_queries.sql                    # Task 4 & 8: Labor Efficiency & Staff Audit Logs
        ├── 02_procedures.sql                 # Task 5 & 8: Branch Registration & Staff Promotion
        ├── 03_triggers.sql                   # Task 6: Minimum Wage (RM1500) & Branch Deactivation
        ├── 04_reports.sql                    # Task 7: Staffing Payroll Dossier & Regional Summary
        └── README.md                         # Presentation & Verification Guide
```

---

## 👥 Team Member Task Allocations

| Member | Assigned Domain | Task 4 Queries | Task 5 Procedures | Task 6 Triggers | Task 7 Nested Reports |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **Member 1** | **Member & Loyalty** | • Churn Risk View<br>• Voucher Burn ROI | • Register/Renew VIP<br>• Point Redemption | • Inactive Point Guard<br>• VIP 1-Yr Expiry | • Member Annual Statement<br>• Voucher Campaign Summary |
| **Member 2** | **Inventory & Stock** | • Reorder Deficit View<br>• Batch Spoilage Risk | • PO Intake & MERGE<br>• Damaged Write-off | • Positive PO Cost<br>• Max Stock Ceiling | • Branch Stock Audit<br>• Supplier Procurement Dossier |
| **Member 3** | **Order & Fulfillment** | • Omnichannel GMV<br>• Courier SLA Audit | • Pickup Booking & Code<br>• Settle Payment & Pts | • Exclusive Fulfillment<br>• Paid Payment Guard | • Official Tax Invoice<br>• Daily Branch Manifest |
| **Member 4** | **Promotion & Marketing** | • Campaign Margin ROI<br>• Markdown Depth | • Launch Campaign<br>• Cart Auto-Repricing | • Promo Date Sanity<br>• Base Price Ceiling | • Active Promo Catalog<br>• Promotion Sales Impact |
| **Member 5** | **Branch & Staffing** | • Labor Efficiency Ratio<br>• Staff Audit Workload | • Register Branch<br>• Staff Promotion/Transfer | • Min Wage (RM1500)<br>• Deactivation Guard | • Branch Payroll Dossier<br>• Regional Branch Summary |

---

## 🚀 Live Demo Presentation Execution

To demonstrate in **Oracle SQL Developer** or **SQL\*Plus**:

### 1. Initial Setup (One-time)
Run `@Dataset.txt` to create the schema and populate 2,816 sample records.

### 2. Individual Member Presentation
Each member runs their 4 standalone files in sequence:

```sql
-- Example for Member 1:
@modules/01_member_loyalty/01_queries.sql
@modules/01_member_loyalty/02_procedures.sql
@modules/01_member_loyalty/03_triggers.sql
@modules/01_member_loyalty/04_reports.sql
```
