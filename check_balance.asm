global check_balance
extern calculate_balance

section .data
    balance_msg db "Current Balance: $",0
    balance_msg_len equ $ - balance_msg
    
section .bss
    balance_string resb 20
    balance_string_len resb 1

section .text
check_balance: