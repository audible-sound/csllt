global add_expense

extern repeat_menu
extern add_record

extern desc_prompt
extern desc_prompt_len

extern amount_zero
extern amount_zero_len

extern empty_amount
extern amount_too_long
extern validate_description
extern validate_amount_loop
extern conv_loop_cents


section .data
    expense_prompt db "Enter expense amount: $",0
    expense_prompt_len equ $ - expense_prompt - 1

    success_msg db "Expense added successfully!",0xA,0
    success_msg_len equ $ - success_msg - 1
    
section .bss
    expense_buffer resb 32
    desc_buffer resb 55
    current_amount resb 4   ; stores expense amount

section .text
add_expense:    
get_expense_amount:
    ; Print expense prompt
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, expense_prompt
    mov edx, expense_prompt_len
    int 0x80
    
    ; Read expense input
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, expense_buffer
    mov edx, 32
    int 0x80
    
    ; Validate amount input
    call validate_amount
    cmp eax, 0          
    jne get_expense_amount
    
    ; Convert expense string to amount in cents and set decimal flag
    call string_to_cents

    cmp eax, 0
    je check_zero

    mov [current_amount], eax
            
get_description:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, desc_prompt
    mov edx, desc_prompt_len
    int 0x80
    
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, desc_buffer
    mov edx, 55
    int 0x80
    
    mov edi, eax        ; Save length
    
    call validate_description
    cmp eax, 0          
    jne get_description 
    
    mov ebx, desc_buffer
    add ebx, edi        
    dec ebx             
    mov byte [ebx], 0   ; Replace newline with null terminator
    
    ; record fields
    mov eax, 1          ; Record Type: 0 = expense, 1 = Expense
    mov ebx, [current_amount]  ; Amount
    mov ecx, desc_buffer     ; Description pointer
    mov edx, edi        ; store description length

    call add_record
    
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, success_msg
    mov edx, success_msg_len
    int 0x80
        
    jmp repeat_menu

string_to_cents:
    mov eax, 0              ; amount accumulator
    mov ebx, expense_buffer  ; pointer to input
    mov ecx, 0              ; string index
    mov esi, 0              ; decimal counter
    mov edi, 0              ; decimal flag
    xor edx, edx            ; clear edx

    jmp conv_loop_cents
validate_amount:
    ; Returns: eax = 0 if valid, 1 if invalid    
    cmp eax, 1         
    jle empty_amount
    
    cmp eax, 10
    jg amount_too_long
    
    ; Validate each character
    mov ebx, expense_buffer ; pointer to input
    mov ecx, 0          ; Counter
    mov esi, eax        ; Store length of input
    dec esi             ; Exclude newline
    mov dh, 0          ; Decimal counter
    mov dl, 0          ; found dot character flag
    mov ah, 0           ; digit counter

    jmp validate_amount_loop
        
check_zero:
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_zero
    mov edx, amount_zero_len
    int 0x80
    jmp get_expense_amount