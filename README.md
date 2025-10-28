# 💰 CSLLT — Budget Management System
✨ Features:

* View current balance
* View all records
* Add an expense
* Add income
* Update a record
* Delete a record

## Database Record Format

The `budget.db` file stores financial records in a fixed-size binary format. Each record is exactly **64 bytes** in size and contains the following fields:

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0-3 | 4 bytes | ID | Unique record identifier (32-bit integer) |
| 4 | 1 byte | Type | Record type: `0` = Income, `1` = Expense |
| 5-8 | 4 bytes | Amount | Transaction amount (32-bit integer) |
| 9-63 | 54 bytes | Description | Transaction description (null-terminated string, max 54 chars) |

## 🛠️ Build Instructions
Prerequisites: Linux x86-32 NASM compiler

To compile the program, run the following commands:

```bash
nasm -f elf32 main.asm -o main.o
nasm -f elf32 add_income.asm -o add_income.o
nasm -f elf32 add_expense.asm -o add_expense.o
nasm -f elf32 view_records.asm -o view_records.o
nasm -f elf32 record_manager.asm -o record_manager.o
nasm -f elf32 check_balance.asm -o check_balance.o
nasm -f elf32 delete_record.asm -o delete_record.o
nasm -f elf32 edit_record.asm -o edit_record.o
ld -m elf_i386 -o main main.o add_income.o record_manager.o view_records.o add_expense.o check_balance.o delete_record.o edit_record.o
./main
```
