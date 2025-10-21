global add_record
global get_record_count
global print_records
global calculate_balance
global print_amount
global find_record_by_id
global perform_delete
global update_record

extern repeat_menu
extern print_new_line

section .data
    filename db "budget.db", 0
    temp_filename db "budget_temp.db", 0
    file_handle dd 0    ; reserve 4 bytes to store file descriptor
    temp_file_handle dd 0    ; reserve 4 bytes to store temp file descriptor
    
    ; Record structure: [ID(4)][Type(1)][Amount(4)][Description(55)]
    RECORD_SIZE equ 64 ; Total: 64 bytes per record
        
    error_open_file db "Error: Could not open file", 0xA, 0
    error_open_file_len equ $ - error_open_file - 1

    error_calc_balance db "Error: Failed to calculate balance", 0xA, 0
    error_calc_balance_len equ $ - error_open_file - 1

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

    current_balance dd 0
    
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
    ; Input: eax = amount in cents (e.g., 12345 = $123.45)
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

calculate_balance:
    ; Calculate total balance from all records
    ; eax will return the balance
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Initialize balance to 0
    xor eax, eax        
    mov [current_balance], eax
    
    ; Open file for reading
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl calc_balance_error
    mov [file_handle], eax
    
    ; Get file size to check if there are records
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    je calc_balance_done    ; No records, set balance to 0
    
    mov esi, eax        ; save file size
    
    ; Seek back to beginning of file
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    ; Calculate number of records
    mov eax, esi
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             
    
    mov ebx, 0          ; record counter
    mov ecx, eax        ; total records
    
    calc_read_loop:
        cmp ebx, ecx    ; end loop condition
        jge calc_balance_done
        
        push ebx
        push ecx
        
        ; Read one record
        mov eax, 3      ; sys_read
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Process the record
        call process_record_for_balance
        pop ecx
        pop ebx
        
        inc ebx
        jmp calc_read_loop
    
calc_balance_done:
    call close_file
    mov eax, [current_balance]  ; get final balance
    jmp calc_balance_exit
    
calc_balance_error:
    call close_file
    mov eax, 0          ; return 0 on error

    ; Print error message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_calc_balance
    mov edx, error_calc_balance_len
    int 0x80
    
    jmp repeat_menu             
    
calc_balance_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

process_record_for_balance:
    ; Input: record_buffer contains the record
    push eax
    push ebx
    push ecx
    push edx
    push esi
    
    mov esi, record_buffer
    
    ; Skip ID (4 bytes)
    add esi, 4
    mov cl, [esi]       ; Get type (0 = income, 1 = expense)

    ; Skip Type
    add esi, 1
    ; Get Amount (4 bytes)
    mov ebx, [esi]      ; Get amount in cents
    
    ; Get current balance
    mov eax, [current_balance]
    
    ; Check if it's income or expense
    cmp cl, 0
    je add_income_to_balance
    jmp subtract_expense_from_balance
    
add_income_to_balance:
    ; Add income to balance
    add eax, ebx        ; add income amount
    mov [current_balance], eax ; save updated balance
    jmp process_done
    
subtract_expense_from_balance:
    ; Subtract expense from balance
    sub eax, ebx        ; subtract expense amount
    mov [current_balance], eax ; save updated balance
    
process_done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

find_record_by_id:
    ; Parameters:
    ;   eax = ID to search for
    ; Returns:
    ;   eax = 1 if found, 0 if not found
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov edi, eax        ; Save ID to search for
    
    ; Open file
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl find_error
    mov [file_handle], eax
    
    ; Get file size to check if there are records
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    je id_not_found   ; No records
    
    mov esi, eax        ; save file size
    
    ; Seek back to beginning of file
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    ; Calculate number of records
    mov eax, esi
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             
    
    mov ebx, 0          ; record counter
    mov ecx, eax        ; total records
    
    find_loop:
        cmp ebx, ecx    ; end loop condition
        jge id_not_found
        
        push ebx
        push ecx
        
        ; Read one record
        mov eax, 3      ; sys_read
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        mov eax, [record_buffer]    ; Get ID from record
        cmp eax, edi                ; Compare with search ID
        je id_found
        
        pop ecx
        pop ebx
        inc ebx
        jmp find_loop
    
