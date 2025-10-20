global view_records
extern print_records
extern repeat_menu

section .data
    ; Record structure: [ID(4)][Type(1)][Amount(4)][Description(55)]
    RECORD_SIZE equ 64

    income_str db "Income ", 0
    expense_str db "Expense", 0
    
    continue_prompt db 0xA, "Press any key to return to menu...", 0
    continue_prompt_len equ $ - continue_prompt - 1
        
section .bss
    input resb 1
    record_buffer resb RECORD_SIZE
    amount_str resb 12      ; Buffer for converting amount to string
    output_buffer resb 80   ; Buffer for formatted output line

section .text
view_records:
    call print_records
    call wait_for_input
    call repeat_menu    
        
wait_for_input:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, continue_prompt
    mov edx, continue_prompt_len
    int 0x80
    
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input
    mov edx, 1
    int 0x80
    ret