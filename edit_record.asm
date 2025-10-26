global edit_record

extern repeat_menu
extern find_record_by_id
extern update_record
extern desc_prompt
extern desc_prompt_len
extern print_new_line
extern record_not_found
extern record_not_found_len
extern validate_description
extern empty_amount
extern amount_too_long
extern validate_description
extern validate_amount_loop
extern conv_loop_cents

section .data
    id_prompt db "Enter ID of record to edit: ", 0
    id_prompt_len equ $ - id_prompt - 1

    edit_success db "Record edited successfully.", 0xA, 0
    edit_success_len equ $ - edit_success - 1

    edit_option_prompt db "What would you like to edit?", 0xA
                       db "1. Amount", 0xA
                       db "2. Description", 0xA
                       db "Enter choice (1 or 2): ", 0
    edit_option_prompt_len equ $ - edit_option_prompt - 1

    amount_prompt db "Enter new amount: $", 0
    amount_prompt_len equ $ - amount_prompt - 1

    ; Validation error messages
    amount_zero db "Amount cannot be zero! Input must be between (0.01 - 999999.99).", 0xA, 0
    amount_zero_len equ $ - amount_zero - 1

    invalid_choice_msg db "Invalid choice! Please enter 1 or 2.", 0xA, 0
    invalid_choice_msg_len equ $ - invalid_choice_msg - 1

    error_edit db "Error: Failed to edit record.", 0xA, 0
    error_edit_len equ $ - error_edit - 1
        
section .bss
    input_buffer resb 16
    amount_buffer resb 32
    desc_buffer resb 55
    current_amount resb 4   ; stores new amount in cents

section .text
edit_record:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, id_prompt
    mov edx, id_prompt_len
    int 0x80

    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input_buffer
    mov edx, 16
    int 0x80

    call convert_string_to_number
    cmp eax, 0
    jle invalid_id
    
    push eax

    ; Find the record
    call find_record_by_id
    cmp eax, 0
    je record_not_found_msg

    ; Record found, show edit options
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, edit_option_prompt
    mov edx, edit_option_prompt_len
    int 0x80

    ; Read edit choice
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input_buffer
    mov edx, 16
    int 0x80

    ; Validate choice
    mov al, [input_buffer]
    cmp al, '1'
    je edit_amount
    cmp al, '2'
    je edit_description
    
    ; Invalid choice
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, invalid_choice_msg
    mov edx, invalid_choice_msg_len
    int 0x80
    jmp edit_record

edit_amount:
    ; Get new amount
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, amount_prompt
    mov edx, amount_prompt_len
    int 0x80
    
    ; Read amount input
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, amount_buffer
    mov edx, 32
    int 0x80
    
    ; Validate amount input
    call validate_amount
    cmp eax, 0          
    jne edit_amount
    
    ; Convert amount string to cents
    call string_to_cents
    cmp eax, 0
    je check_zero_amount

    mov [current_amount], eax
    
    ; Call update_record with amount
    pop eax             ; Get ID from stack
    mov ebx, 1          ; Field type: 1 = amount
    mov ecx, [current_amount]  ; New amount
    mov edx, 0          ; desc length / not used for amount
    call update_record
    
    cmp eax, 0
    je edit_error
    
    ; Success message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, edit_success
    mov edx, edit_success_len
    int 0x80
    jmp edit_exit

edit_description:
    ; Get new description
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, desc_prompt
    mov edx, desc_prompt_len
    int 0x80
    
    ; Read description input
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, desc_buffer
    mov edx, 55
    int 0x80
    
    mov edi, eax        ; Save length in edi
    
    ; Validate description input
    call validate_description
    cmp eax, 0          
    jne edit_description 
    
    ; Remove newline from description
    mov ebx, desc_buffer
    add ebx, edi        
    dec ebx             
    mov byte [ebx], 0   
    
    pop eax             ; Get ID from stack
    mov ebx, 2          ; Field type: 2 = description
    mov ecx, desc_buffer ; Description pointer
    mov edx, edi        ; Description length
    call update_record
    
    cmp eax, 0
    je edit_error
        
    ; Success message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, edit_success
    mov edx, edit_success_len
    int 0x80
    jmp edit_exit

record_not_found_msg:
    pop eax             ; Clean up the stack
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, record_not_found
    mov edx, record_not_found_len
    int 0x80
    jmp edit_record

invalid_id:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, record_not_found
    mov edx, record_not_found_len
    int 0x80
    jmp edit_record

edit_error:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_edit
    mov edx, error_edit_len
    int 0x80

edit_exit:
    call print_new_line
    call repeat_menu

convert_string_to_number:
    ; Convert string in input_buffer to number in eax
    push ebx
    push ecx
    push edx
    push esi

    mov esi, input_buffer
    xor eax, eax        ; result
    xor ebx, ebx        ; current digit
    mov ecx, 10         ; multiplier

convert_loop:
    mov bl, [esi]
    cmp bl, 0xA         ; newline
    je convert_done
    cmp bl, 0           ; null terminator
    je convert_done
    cmp bl, '0'
    jl convert_error
    cmp bl, '9'
    jg convert_error

    sub bl, '0'         
    mul ecx             
    add eax, ebx        
    inc esi
    jmp convert_loop

convert_done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

convert_error:
    mov eax, 0          ; return 0 on error
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

string_to_cents:    
    mov eax, 0              ; amount accumulator
    mov ebx, amount_buffer  ; pointer to input
    mov ecx, 0              ; string index
    mov esi, 0              ; decimal counter
    mov edi, 0              ; decimal flag
    xor edx, edx            ; clear edx
    jmp conv_loop_cents

validate_amount:    
    cmp eax, 1         
    jle empty_amount
    
    cmp eax, 10
    jg amount_too_long
    
    ; Validate each character
    mov ebx, amount_buffer ; pointer to input
    mov ecx, 0          ; Counter
    mov esi, eax        ; Store length of input
    dec esi             ; Exclude newline
    mov dh, 0          ; Decimal counter
    mov dl, 0          ; found dot character flag
    mov ah, 0           ; digit counter

    jmp validate_amount_loop
    
check_zero_amount:
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_zero
    mov edx, amount_zero_len
    int 0x80
    jmp edit_amount