section .data
    menu db "==========================",0xA
         db "   CONTACT MANAGER MENU   ",0xA
         db "==========================",0xA
         db "1. Add Contact",0xA
         db "2. View Contacts",0xA
         db "3. Edit Contact",0xA
         db "4. Delete Contact",0xA
         db "5. Exit",0xA
         db "Enter choice: ",0
    menu_len equ $ - menu

    invalid_choice_msg db "Invalid choice. Try again.",0xA,0
    invalid_choice_msg_len equ $ - invalid_choice_msg

    new_line db 0xA 
    new_line_len equ $ - new_line

    prompt_name db "Enter Contact Name (max 20 characters): ",0
    prompt_name_len equ $ - prompt_name

    prompt_number db "Enter Contact Number (max 12 characters): ",0
    prompt_number_len equ $ - prompt_number

    err_file_open_msg db "Error opening file",0xA,0
    err_file_open_len equ $ - err_file_open_msg

    filename db "contacts.csv", 0
    file_buffer_size equ 4096 ; 4KB

section .bss
    input resb 2      ; Reserve 4 bytes (2 bytes for input, the remaining just to be safe)
    contacts resb 320 ; Reserve 320 bytes (32 bytes (20 for name and 12 for phone number) * 10 contacts)
    file_buffer resb file_buffer_size; Files will be read at 4KB blocks

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
    mov edx, 2
    int 0x80

    ; Check input option
    mov al, [input]
    cmp al, '5'
    je exit_program

    ; Manage Invalid Input
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, invalid_choice_msg
    mov edx, invalid_choice_msg_len
    int 0x80

    ; Repeat menu in new line
    call print_new_line
    jmp menu_loop

print_new_line:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, new_line
    mov edx, new_line_len
    int 0x80
    ret

exit_program:
    mov eax, 1          ; call sys_exit
    xor ebx, ebx        ; set exit code to 0 (success)
    int 0x80
