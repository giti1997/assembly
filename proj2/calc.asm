; Ashena G.Mohammadi, 610394128
; calculator with the simple arithmetic functions-summation, multiplication,
; division, and subtraction-for both integers and floating point numbers

;******************************************************************************
;******************************************************************************

%macro hiprec 2
    push rax
    mov al, %1
    cmp al, byte '/'
    je check_second
    cmp al, byte '*'
    je check_second
    jmp end_hiprec

    check_second:
    mov al, %2
    cmp al, byte '+'
    je is_higher
    cmp al, byte '-'
    je is_higher
    jmp end_hiprec

    is_higher:
    mov ax, higherprec
    clc
    bts [calc_flag], ax

    end_hiprec:
    pop rax
%endmacro

section .data
    msg db "Enter a valid operation or q to exit:", 10
    msg_len equ $-msg
    errormsg db "Illegal operation. Please, try again.", 10
    error_len equ $-errormsg
    divide_by_zero db "divide by zero", 10
    div_len equ $-divide_by_zero

    termios times 36 db 0
    stdin equ 0
    ICANON equ 1<<1
    ECHO equ 1<<3
    sys_read equ 3
    sys_write equ 4
    stdout equ 1

    isfloat equ 1
    opentered equ 2
    numentered equ 3
    erroccured equ 4
    higherprec equ 5
    isneg equ 6

    max_size equ 15
    calc_flag db 0
    num_len db 0
    dot_pos db 0
    num dq 0
    ten dq 10
    oldcontrol dw 0
    newcontrol dw 0
    fsig dq 0.0
    fexp dq 0.0

;******************************************************************************

section .bss
    op_stack resb max_size      ; operators' stack
    num_stack resq max_size     ; operands' stack
    inp resb 1                  ; holds input char
    output resb max_size        ; saves output

;******************************************************************************

section .text
    global _start

_start:
    call canonical_off
    call evaluate_expression

;------------------------------------------------------------------------------

exit:
    call canonical_on
    mov rax, 1
    mov rbx, 0
    int 80h

;------------------------------------------------------------------------------

evaluate_expression:
    mov rsi, num_stack
    mov rdi, op_stack
    read_loop:
        call read_char
        call evaluate_char
        mov bx, erroccured
        clc
        bt [calc_flag], bx
        jnc read_loop
    xor rax, rax
    xor rbx, rbx
    xor rdx, rdx
    mov qword[num], 0
    mov byte[calc_flag], 0
    mov byte[num_len], 0
    mov byte[dot_pos], 0
    mov rdi, op_stack
    mov rcx, max_size
    clear_op_stack:
        mov [rdi], bl
        inc rdi
        loop clear_op_stack
    mov rsi, num_stack
    mov rcx, max_size
    clear_num_stack:
        mov [rsi], rbx
        add rsi, 8
        loop clear_num_stack
    xor rcx, rcx
    jmp evaluate_expression
    ret

;..............................................................................

read_char:
    ; save contents of registers
    push rax
    push rbx
    push rcx
    push rdx

    ; sys_read
    mov byte [inp], 0
    mov rax, sys_read
    mov rbx, stdin
    mov rcx, inp
    mov edx, 2
    int 80h

    ; retrieve contents of registers
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

evaluate_char:
    ; save contents of registers
    push rax
    push rbx

    ; check quit command
    mov al, byte 'q'
    cmp al, [inp]
    je exit

    ;check end of line
    mov al, byte '='
    cmp al, [inp]
    jne dot
    call push_number
    call calculate
    call print_result
    jmp end_evaluate_char

    ; check for .
    dot:
    mov al, byte '.'
    cmp al, [inp]
    jne plus
    mov al, [num_len]
    mov [dot_pos], al
    mov ax, isfloat
    clc
    bts [calc_flag], ax
    jmp end_evaluate_char

    ; check operators
    plus:
    mov al, byte '+'
    cmp al, [inp]
    jne minus
    call push_number
    push qword[inp]
    call evaluate_operator
    jmp end_evaluate_char

    minus:
    mov al, byte '-'
    cmp al, [inp]
    jne star
    call push_number
    push qword[inp]
    call evaluate_operator
    jmp end_evaluate_char

    star:
    mov al, byte '*'
    cmp al, [inp]
    jne divide
    call push_number
    push qword[inp]
    call evaluate_operator
    jmp end_evaluate_char

    divide:
    mov al, byte '/'
    cmp al, [inp]
    jne digit
    call push_number
    push qword[inp]
    call evaluate_operator
    jmp end_evaluate_char

    ; check digit
    digit:
    mov al, byte '9'
    cmp al, [inp]
    jl char_error
    mov al, byte '0'
    cmp al, [inp]
    jg char_error
    xor rbx, rbx
    mov bl, [inp]
    sub bl, al
    push rbx
    call atoi
    mov ax, numentered
    clc
    bts [calc_flag], ax
    mov ax, opentered
    clc
    btr [calc_flag], ax
    jmp end_evaluate_char

    ; invalid expression
    char_error:
    call invalid_exp_err

    end_evaluate_char:
    ; retrieve contents of registers
    pop rbx
    pop rax
    ret

