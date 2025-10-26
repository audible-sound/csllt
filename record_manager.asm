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
    filename db "budget.dat", 0
    temp_filename db "budget_temp.dat", 0

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
    push ebx
    push ecx
    push edx
    push esi
    
    ; Open file
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl open_error       ; if error
    mov [file_handle], eax        ; file descriptor
    
    mov esi, 0          ; highest ID
    mov ebx, 0          ; current ID
    
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0
    mov edx, 2          ; SEEK_END
    int 0x80
    
    cmp eax, 0
    jle empty_file_id      
    
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0
    mov edx, 0          ; SEEK_SET
    int 0x80
    
    mov ebx, 0          ; reset counter
    
read_records_loop:
    mov eax, 3          ; sys_read
    mov ebx, [file_handle]
    mov ecx, record_buffer
    mov edx, RECORD_SIZE
    int 0x80
    
    cmp eax, 0
    jl open_error
    je read_done      
    
    mov eax, [record_buffer]    ; get the ID (4 bytes)
    
    ; Compare with current highest ID
    cmp eax, esi
    jle id_smaller_equal    
    mov esi, eax        
    
id_smaller_equal:
    jmp read_records_loop

read_done:
    inc esi
    mov eax, esi        
    push eax            
    call close_file
    pop eax           
    jmp id_done

empty_file_id:
    mov eax, 1
    push eax           
    call close_file
    pop eax             
    jmp id_done
        
id_done:
    pop esi
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
    mov ecx, 0          
    mov edx, 0          
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
        cmp ebx, ecx    
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
    add esi, 4             
    mov ecx, 55             
    mov edi, 0             
    
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
    mov ecx, esi            
    mov edx, edi            
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
    inc esi                 
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov edx, ecx           
    mov ecx, esi            
    int 0x80
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_space:
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
    push eax                 
    
    ; Write cents
    mov ebx, 10              
    xor eax, eax             
    mov al, dl               
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
    mov [esi], dl            
    dec esi
    jmp write_dollars_loop

write_zero_dollar:
    mov byte [esi], '0'
    dec esi

finalize_amount:
    inc esi                  ; Point to start of string
    mov eax, 4               ; sys_write
    mov ebx, 1               ; stdout
    mov ecx, esi             

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
    
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl calc_balance_error
    mov [file_handle], eax
    
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0         
    mov edx, 2          
    int 0x80
    
    cmp eax, 0
    je calc_balance_done    
    
    mov esi, eax        ; save file size
    
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          
    mov edx, 0          
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
    add eax, ebx       
    mov [current_balance], eax 
    jmp process_done
    
subtract_expense_from_balance:
    sub eax, ebx       
    mov [current_balance], eax 
    
process_done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

find_record_by_id:
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
    je id_not_found   
    
    mov esi, eax        ; save file size
    
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
        
        mov eax, [record_buffer]    
        cmp eax, edi               
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
    
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 2          ; Go to end of file
    int 0x80
    
    cmp eax, 0
    jl open_error     
        
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             
    
    cmp eax, 0
    je delete_no_records    
    
    mov esi, eax        ; Save number of records
        
    ; Open temp file
    mov eax, 5          ; sys_open
    mov ebx, temp_filename
    mov ecx, 0x241      ; read and write (truncate)
    mov edx, 0644       
    int 0x80
    
    cmp eax, 0
    jl delete_update_error
    mov [temp_file_handle], eax
    
    ; Seek to beginning
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          
    mov edx, 0         
    int 0x80
    
    mov ebx, 0          ; record counter
    mov ecx, esi        ; total records

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
        jl copy_error    
        je copy_done      
        cmp eax, RECORD_SIZE
        jne copy_error   
        
        ; Check if this is the record to delete
        mov eax, [record_buffer]    
        cmp eax, edi                
        je continue_loop             
        
        ; Write record to temp file
        mov eax, 4      ; sys_write
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        cmp eax, RECORD_SIZE
        jne copy_error
        
        jmp continue_loop
        
    continue_loop:
        pop ecx
        pop ebx
        inc ebx
        jmp copy_loop
    
copy_error:
    pop ecx
    pop ebx
    jmp delete_update_error
    
