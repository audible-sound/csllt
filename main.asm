global _start
global repeat_menu
global print_new_line

extern check_balance
extern add_income
extern add_expense
extern view_records

section .data
    menu db "===========================",0xA
         db "    BUDGET MANAGER MENU    ",0xA
         db "===========================",0xA
         db "1. Check Balance",0xA
         db "2. Add Income",0xA
         db "3. Add Expense",0xA
         db "4. View Records",0xA
         db "5. Update Record",0xA
         db "6. Delete Record",0xA
         db "7. Exit",0xA
         db "Enter choice: ",0
    menu_len equ $ - menu

    invalid_choice_msg db "Invalid choice. Try again.",0xA,0
    invalid_choice_msg_len equ $ - invalid_choice_msg - 1

    new_line db 0xA 
    new_line_len equ $ - new_line

    err_file_open_msg db "Error opening file",0xA,0
    err_file_open_len equ $ - err_file_open_msg - 1

section .bss
    input resb 8

section .text
_start:
menu_loop:
    ; Print menu
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, menu
    mov edx, menu_len
    int 0x80

    ; Read user input
    mov eax, 3          ; Call sys_read
    mov ebx, 0          ; stdin 
    mov ecx, input
    mov edx, 8
    int 0x80
    
    ; Check input option
    mov al, [input]
    cmp al, '1'
    je check_balance
    cmp al, '2'
    je add_income
    cmp al, '3'
    je add_expense
    cmp al, '4'
    je view_records
    cmp al, '7'
    je exit_program

    ; Manage Invalid Input
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, invalid_choice_msg
    mov edx, invalid_choice_msg_len
    int 0x80
    jmp repeat_menu

print_new_line:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, new_line
    mov edx, new_line_len
    int 0x80
    ret

repeat_menu:
    ; Repeat menu in new line
    call print_new_line
    jmp menu_loop

exit_program:
    mov eax, 1          ; call sys_exit
    xor ebx, ebx        ; set exit code to 0 (success)
    int 0x80