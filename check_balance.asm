global check_balance
extern calculate_balance
extern print_amount
extern repeat_menu

section .data
    balance_msg db "Current Balance: $",0
    balance_msg_len equ $ - balance_msg

    continue_prompt db 0xA, "Press any key to return to menu...", 0
    continue_prompt_len equ $ - continue_prompt - 1
    
    minus_sign db "-", 0
    
section .bss
    input resb 1
    amount_buffer resb 12  ; Buffer for converting number to string

section .text
check_balance:
    call calculate_balance
    call print_balance_value
    call wait_for_input
    call repeat_menu  

print_balance_value:
    push eax    ; save balance

    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, balance_msg
    mov edx, balance_msg_len
    int 0x80
    
    ; Print the actual balance amount
    pop eax
    call process_amount
    call print_amount
    ret

process_amount:    
    ; Check if value is negative
    test eax, eax       ; test sign 0 non negative, 1 is negative
    js process_negative ; jump if sign
    ret

process_negative:
    ; Print minus sign for negative values
    push eax
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, minus_sign
    mov edx, 1
    int 0x80
    pop eax
    
    ; Convert amount to positive
    neg eax
    ret

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