;..............................................................................

push_number:
    ; save registers' contents
    push rax
    push rbx
    push rcx

    mov bx, numentered
    clc
    btr [calc_flag], bx
    jnc end_push_number

    mov bx, isneg
    clc
    bt [calc_flag], bx
    jnc continue
    neg qword[num]

    continue:
    mov bx, isfloat
    clc
    bt [calc_flag], bx
    jc push_float
    mov al, [num_len]
    mov [dot_pos], al

    push_float:
    xor rcx, rcx
    mov cl, [num_len]
    sub cl, [dot_pos]
    fild qword[ten]
    fild qword[num]
    convert_to_float_loop:
        cmp rcx, 0
        je end_loop
        fdiv st1
        dec rcx
        jmp convert_to_float_loop
        end_loop:
    fstp qword[rsi]

    add rsi, 8
    mov qword[num], 0
    mov byte[dot_pos], 0
    mov byte[num_len], 0
    mov ax, isfloat
    btr [calc_flag], ax
    clc

    end_push_number:
    ; retrieve registers' contents
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

evaluate_operator:
    enter 8, 0
    ; save registers' contents
    mov [rbp - 8], rax

    mov ax, opentered
    clc
    bt [calc_flag], ax
    jnc check_prec
    mov al, '-'
    cmp [rbp + 16], al
    jne operator_error
    cmp [rdi], al
    jne operator_error
    mov ax, isneg
    clc
    btc [calc_flag], ax
    jmp end_evaluate_operator

    check_prec:
    clc
    cmp rdi, op_stack
    je push_operator
    hiprec byte[rbp + 16], byte[rdi]
    jc push_operator
    call calculate

    push_operator:
    mov ax, higherprec
    clc
    btr [calc_flag], ax
    mov al, [rbp + 16]
    mov [rdi], al
    inc rdi
    jmp end_evaluate_operator

    operator_error:
    call invalid_exp_err

    end_evaluate_operator:
    mov ax, opentered
    clc
    bts [calc_flag], ax
    ; retrieve registers' contents
    mov rax, [rbp - 8]

    leave
    ret 8

;..............................................................................

atoi:
    enter 16, 0
    ; save registers' contents
    mov [rbp - 8], rax
    mov [rbp - 16], rdx

    mov rax, [num]
    mul qword[ten]
    add rax, [rbp + 16]
    mov [num], rax
    inc byte [num_len]

    end_atoi:
    ; retrieve contents of registers
    mov rdx, [rbp - 16]
    mov rax, [rbp - 8]
    leave
    ret 8

;..............................................................................

calculate:
    ; save registers' contents
    push rax
    push rbx
    push rcx
    push rdx

    fstcw word[oldcontrol]
    mov ax, [oldcontrol]
    mov [newcontrol], ax
    mov ax, 11
    btr word[newcontrol], ax
    mov ax, 10
    btr word[newcontrol], ax
    clc
    fldcw word[newcontrol]

    sub rsi, 8
    fld qword[rsi]
    fldz
    fstp qword[rsi]
    sub rsi, 8
    fld qword[rsi]
    fldz
    fstp qword[rsi]

    sub rdi, 8
    mov al, [rdi]
    mov byte[rdi], 0

    cmp al, byte '+'
    je do_addition
    cmp al, byte '-'
    je do_subtraction
    cmp al, byte '*'
    je do_multiplication
    cmp al, byte '/'
    je do_division

    do_addition:
    fadd st1
    jmp end_calculate

    do_subtraction:
    fsub st1
    jmp end_calculate

    do_multiplication:
    fmul st1
    jmp end_calculate

    do_division:
    fdiv st1
    fstsw ax
    bt ax, 2
    jnc end_calculate
    call goto_nextline
    mov rax, sys_write
    mov rbx, stdout
    mov rcx, divide_by_zero
    mov rdx, div_len
    int 80h
    jmp exit

    end_calculate:
    fstp qword[rsi]
    add rsi, 8
    fldcw word[oldcontrol]

    ; retrieve registers' contents
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