id_found:
    pop ecx
    pop ebx
    call close_file
    mov eax, 1          
    jmp find_exit
    
id_not_found:
    call close_file
    mov eax, 0          
    jmp find_exit
    
find_error:
    call close_file
    mov eax, 0         

find_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

perform_delete:
    ; Parameters:
    ;   eax = ID to delete
    ; Returns:
    ;   eax = 1 if successful, 0 if failed
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov edi, eax        ; Save ID to delete
    
    ; Open file for reading
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl open_error
    mov [file_handle], eax
    
    ; Get file size
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    jle lseek_error     
        
    ; Calculate number of records
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    cmp eax, 0
    je delete_no_records     ; No records
    
    mov esi, eax        ; Save number of records in edx
        
    ; Open temp file
    mov eax, 5          ; sys_open
    mov ebx, temp_filename
    mov ecx, 0x241      ; O_CREAT | O_WRONLY | O_TRUNC
    mov edx, 0644       ; file permissions
    int 0x80
    
    cmp eax, 0
    jl delete_error
    mov [temp_file_handle], eax
    
    ; Seek to beginning
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    mov ebx, 0          ; record counter
    mov ecx, esi        ; total records
    mov edx, 0          ; found flag (0 = not found, 1 = found)

    ; Copy all records to temp file, skipping the one to delete
    copy_loop:
        cmp ebx, ecx   
        jge copy_done
        
        push ebx
        push ecx
        
        ; Read one record
        mov eax, 3      ; sys_read
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if read was successful
        cmp eax, 0
        jl copy_error     ; If read failed
        je copy_done      ; If read 0 bytes, pointer reached EOF
        cmp eax, RECORD_SIZE
        jne copy_error    ; If read different number of bytes, error
        
        ; Check if this is the record to delete
        mov eax, [record_buffer]    ; Get ID from record, loads first four bytes
        cmp eax, edi                ; Compare with ID to delete
        je found_record             ; Found the record to delete
        
        ; Write record to temp file
        mov eax, 4      ; sys_write
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if write was successful
        cmp eax, RECORD_SIZE
        jne copy_error
        
        jmp continue_loop
        
    found_record:
        mov edx, 1          ; Set found flag
        ; Skip writing this record (don't copy to temp file)
        
    continue_loop:
        pop ecx
        pop ebx
        inc ebx
        jmp copy_loop
    
copy_error:
    ; Clean up and exit on error
    pop ecx
    pop ebx
    jmp delete_error
    
copy_done:
    ; Check if the record was found
    cmp edx, 0
    je record_not_found
    
    ; Close both files
    call close_file
    call close_temp_file

    ; Open temp file for reading
    mov eax, 5          ; sys_open
    mov ebx, temp_filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl copy_back_error    
    mov [temp_file_handle], eax
        
    ; Get file size
    mov eax, 19         ; sys_lseek
    mov ebx, [temp_file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    jl delete_error     
        
    ; Calculate number of records
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    cmp eax, 0
    je handle_empty_file     ; No records in temp file (all deleted)
    
    mov esi, eax        ; save number of records

    ; Open original file for writing
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0x241       ; read write and truncate
    mov edx, 0644        ; file permissions
    int 0x80
    
    cmp eax, 0
    jl delete_error
    mov [file_handle], eax
    
    ; Seek to beginning of temp file
    mov eax, 19         ; sys_lseek
    mov ebx, [temp_file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    cmp eax, 0
    jl copy_back_error
    
    mov ebx, 0          ; record counter
    mov ecx, esi        ; total records
    
    ; Copy all data from temp file to original file
    copy_back_loop:
        cmp ebx, ecx
        jge copy_back_done
        
        push ebx
        push ecx

        ; Read one record from temp file
        mov eax, 3      ; sys_read
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if read was successful
        cmp eax, 0
        jl copy_back_error     ; If read failed
        je copy_back_done      ; pointer reached EOF
        cmp eax, RECORD_SIZE
        jne copy_back_error    ; If read different number of bytes, error
        
        ; Write record to original file
        mov eax, 4      ; sys_write
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if write was successful
        cmp eax, RECORD_SIZE
        jne copy_back_error     ; If write failed 

        pop ecx
        pop ebx
        inc ebx
        
        ; Check if we've processed all records before continuing
        cmp ebx, ecx
        jge copy_back_done
        
        jmp copy_back_loop
    
handle_empty_file:
    ; All records were deleted, just truncate the original file
    call close_temp_file
    
    ; Open original file for writing (truncate to 0)
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0x241       ; O_CREAT | O_WRONLY | O_TRUNC
    mov edx, 0644        ; file permissions
    int 0x80
    
    cmp eax, 0
    jl delete_error
    mov [file_handle], eax
    
    ; Close the file (it's now empty)
    call close_file
    
    mov eax, 1          ; success
    jmp delete_exit
    
copy_back_done:
    ; Close both files
    call close_file
    call close_temp_file
    
    ; ; Delete temp file
    ; mov eax, 10         ; sys_unlink
    ; mov ebx, temp_filename
    ; int 0x80
    
    mov eax, 1          ; success
    jmp delete_exit

copy_back_error:
    ; Clean up stack if needed
    pop ecx
    pop ebx
    call close_file
    call close_temp_file
    jmp delete_error
    
delete_no_records:
    call close_file
    mov eax, 0          ; failure - no records to delete
    jmp delete_exit

record_not_found:
    call close_file
    call close_temp_file
    mov eax, 0          ; failure - record not found
    jmp delete_exit

delete_error:
    call close_file
    call close_temp_file
    mov eax, 0          ; failure
    
delete_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

close_temp_file:
    mov eax, 6          ; sys_close
    mov ebx, [temp_file_handle]
    int 0x80
    ret

update_record:
    ; Parameters:
    ;   eax = ID to update
    ;   ebx = field to update (1 = amount, 2 = description)
    ;   ecx = new amount (if ebx = 1) or new description pointer (if ebx = 2)
    ;   edx = new description length (if ebx = 2)
    ; Returns:
    ;   eax = 1 if successful, 0 if failed
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov edi, eax        ; Save ID to update
    mov esi, ebx        ; Save field to update
    push ecx            ; Save new value
    push edx            ; Save description length
    
    ; Open file for reading
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl update_error
    mov [file_handle], eax
    
    ; Get file size
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    jle update_error
    
    ; Calculate number of records
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    cmp eax, 0
    je update_error     ; No records
    
    mov esi, eax        ; Save number of records
    
    ; Open temp file
    mov eax, 5          ; sys_open
    mov ebx, temp_filename
    mov ecx, 2          ; open file read write access
    int 0x80
    
    cmp eax, 0
    jl update_error
    mov [temp_file_handle], eax
    
    ; Seek to beginning
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    mov ebx, 0          ; record counter
    mov ecx, esi        ; total records
    mov esi, 0          ; found flag

    ; Copy all records to temp file, updating the target record
    update_copy_loop:
        cmp ebx, ecx   
        jge update_copy_done
        
        push ebx
        push ecx
        
        ; Read one record
        mov eax, 3      ; sys_read
        mov ebx, [file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if read was successful
        cmp eax, 0
        jl update_copy_error     ; If read failed
        je update_copy_done      ; If read 0 bytes, pointer reached EOF
        cmp eax, RECORD_SIZE
        jne update_copy_error    ; If read different number of bytes, error
        
        ; Check if this is the record to update
        mov eax, [record_buffer]    ; Get ID from record
        cmp eax, edi                ; Compare with ID to update
        je update_this_record       ; Update this record
        
        ; Write record to temp file (unchanged)
        mov eax, 4      ; sys_write
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if write was successful
        cmp eax, RECORD_SIZE
        jne update_copy_error
        
        jmp update_skip_record
        
    update_this_record:
        ; Update the record based on field type
        pop edx         ; Get description length
        pop ecx         ; Get new value
        pop esi         ; Get field type
        push esi        ; Restore field type
        push ecx        ; Restore new value
        push edx        ; Restore description length
        
        cmp esi, 1
        je update_amount_field
        cmp esi, 2
        je update_description_field
        jmp update_copy_error  ; Invalid field type
        
    update_amount_field:
        ; Update amount field (offset 5-8 in record)
        mov [record_buffer + 5], ecx  ; Store new amount
        jmp update_write_record
        
    update_description_field:
        ; Update description field (offset 9-63 in record)
        ; Clear description field first
        mov edi, record_buffer
        add edi, 9
        mov ecx, 55
        xor eax, eax
        rep stosb
        
        ; Copy new description
        mov edi, record_buffer
        add edi, 9
        mov esi, ecx    ; ecx contains new description pointer
        mov ecx, edx    ; edx contains description length
        rep movsb
        
    update_write_record:
        ; Write updated record to temp file
        mov eax, 4      ; sys_write
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if write was successful
        cmp eax, RECORD_SIZE
        jne update_copy_error
        
        mov esi, 1      ; Set found flag
        
    update_skip_record:
        pop ecx
        pop ebx
        inc ebx
        jmp update_copy_loop
    
    update_copy_error:
        ; Clean up and exit on error
        pop ecx
        pop ebx
        jmp update_error
    
    update_copy_done:
        ; Check if record was found
        cmp esi, 0
        je update_not_found
        
        ; Close both files
        call close_file
        call close_temp_file

        ; Now copy data back from temp file to original file
        mov eax, 5          ; sys_open
        mov ebx, filename
        mov ecx, 577o       ; O_CREAT | O_WRONLY | O_TRUNC
        mov edx, 644o      ; file permissions
        int 0x80
        
        cmp eax, 0
        jle update_error    ; file descriptor should be positive
        mov [file_handle], eax
        
        ; Open temp file for reading
        mov eax, 5          ; sys_open
        mov ebx, temp_filename
        mov ecx, 0          ; read only access
        int 0x80
        
        cmp eax, 0
        jle update_error    
        mov [temp_file_handle], eax
        
        ; Get temp file size
        mov eax, 19         ; sys_lseek
        mov ebx, [temp_file_handle]
        mov ecx, 0          ; offset from start
        mov edx, 2          ; Go to end of file
        int 0x80
        
        cmp eax, 0
        je update_copy_back_done   ; No data to copy back
        
        ; Seek back to beginning of temp file
        mov eax, 19         ; sys_lseek
        mov ebx, [temp_file_handle]
        mov ecx, 0          ; offset from start
        mov edx, 0          ; Go to beginning
        int 0x80
        
        ; Copy all data from temp file to original file
        update_copy_back_loop:
            ; Read one record from temp file
            mov eax, 3      ; sys_read
            mov ebx, [temp_file_handle]
            mov ecx, record_buffer
            mov edx, RECORD_SIZE
            int 0x80
            
            ; Check if read was successful
            cmp eax, 0
            jl update_copy_back_error     ; If read failed
            je update_copy_back_done      ; pointer reached EOF
            cmp eax, RECORD_SIZE
            jne update_copy_back_error    ; If read different number of bytes, error
            
            ; Write record to original file
            mov eax, 4      ; sys_write
            mov ebx, [file_handle]
            mov ecx, record_buffer
            mov edx, RECORD_SIZE
            int 0x80
            
            ; Check if write was successful
            cmp eax, 0
            jl update_copy_back_error     ; If write failed (negative return)
            cmp eax, RECORD_SIZE
            jne update_copy_back_error    ; If didn't write all bytes
            
            jmp update_copy_back_loop
        
    update_copy_back_done:
        ; Close both files
        call close_file
        call close_temp_file
        
        ; Delete temp file
        mov eax, 10         ; sys_unlink
        mov ebx, temp_filename
        int 0x80
        
        mov eax, 1          ; success
        jmp update_exit

    update_copy_back_error:
        call close_file
        call close_temp_file
        jmp update_error
    
    update_not_found:
        call close_file
        call close_temp_file
        mov eax, 0          ; record not found
        jmp update_exit
        
    update_error:
        call close_file
        call close_temp_file
        mov eax, 0          ; failure
    
    update_exit:
        pop edi
        pop esi
        pop edx
        pop ecx
        pop ebx
        ret
