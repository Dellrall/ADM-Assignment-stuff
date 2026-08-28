# 88 Speedmart System — Report Writing & Submission Quality Assurance Guide
**BMCS3183 Advanced Database Management | TAR UMT Practical Assignment**

---

## 📋 1. Strict Formatting & Typography Specifications

| Requirement | Specification in Brief | How to Verify in MS Word (.docx) |
| :--- | :--- | :--- |
| **File Format** | **MS-Word (.docx)** only | Do NOT submit raw PDF or ZIP for the main report. |
| **Paper Size** | **A4** (210 mm x 297 mm) | `Layout` &rarr; `Size` &rarr; `A4`. |
| **Line Spacing** | **Single spacing (1.0)** | `Paragraph` &rarr; `Line Spacing: 1.0` (0pt before/after). |
| **Body Text Font** | **Times New Roman, 11pt** | Standard body text across all explanatory paragraphs. |
| **Code / SQL Font** | **9pt** (Courier New or Consolas) | All SQL queries, DDL, procedures, triggers, and reports. |
| **Headings Font** | **Arial or Times New Roman (Bold)** | Heading 1: 16pt, Heading 2: 13pt, Heading 3: 11pt. |
| **Page Numbers** | Bottom center or bottom right | Number all pages **EXCEPT** the cover page. |
| **Headers & Footers** | Running header and footer | Use `Different First Page` in MS Word to keep cover clean. |
| **Report File Name** | `TeamName (TeamNo - ProgrammeSemGroup) - StudentNamesAlphabetical.docx` | Example: `MON0800RMXH (Team 1-RSW2S3G5) -Alice Ng-Bob Lee-Cat Tan-Dickson.docx` |
| **Google Drive Folders** | **DO NOT UPLOAD IN ZIP FILE** | Create main team folder + individual member subfolders containing `.txt` scripts. |

---

## 📑 2. Required Report Chapter Outline

- **Front Matter**: Cover Page, Signed Coursework Declaration, Table of Contents, Table of Figures.
- **Chapter 1: System Introduction & Scope**: 88 Speedmart omnichannel retail operations and selected Module 3 (Refund/Return Management).
- **Chapter 2: Task 1 — Entity-Relationship Modeling**: Complete 3NF ERD diagram, 33 business rules, and 6 core assumptions.
- **Chapter 3: Task 2 — Data Definition Language**: 22 normalized table DDL definitions with integrity constraints.
- **Chapter 4: Task 3 — Data Population & Statistics**: 2,816 sample records, table volume breakdown, and multi-year date spread.
- **Chapter 5: Task 4 — Analytical SQL Queries**: 10 queries (2 per student) with Strategic/Tactical business value and output screenshots.
- **Chapter 6: Task 5 — Stored Procedures & Exception Handling**: 10 stored procedures (2 per student) with validation, transactions, and execution screenshots.
- **Chapter 7: Task 6 — Conditional Database Triggers**: 10 triggers (2 per student) with `WHEN` condition guards and rejection screenshots.
- **Chapter 8: Task 7 — Report Generation with Nested Cursors**: 10 reports (2 per student) using parameterized nested cursors with ASCII output screenshots.
- **Chapter 9: Task 8 — Extra Efforts**: Sequences, Views, Indexes, Formatted Outputs, and `PRAGMA EXCEPTION_INIT` bindings per student.

---

## 🔍 3. Four-Step Documentation Pattern per Technical Item

For every Query, Stored Procedure, Trigger, and Report in Chapters 5 to 9, follow this exact structure:
1. **Student Attribution**: Explicitly state the author (e.g., *Developed by: Alice Ng (ID: 24WMR01234) — Module 1*).
2. **Business Rationale**: 2 to 3 sentences explaining *why* management or staff needs this database object.
3. **PL/SQL Source Code**: Display formatted code in **9pt font** with numbered step comments.
4. **Execution Screenshot / Verification Output**: Capture actual output from Oracle SQL Developer or SQL*Plus console.

---

## 📸 4. Screenshot & Verification Checklist

- [ ] **Queries (Task 4)**: Formatted table results with column headers.
- [ ] **Procedures (Task 5)**: Both successful execution output and intentional exception triggering (e.g., `ORA-20001`).
- [ ] **Triggers (Task 6)**: Rejected DML attempt showing custom trigger error message.
- [ ] **Reports (Task 7)**: Complete ASCII report layout generated via `DBMS_OUTPUT.PUT_LINE`.
- [ ] **Extra Efforts (Task 8)**: `DESC ViewName`, `USER_INDEXES`, and sequence verification.

---

## ⚠️ 5. Critical Submission Reminders

1. **No ZIP Files**: Upload individual `.docx` and `.txt` files directly to Google Drive.
2. **Distinct Contributions**: Ensure students from the same team do not submit identical logic.
3. **Cursor Tier Highlight**: In Chapter 8, explicitly state that **Parameterized Nested Cursors** were utilized to target the maximum **8 marks+** tier.