print_result:
    ; save registers' contents
    push rax
    push rbx
    push rcx
    push rdx
    push r8

    mov r8, output
    sub rsi, 8
    fld qword[rsi]
    fxam
    fstsw ax
    bt ax, 9
    jnc generate_output
    mov al, byte '-'
    mov [r8], al
    inc r8
    fchs

    generate_output:
    call extract_exp
    fld qword[fexp]
    fistp qword[fexp]
    fld qword[ten]
    fld qword[rsi]
    mov rcx, [fexp]
    ftoi_loop:
        cmp rcx, 0
        je end_ftoi_loop
        fmul st1
        dec rcx
        jmp ftoi_loop
        end_ftoi_loop:
    fistp qword[fsig]

    xor rcx, rcx
    mov rax, qword[fsig]
    itoa_loop:
        xor rbx, rbx
        cmp [fexp], rbx
        je convert_number
        cmp rcx, [fexp]
        jne convert_number
        mov bl, byte '.'
        mov [r8], bl
        inc r8
        inc rcx
        convert_number:
        xor rdx, rdx
        div qword[ten]
        add dl, byte '0'
        mov [r8], dl
        inc r8
        inc rcx
        cmp rax, 0
        jne itoa_loop

    call goto_nextline

    mov rdx, rcx
    mov rax, sys_write
    mov rbx, stdout
    mov rcx, output
    int 80h

    clear_output:
    mov rcx, rdx
    xor rdx, rdx
    mov r8, output
    clear_output_loop:
        mov [r8], dl
        loop clear_output_loop

    add rsi, 8
    ; retrieve registers' contents
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

extract_exp:
    fld st0
    fldlg2
    fxch st1            ; st2 = fvar, st1 = log_10(2), st0 = fvar
    fyl2x               ; log_10(fvar) = log_10(2) * log_2(fvar)
    frndint             ; truncate log_10(fvar)
    fst qword[fexp]
    ; fsig = fvar / 10^(fexp)
    fldl2t              ; st2 = fvar, st1 = fexp, st0 = log_2(10)
    fmulp               ; m = log_2(10) * fexp
    fld st0
    frndint             ; integral part of m
    fxch st1            ; st2 = fvar, st1 = integer, st0 = m
    fsub st0, st1       ; fractional part of m
    f2xm1
    fld1
    faddp               ; 2^(fraction)
    fscale              ; 10^fexp = 2^(integer) * 2^(fraction)
    fstp st1            ; st1 = fvar, st0 = 10^fexp
    fdivp               ; fvar / 10^fexp
    fstp qword[fsig]
    ret

;..............................................................................

invalid_exp_err:
    ; save registers' contents
    push rax
    push rbx
    push rcx
    push rdx

    call goto_nextline

    mov rax, sys_write
    mov rbx, stdout
    mov rcx, errormsg
    mov rdx, error_len
    int 80h

    mov bx, erroccured
    clc
    bts [calc_flag], bx

    ; retrieve registers' contents
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

goto_nextline:
    ; save registers' contents
    push rax
    push rbx
    push rcx
    push rdx

    mov rax, sys_write
    mov rbx, stdout
    mov rcx, 10
    mov rdx, 1
    int 80h

    ; retrieve registers' contents
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;------------------------------------------------------------------------------

canonical_off:
    call read_stdin_termios

    ; clear canonical bit in local mode flags
    push rax
    mov eax, ICANON
    not eax
    and [termios+12], eax
    pop rax

    call write_stdin_termios
    ret

;..............................................................................

echo_off:
    call read_stdin_termios

    ; clear echo bit in local mode flags
    push rax
    mov eax, ECHO
    not eax
    and [termios+12], eax
    pop rax

    call write_stdin_termios
    ret

;..............................................................................

canonical_on:
    call read_stdin_termios

    ; set canonical bit in local mode flags
    or dword [termios+12], ICANON

    call write_stdin_termios
    ret

;..............................................................................

echo_on:
    call read_stdin_termios

    ; set echo bit in local mode flags
    or dword [termios+12], ECHO

    call write_stdin_termios
    ret

;..............................................................................

read_stdin_termios:
    push rax
    push rbx
    push rcx
    push rdx

    mov eax, 36h
    mov ebx, stdin
    mov ecx, 5401h
    mov edx, termios
    int 80h

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

;..............................................................................

write_stdin_termios:
    push rax
    push rbx
    push rcx
    push rdx

    mov eax, 36h
    mov ebx, stdin
    mov ecx, 5402h
    mov edx, termios
    int 80h

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
