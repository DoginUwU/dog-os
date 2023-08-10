org 0x7C00 ; local address to legacy bios locate a bootloader

bits 16 ; set assembly to 16 bits

; macro to end line
%define ENDL 0x0D, 0x0A

start:
    jmp main


;
; Prints a string to the screen
;
; registers to modify
puts:
    push ax
    push si

; loop for characters
.loop:
    lodsb ; load next character
    or al, al ; verify if next character isnt null
    jz .done ; jump to destination if zero flag is set (finished)

    mov ah, 0x0e ; call bios interrupt
    mov bh, 0 ; page number0
    int 0x10

    jmp .loop
    
; finished load characters
.done:
    pop ax
    pop si
    ret


main:
    ; setup data segments
    mov ax, 0 ; cant write directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00 ; stack grows donwards from where are loaded in memory

    ; print message
    mov si, msg_hello
    call puts

    hlt ; Hold the CPU

.halt:
    jmp .halt ; goto (infinite loop)



msg_hello: db 'Hello, World!', ENDL, 0

times 510-($-$$) db 0 ; repeat N times, caculate the rest of bytes left to 510 | $ represent the current address loc | $$ represent the start address loc | db filll bytes with 0
dw 0AA55h ; define 2 byte value