section .data
    menu db "==========================",10
         db "   CONTACT MANAGER MENU   ",10
         db "==========================",10
         db "1. Add Contact",10
         db "2. View Contacts",10
         db "3. Edit Contact",10
         db "4. Delete Contact",10
         db "5. Exit",10
         db "Enter choice: ",0
    menu_len equ $ - menu

    invalid_choice_msg db "Invalid choice. Try again.",10,0
    invalid_choice_msg_len equ $ - invalid_choice_msg

    new_line db 0xA 
    new_line_len equ $ - new_line

    prompt_name db "Enter Contact Name (max 20 characters): ",0
    prompt_name_len equ $ - prompt_name

    prompt_number db "Enter Contact Number (max 12 characters): ",0
    prompt_number_len equ $ - prompt_number

section .bss
    input resb 4      ; Reserve 4 bytes (2 bytes for input, the remaining just to be safe)
    contacts resb 320 ; Reserve 320 bytes (32 bytes (20 for name and 12 for phone number) * 10 contacts)
    contact_count resd 1     ; Reserve 4 bytes to track the number of contacts

section .text
    global _start

_start:
menu_loop:
    ; Print menu
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, menu
    mov edx, menu_len
    int 0x80

    ; Read user input
    mov eax, 3          ; Call sys_read
    mov ebx, 0          ; stdin file descriptor
    mov ecx, input
    mov edx, 4
    int 0x80

    ; Check input option
    mov al, [input]
    cmp al, '1'
    je add_contact
    cmp al, '5'
    je exit_program

    ; Manage Invalid Input
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, invalid_choice_msg
    mov edx, invalid_choice_msg_len
    int 0x80

    ; Repeat menu in new line
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, new_line
    mov edx, new_line_len
    int 0x80
    jmp menu_loop

add_contact:
    ; Check space
    mov eax, [contact_count]

    ; Find free slot to store new contact
    mov ecx, 32         ; assign 32 bytes for ecx
    mul ecx
    mov esi, contacts   ; find where contacts is stored
    add esi, eax        ; find where the new contact slot

    ; Prompt name
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, prompt_name
    mov edx, prompt_name_len
    int 0x80

    ; Get name input
    mov eax, 3          ; Call sys_read
    mov ebx, 0          ; stdin file descriptor
    mov ecx, esi
    mov edx, 20         ; max 20 bytes for name
    int 0x80

    ; Prompt contact
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, prompt_number
    mov edx, prompt_number_len
    int 0x80

    ; Get contact input
    mov eax, 3          ; Call sys_read
    mov ebx, 0          ; stdin file descriptor
    mov ecx, esi
    add ecx, 20         ; store contact after name
    mov edx, 12         ; max 12 bytes for contact number
    int 0x80

    ; Increment contact count
    mov eax, [contact_count]    ; get contact count
    inc eax                     ; increment value
    mov [contact_count], eax    ; save value

    ; Go back to main menu
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, new_line
    mov edx, new_line_len
    int 0x80
    jmp menu_loop

exit_program:
    mov eax, 1          ; call sys_exit
    xor ebx, ebx        ; set exit code to 0 (success)
    int 0x80
