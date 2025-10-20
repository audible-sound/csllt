global add_record
global get_record_count
global print_records
extern repeat_menu
extern print_new_line

section .data
    filename db "budget.db", 0
    file_handle dd 0    ; reserve 4 bytes to store file descriptor
    
    ; Record structure: [ID(4)][Type(1)][Amount(4)][Description(55)]
    RECORD_SIZE equ 64 ; Total: 64 bytes per record
        
    error_open_file db "Error: Could not open file", 0xA, 0
    error_open_file_len equ $ - error_open_file - 1

    no_records_msg db "No records found in database.", 0xA, 0
    no_records_msg_len equ $ - no_records_msg - 1

    table_header db "ID    | Type     | Amount        | Description", 0xA
                db  "------|----------|---------------|--------------------------------", 0xA, 0
    table_header_len equ $ - table_header - 1
    
    ; Display strings
    income_str db "Income ", 0
    income_str_len equ $ - income_str - 1
    expense_str db "Expense", 0
    expense_str_len equ $ - expense_str - 1
    separator db "|", 0
    space db " ", 0
    newline db 0xA, 0
    
section .bss
    record_buffer resb RECORD_SIZE
    number_buffer resb 16

section .text
add_record:
    ; Add record to db file
    ; Parameters:
    ;   eax = record type (0 = income, 1 = expense)
    ;   ebx = amount in cents (32-bit integer)
    ;   ecx = description pointer
    ;   edx = description length (max 55)
    ; Keep original values of registers
    push edx
    push ecx
    push ebx
    push eax

    ;Get next record ID
    call get_next_record_id
    push eax            ; place id value to the stack

    ; Open file for append
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 2001o      ; file flags (write only access, append to end of file)
    int 0x80
    
    cmp eax, 0
    jl open_error
    mov [file_handle], eax  ; store file descriptor
    
    ; Clear record buffer
    mov esi, record_buffer
    mov ecx, RECORD_SIZE
    xor eax, eax    ; make eax 0

    clear_loop:
        mov [esi], al   ; fill record buffer with 0
        inc esi
        loop clear_loop
    
    ; Build record
    mov esi, record_buffer
    mov edi, 0             ; pointer to record buffer
    
    ; Write ID (4 bytes)
    pop eax             ; Get ID from stack
    mov [esi + edi], eax    ; store ID
    add edi, 4              ; move buffer pointer      
    
    ; Write Type (1 byte)
    pop eax             ; Get type from stack
    mov [esi + edi], al ; store type
    inc edi
    
    ; Write Amount (4 bytes)
    pop eax             ; Get amount from stack
    mov [esi + edi], eax    ; store amount
    add edi, 4              ; move buffer pointer
    
    ; Write Description (55 bytes)
    pop eax            ; eax = pointer to description
    pop ecx            ; ecx = length of description

    lea edi, [esi + edi]
    mov esi, eax
    cld 
    rep movsb
                
    ; Write record to file
    mov eax, 4          ; sys_write
    mov ebx, [file_handle]
    mov ecx, record_buffer
    mov edx, RECORD_SIZE
    int 0x80
        
    call close_file   
    ret

open_error:
    call close_file
    ; Print error message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_open_file
    mov edx, error_open_file_len
    int 0x80
    
    jmp repeat_menu

get_next_record_id:
    ; Get the next available record ID
    ; Keep original values of registers
    push ebx
    push ecx
    push edx
    
    ; Open file
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl open_error       ; if error
    mov [file_handle], eax        ; file descriptor
    
    ; Get file size using lseek to end of file
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]        ; file descriptor
    mov ecx, 0          ; offset
    mov edx, 2          ; SEEK_END
    int 0x80
    
    cmp eax, 0
    jl lseek_error      ; if error
    
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    ; Get the next id
    inc eax
    push eax        ; Save ID value
    call close_file
    pop eax         ; Get the ID value
    jmp id_done

lseek_error:
    call close_file
    jmp open_error
        
id_done:
    pop edx
    pop ecx
    pop ebx
    ret

close_file:
    mov eax, 6          ; sys_close
    mov ebx, [file_handle]
    int 0x80
    ret

print_records:
    ; Open file for reading
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl open_error
    mov [file_handle], eax

    ; Get file size to check if there are records
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    je print_no_records

    mov esi, eax    ; save file size

    ; Seek back to beginning of file
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80

    ; Display table header
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, table_header
    mov edx, table_header_len
    int 0x80

    ; Calculate number of records
    mov eax, esi
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; store total in eax

    mov ebx, 0          ; record counter
    mov ecx, eax        ; copy total records

    read_loop:
        cmp ebx, ecx    ; end loop condition
        jge display_done

        push ebx
        push ecx
        
        ; Read one record
        mov eax, 3          ; sys_read
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Display the record
        call print_row
        pop ecx
        pop ebx

        inc ebx
        jmp read_loop