copy_done:
    ; Close both files
    call close_file
    call close_temp_file

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
    mov ecx, 0          
    mov edx, 2          
    int 0x80
    
    cmp eax, 0
    jl delete_update_error     
        
    ; Calculate number of records
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    cmp eax, 0
    je handle_empty_file     ; No records in temp file
    
    mov esi, eax        ; save number of records

    ; Open original file for writing
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0x241       ; read write and truncate
    mov edx, 0644        ; file permissions
    int 0x80
    
    cmp eax, 0
    jl delete_update_error
    mov [file_handle], eax
    
    ; Seek to beginning of temp file
    mov eax, 19         ; sys_lseek
    mov ebx, [temp_file_handle]
    mov ecx, 0          
    mov edx, 0         
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
        jl copy_back_error     
        je copy_back_done     
        cmp eax, RECORD_SIZE
        jne copy_back_error   
        
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
                
        jmp copy_back_loop
    
handle_empty_file:
    call close_temp_file
    
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0x241      
    mov edx, 0644       
    int 0x80
    
    cmp eax, 0
    jl delete_update_error
    mov [file_handle], eax
    
    ; Close the file
    call close_file
    
    mov eax, 1          
    jmp delete_update_exit
    
copy_back_done:
    ; Close both files
    call close_file
    call close_temp_file
        
    mov eax, 1          ; success
    jmp delete_update_exit

copy_back_error:
    ; Clean up stack if needed
    pop ecx
    pop ebx
    jmp delete_update_error
    
delete_no_records:
    call close_file
    mov eax, 0         
    jmp delete_update_exit

delete_update_error:
    call close_file
    call close_temp_file
    mov eax, 0          
    
delete_update_exit:
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
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov edi, eax        ; Save ID to update
    
    ; Open file for reading
    mov eax, 5          ; sys_open
    mov ebx, filename
    mov ecx, 0          ; read only access
    int 0x80
    
    cmp eax, 0
    jl delete_update_error
    mov [file_handle], eax
    
    ; Get file size
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          
    mov edx, 2          
    int 0x80
    
    cmp eax, 0
    jle delete_update_error
    
    ; Calculate number of records
    xor edx, edx
    mov ecx, RECORD_SIZE
    div ecx             ; eax = number of records
    
    cmp eax, 0
    je delete_update_error     ; No records
    
    mov esi, eax        ; Save number of records
    
    ; Open temp file
    mov eax, 5          ; sys_open
    mov ebx, temp_filename
    mov ecx, 0x241      ; read and write (truncate)
    mov edx, 0644       ; file permissions
    int 0x80
    
    cmp eax, 0
    jl delete_update_error
    mov [temp_file_handle], eax

    ; Seek to beginning
    mov eax, 19         ; sys_lseek
    mov ebx, [file_handle]
    mov ecx, 0          ; offset from start
    mov edx, 0          ; Go to beginning
    int 0x80
    
    mov ebx, 0          ; record counter
    mov ecx, esi        ; total records

    ; Copy all records to temp file and udpate target record
    update_copy_loop:
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
        jl copy_error    
        je  copy_done     
        cmp eax, RECORD_SIZE
        jne copy_error   
        
        ;  Check if this is the record to update
        mov eax, [record_buffer]    
        cmp eax, edi                
        je update_which_record       
        
        mov eax, 4      ; sys_write
        mov ebx, [temp_file_handle]
        mov ecx, record_buffer
        mov edx, RECORD_SIZE
        int 0x80
        
        ; Check if write was successful
        cmp eax, RECORD_SIZE
        jne copy_error
        
        jmp continue_update
        
    update_which_record:  
        mov eax, [esp + 24]      
        cmp eax, 1
        je update_amount_field
        cmp eax, 2
        je update_description_field
        jmp copy_error  ; Invalid field type
        
    update_amount_field:
        ; Update amount field (bits 5-8 in record)
        mov eax, [esp + 20]  ; Get new amount from stack
        mov [record_buffer + 5], eax  ; Store new amount
        jmp update_write_record
        
    update_description_field:
        ; Update description field (bits 9-63 in record)        
        ; Clear description field
        mov edi, record_buffer
        add edi, 9
        mov ecx, 55
        mov al, 0
        rep stosb 

        mov ecx, [esp + 20]  ;ecx contains new description pointer
        mov edx, [esp + 16] ; edx contains description length
        
        ; Copy new description
        mov edi, record_buffer
        add edi, 9
        mov esi, ecx    
        mov ecx, edx    
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
        jne copy_error
        
        jmp continue_update
        
    continue_update:
        pop ecx
        pop ebx
        inc ebx
        jmp update_copy_loop