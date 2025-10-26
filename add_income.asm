global add_income

global desc_prompt
global desc_prompt_len

global amount_zero
global amount_zero_len
global empty_amount
global amount_too_long
global validate_amount_loop
global conv_loop_cents
global validate_description

extern repeat_menu
extern add_record

section .data
    income_prompt db "Enter income amount: $",0
    income_prompt_len equ $ - income_prompt - 1
    
    desc_prompt db "Enter description (max 54 characters): ",0
    desc_prompt_len equ $ - desc_prompt - 1
    
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
    
    success_msg db "Income added successfully!",0xA,0
    success_msg_len equ $ - success_msg - 1

section .bss
    income_buffer resb 32
    desc_buffer resb 55
    current_amount resb 4   

section .text
add_income:
get_income_amount:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, income_prompt
    mov edx, income_prompt_len
    int 0x80
    
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, income_buffer
    mov edx, 32
    int 0x80
    
    ; Validate amount input
    call validate_amount
    cmp eax, 0          
    jne get_income_amount
    
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
    
    ; Validate description input
    call validate_description
    cmp eax, 0          
    jne get_description 
    
    mov ebx, desc_buffer
    add ebx, edi        
    dec ebx             
    mov byte [ebx], 0   ; Replace newline with null terminator
    
    ; record fields
    mov eax, 0          ; Record Type: 0 = income, 1 = Expense
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
    mov ebx, income_buffer  
    mov ecx, 0             
    mov esi, 0              ; decimal counter
    mov edi, 0              ; decimal flag
    xor edx, edx            ; temp container

conv_loop_cents:
    mov dl, [ebx + ecx]
    cmp dl, 0xA             
    je finish_conversion
    cmp dl, 0               
    je finish_conversion
    
    cmp dl, '.'
    je dot_found
    jne handle_digit

dot_found:
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

    ret

validate_amount:
    ; Returns: eax = 0 if valid, 1 if invalid
    ; Check if input is empty
    cmp eax, 1         
    jle empty_amount
    
    ; Check if input is too long (max 6 figures, two decimals, dot + newline)
    cmp eax, 10
    jg amount_too_long
    
    ; Validate each character
    mov ebx, income_buffer
    mov ecx, 0          
    mov esi, eax        
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

    cmp dl, 0
    je check_digit
    jne validate_decimal

validate_dot:
    inc dl
    cmp dl, 1
    jg invalid_amount_char

    ; check if dot is the last character
    inc ecx     ; increment for comparison because counter is zero indexed
    cmp ecx, esi
    je invalid_amount_char
    dec ecx

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
    ; Check amount range (999,999.99)
    sub ah, dh
    cmp ah, 6
    ja amount_too_large
    
    ; Amount is valid
    mov eax, 0
    ret
    
empty_amount:
    mov eax, 4
    mov ebx, 1
    mov ecx, empty_input_msg
    mov edx, empty_input_msg_len
    int 0x80
    mov eax, 1
    ret
    
amount_too_long:
    ; Print too long error
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_too_large_msg
    mov edx, amount_too_large_msg_len
    int 0x80
    mov eax, 1
   ret
    
invalid_amount_char:
    mov eax, 4
    mov ebx, 1
    mov ecx, invalid_amount_msg
    mov edx, invalid_amount_msg_len
    int 0x80
    mov eax, 1
    ret
    
amount_too_large:
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_too_large_msg
    mov edx, amount_too_large_msg_len
    int 0x80
    mov eax, 1
    ret

check_zero:
    mov eax, 4
    mov ebx, 1
    mov ecx, amount_zero
    mov edx, amount_zero_len
    int 0x80
    jmp get_income_amount

validate_description:
    ; Returns: eax = 0 if valid, 1 if invalid
    ; Check if input only contains newline
    cmp edi, 1          
    jle empty_description
    
    ; Description is valid
    mov eax, 0
    ret
    
empty_description:
    mov eax, 4
    mov ebx, 1
    mov ecx, empty_input_msg
    mov edx, empty_input_msg_len
    int 0x80
    mov eax, 1
    ret