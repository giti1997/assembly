; Ashena G.Mohammadi
; calculator with the simple arithmetic functions-summation, multiplication,
; division, and subtraction-for both integers and floating point numbers

section .data
    msg db "Enter a valid operation or x to exit:", 10
    msg_len equ $-msg
    error db "Illegal operation. Please, try again.", 10
    error_len equ $-error
    divide_by_zero db "divide by zero", 10
    div_len equ $-divide_by_zero
    result dq 0
    max_num_size equ 19                 ; max digits of a number
    max_inp_size equ 1000                 ; max size of input string

section .bss
    inp resb max_inp_size               ; keeps the input
    num resb max_num_size              ; keeps a number
    ; op resb 1                           ; keeps operator
    ; flag resb 1                         ; flags

section .text
    global _start

_start:
    mov rax, 1
    mov rdi, 0
    mov rsi, msg                        ; start message
    mov rdx, msg_len
    syscall

exit:
    mov rax, 1
    mov rbx, 0
    int 80h
