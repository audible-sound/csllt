global add_expense
extern repeat_menu
extern add_record

section .data
    expense_prompt db "Enter expense amount: $",0
    expense_prompt_len equ $ - expense_prompt - 1
    
    desc_prompt db "Enter description (max 54 characters): ",0
    desc_prompt_len equ $ - desc_prompt - 1
    
    ; Validation error messages
    invalid_amount_msg db "Invalid amount! Please enter a positive number (e.g. 25.00).",0xA,0
    invalid_amount_msg_len equ $ - invalid_amount_msg - 1
    
    empty_input_msg db "Input cannot be empty! Please try again.",0xA,0
    empty_input_msg_len equ $ - empty_input_msg - 1
    
    amount_too_large_msg db "Amount too large! Input must be between (0.01 - 999999.99).",0xA,0
    amount_too_large_msg_len equ $ - amount_too_large_msg - 1

    amount_zero db "Amount cannot be zero! Input must be between (0.01 - 999999.99).",0xA,0
    amount_zero_len equ $ - amount_zero - 1
    
    desc_too_long_msg db "Description too long! Maximum is 54 characters.",0xA,0
    desc_too_long_msg_len equ $ - desc_too_long_msg - 1
    
    success_msg db "Expense added successfully!",0xA,0
    success_msg_len equ $ - success_msg - 1

section .bss
    expense_buffer resb 32
    desc_buffer resb 55
    current_amount resb 4   ; stores expense amount

section .text
add_expense:
    ; Save registers
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
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
    ; Print description prompt
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
    jne get_description 
    
    ; Remove newline from description
    mov ebx, desc_buffer
    add ebx, edi        ; Use saved length
    dec ebx             ; ebx points to the last character of the string
    mov byte [ebx], 0   ; Replace newline with null terminator
    
    ; record fields
    mov eax, 1          ; Record Type: 0 = expense, 1 = Expense
    mov ebx, [current_amount]  ; Amount
    mov ecx, desc_buffer     ; Description pointer
    mov edx, 0        ; Register to store description length

    ; Calculate description length
    mov esi, ecx
    mov edi, ecx

    calc_len_loop:
        cmp byte [edi], 0
        je calc_len_done
        inc edi
        jmp calc_len_loop

    calc_len_done:
        sub edi, esi
        mov edx, edi

    mov ebx, [current_amount] ; amount in cents

    call add_record
    
    ; Print success message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, success_msg
    mov edx, success_msg_len
    int 0x80
    
    ; Restore registers
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    
    jmp repeat_menu

string_to_cents:
    ; Convert string in expense_buffer to cents in eax and set is_decimal
    push ebx
    push ecx
    push edx
    push edi
    push esi
    
    mov eax, 0              ; amount accumulator
    mov ebx, expense_buffer  ; pointer to input
    mov ecx, 0              ; string index
    mov esi, 0              ; decimal counter
    mov edi, 0              ; decimal flag
    xor edx, edx            ; clear edx

conv_loop_cents:
    mov dl, [ebx + ecx]
    cmp dl, 0xA             ; newline
    je finish_conversion
    cmp dl, 0               ; null
    je finish_conversion
    
    cmp dl, '.'
    je decimal_found
    jne handle_digit

decimal_found:
    mov edi, 1
    inc ecx
    jmp conv_loop_cents

inc_decimal:
    inc esi
    inc ecx
    jmp conv_loop_cents

handle_digit:
    sub dl, '0'

    imul eax, eax, 10
    add eax, edx

    cmp edi, 1
    je inc_decimal

    inc ecx
    jmp conv_loop_cents

one_decimal:
    imul eax, eax, 10
    inc esi
    jmp finish_conversion

no_decimal:
    imul eax, eax, 100
    add esi, 2
    jmp finish_conversion

finish_conversion:
    cmp esi, 0
    je no_decimal
    cmp esi, 1
    je one_decimal

    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

validate_amount:
    ; Validation function for amount input
    ; Returns: eax = 0 if valid, 1 if invalid
    push ebx
    push ecx
    push edx
    push esi
    
    ; Check if input is empty (only newline)
    cmp eax, 1         
    jle empty_amount
    
    ; Check if input is too long (max 6 figures, two decimals, dot + newline)
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
    
validate_amount_loop:
    cmp ecx, esi        
    je amount_valid
    
    mov al, [ebx + ecx]     ; Get character

    ; check first character (it can only be a digit)
    cmp ecx, 0
    je check_digit

    ; check if character is a dot
    cmp al, '.'
    je validate_dot

    cmp edx, 0
    je check_digit
    jne validate_decimal

validate_dot:
    ; there can only be on dot && it cannot be the last char
    inc dl
    cmp dl, 1
    jg invalid_amount_char

    ; check if dot is the last character
    inc ecx     ; increment for comparison because counter is zero indexed
    cmp ecx, esi
    je invalid_amount_char
    dec ecx

    inc edx
    jmp inc_loop_counter

validate_decimal:
    inc dh 
    cmp dh, 2
    jg invalid_amount_char ; max 2 decimals

    jmp check_digit

check_digit:
    ; Check if character is a digit (0-9)
    cmp al, '0'
    jb invalid_amount_char
    cmp al, '9'
    ja invalid_amount_char
    
    inc ah
    jmp inc_loop_counter
    
inc_loop_counter:
    inc ecx
    jmp validate_amount_loop
    
amount_valid:
    ; ensure at least one digit was entered
    cmp ah, 0
    je invalid_amount_char

    ; Check amount range (999,999.99)
    sub ah, dh
    cmp ah, 6
    ja amount_too_large
    
    ; Amount is valid
    mov eax, 0
    jmp validate_amount_done
    
empty_amount:
    ; Print empty input error
    mov eax, 4
    mov ebx, 1
    mov ecx, empty_input_msg
    mov edx, empty_input_msg_len
    int 0x80
    mov eax, 1
    jmp validate_amount_done
    
amount_too_long:
    ; Print too long error
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_too_large_msg
    mov edx, amount_too_large_msg_len
    int 0x80
    mov eax, 1
    jmp validate_amount_done
    
invalid_amount_char:
    ; Print invalid character error
    mov eax, 4
    mov ebx, 1
    mov ecx, invalid_amount_msg
    mov edx, invalid_amount_msg_len
    int 0x80
    mov eax, 1
    jmp validate_amount_done
    
amount_too_large:
    ; Print too large error
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_too_large_msg
    mov edx, amount_too_large_msg_len
    int 0x80
    mov eax, 1
    jmp validate_amount_done
    
validate_amount_done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

check_zero:
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_zero
    mov edx, amount_zero_len
    int 0x80
    jmp get_expense_amount

validate_description:
    ; Validation function for description input
    ; Returns: eax = 0 if valid, 1 if invalid
    push ebx
    push ecx
    push edx
    
    ; Check if input only contains newline
    cmp eax, 1          
    jle empty_description
    
    ; Check if input is too long (max 54 chars + newline = 55)
    cmp eax, 55
    jg description_too_long
    
    ; Description is valid
    mov eax, 0
    jmp validate_description_done
    
empty_description:
    ; Print empty input error
    mov eax, 4
    mov ebx, 1
    mov ecx, empty_input_msg
    mov edx, empty_input_msg_len
    int 0x80
    mov eax, 1
    jmp validate_description_done
    
description_too_long:
    ; Print too long error
    mov eax, 4
    mov ebx, 1
    mov ecx, desc_too_long_msg
    mov edx, desc_too_long_msg_len
    int 0x80
    mov eax, 1
    jmp validate_description_done
    
validate_description_done:
    pop edx
    pop ecx
    pop ebx
    ret