section .data
    menu db 10, "==========================",10
         db "   CONTACT MANAGER MENU   ",10
         db "==========================",10
         db "1. Add Contact",10
         db "2. View Contacts",10
         db "3. Edit Contact",10
         db "4. Delete Contact",10
         db "5. Exit",10
         db "Enter choice: ",0

    invalid_choice_msg db "Invalid choice. Try again.",10,0

section .bss
    input resb 4      ; Reserve 4 bytes (2 bytes for input, the remaining just to be safe)

section .text
    global _start

_start:
menu_loop:
    ; Print menu
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, menu
    mov edx, menu_end - menu
    int 0x80