display_done:
    call close_file
    ret

print_row:
    ; Print a single record row
    
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, record_buffer
    
    ; Print ID (4 bytes)
    mov eax, [esi]          ; Get ID, first four bytes
    call print_number
    call print_space
    
    ; Print separator
    call print_separator
    call print_space
    
    ; Print Type (1 byte)
    add esi, 4              ; Move to type field
    mov al, [esi]           ; Get type
    cmp al, 0
    je print_income
    jmp print_expense
    
print_income:
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, income_str
    mov edx, income_str_len
    int 0x80
    jmp type_done
    
print_expense:
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, expense_str
    mov edx, expense_str_len
    int 0x80
    
type_done:
    call print_space
    call print_separator
    call print_space
    
    ; Print Amount (4 bytes)
    add esi, 1              ; Move to amount field
    mov eax, [esi]          ; Get amount in cents
    call print_amount
    jmp after_amount
    
after_amount:
    call print_space
    
    ; Print separator
    call print_separator
    call print_space
    
    ; Print Description (55 bytes)
    add esi, 4              ; Move to description field
    mov ecx, 55             ; Max description length
    mov edi, 0              ; Counter for actual chars
    
count_desc_chars:
    cmp edi, ecx
    jge print_desc
    cmp byte [esi + edi], 0
    je print_desc
    inc edi
    jmp count_desc_chars
    
print_desc:
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, esi            ; description pointer
    mov edx, edi            ; actual length
    int 0x80

    call print_new_line
        
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_number:
    ; Convert number in eax to string and print
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, number_buffer
    add esi, 15             ; Start from end of buffer
    mov byte [esi], 0       ; Add Null terminator
    dec esi
    
    mov ebx, 10             ; Divisor
    mov ecx, 0              ; Digit counter
    
    ; Handle zero case
    cmp eax, 0
    jne convert_loop
    mov byte [esi], '0'
    inc ecx
    jmp print_converted
    
convert_loop:
    cmp eax, 0
    je print_converted
    
    xor edx, edx
    div ebx                 ; eax = quotient, edx = remainder
    add dl, '0'             ; Convert to ASCII
    mov [esi], dl           ; assign char
    dec esi
    inc ecx
    jmp convert_loop
    
print_converted:
    inc esi                 ; Point to start of number
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov edx, ecx            ; length (ecx contains the digit count)
    mov ecx, esi            ; pointer to number string
    int 0x80
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_space:
    ; print space character
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, space
    mov edx, 1
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_separator:
    ;print |
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, separator
    mov edx, 1
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret


print_amount:
    ; Print amount as dollars with two decimals
    ; Input: EAX = amount in cents (e.g., 12345 = $123.45)
    ; Example: 12345 -> "123.45"
    ; Example: 12300 -> "123.00"
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Initialize buffer pointer to end of buffer
    mov esi, number_buffer
    add esi, 15              ; Point to end of buffer
    mov byte [esi], 0        ; Null terminator
    dec esi                  ; Move to last character

    ; Separate dollars and cents
    mov ebx, 100
    xor edx, edx
    div ebx                  ; eax quotient (dollar), edx remainder (cents)
    push eax                 ; keep dollar
    
    ; Write cents
    mov ebx, 10              ; ebx will be the divisor
    xor eax, eax             ; clear eax
    mov al, dl               ; Move cents to al
    div bl                   ; al (quotient) tens, ah (remainder) ones
    add al, '0'              ; Convert to ASCII
    add ah, '0' 
    
    ; store in reverse order
    mov [esi], ah            ; Store ones digit
    dec esi
    mov [esi], al            ; Store tens digit
    dec esi

    ; Write decimal point
    mov byte [esi], '.'
    dec esi

    ; Restore dollars from stack
    pop eax
    cmp eax, 0
    je write_zero_dollar

write_dollars:
    mov ebx, 10
write_dollars_loop:
    cmp eax, 0
    je finalize_amount
    xor edx, edx
    div ebx                  ; EDX = remainder (digit), EAX = quotient
    add dl, '0'              ; Convert to ASCII
    mov [esi], dl            ; Store digit
    dec esi
    jmp write_dollars_loop

write_zero_dollar:
    mov byte [esi], '0'
    dec esi

finalize_amount:
    inc esi                  ; Point to start of string
    mov eax, 4               ; sys_write
    mov ebx, 1               ; stdout
    mov ecx, esi             ; String to print

    ; Calculate string length
    mov edi, esi
len_loop_amt:
    cmp byte [edi], 0         ; check null terminator
    je have_len_amt
    inc edi
    jmp len_loop_amt
have_len_amt:
    mov edx, edi
    sub edx, ecx             ; EDX = length
    int 0x80

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_no_records:
    call close_file
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, no_records_msg
    mov edx, no_records_msg_len
    int 0x80
    ret