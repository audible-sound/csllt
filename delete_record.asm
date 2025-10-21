global delete_record
extern repeat_menu
extern find_record_by_id
extern perform_delete
extern print_new_line

section .data
    id_prompt db "Enter ID of record to delete: ", 0
    id_prompt_len equ $ - id_prompt - 1

    confirmation_prompt db "Are you sure you want to delete this record? (y/n): ", 0
    confirmation_prompt_len equ $ - confirmation_prompt - 1

    record_not_found db "Record with that ID not found.", 0xA, 0
    record_not_found_len equ $ - record_not_found - 1

    delete_success db "Record deleted successfully.", 0xA, 0
    delete_success_len equ $ - delete_success - 1

    delete_cancelled db "Deletion cancelled.", 0xA, 0
    delete_cancelled_len equ $ - delete_cancelled - 1

    error_delete db "Error: Failed to delete record.", 0xA, 0
    error_delete_len equ $ - error_delete - 1
        
section .bss
    input_buffer resb 16

section .text
delete_record:
    ; Save registers
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Print ID prompt
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, id_prompt
    mov edx, id_prompt_len
    int 0x80

    ; Read ID from user input
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input_buffer
    mov edx, 16
    int 0x80

    ; Convert ASCII to number
    call convert_string_to_number
    cmp eax, 0
    jle invalid_id
    
    ; Save the ID for later use
    push eax

    ; Find the record
    call find_record_by_id
    cmp eax, 0
    je record_not_found_msg

    ; Record found, show confirmation prompt
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, confirmation_prompt
    mov edx, confirmation_prompt_len
    int 0x80

    ; Read confirmation
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input_buffer
    mov edx, 16
    int 0x80

    ; Check if user confirmed (y or Y)
    mov al, [input_buffer]
    cmp al, 'y'
    je delete_confirmed
    cmp al, 'Y'
    je delete_confirmed

    ; User cancelled
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, delete_cancelled
    mov edx, delete_cancelled_len
    int 0x80
    jmp delete_exit

delete_confirmed:
    pop eax             ; Restore the ID
    call perform_delete
    cmp eax, 0 ; 0 fail to delete / 1 delete successful
    je delete_error

    ; Success message
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, delete_success
    mov edx, delete_success_len
    int 0x80
    jmp delete_exit

record_not_found_msg:
    pop eax             ; Clean up the stack
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, record_not_found
    mov edx, record_not_found_len
    int 0x80
    jmp delete_exit

invalid_id:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, record_not_found
    mov edx, record_not_found_len
    int 0x80
    jmp delete_exit

delete_error:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_delete
    mov edx, error_delete_len
    int 0x80

delete_exit:
    call print_new_line
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
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