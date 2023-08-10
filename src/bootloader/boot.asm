org 0x7C00                                          ; local address to legacy bios locate a bootloader

bits 16                                             ; set assembly to 16 bits

; macro to end line
%define ENDL 0x0D, 0x0A

; FAT12 headers
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'
dbd_bytes_per_sector:       dw 512
bdb_sectores_per_cluster:   db 1
dbd_reserved_sectors:       dw 1
dbd_fat_count:              db 2
dbd_dir_entries_count:      dw 0E0h
dbd_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44mb
dbd_media_descriptor_type:  db 0F0h                 ; F0 = 3.5'' floppy disk
dbd_sectors_per_fat:        dw 9
dbd_sectors_per_track:      dw 18
dbd_heads:                  dw 2
dbd_hidden_sectors:         dd 0
dbd_large_sector_count:     dd 0

; extended boot records
ebr_drive_number:           db 0                    ; 0x00 = floppy, 0x80 = hdd
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 44h, 39h, 22h, 42h   ; seria number (whatever)
edb_volume_label:           db 'sound system'
edb_system_id:              db 'FAT12   '

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
        lodsb           ; load next character
        or al, al       ; verify if next character isnt null
        jz .done        ; jump to destination if zero flag is set (finished)

                        ; https://en.wikipedia.org/wiki/BIOS_interrupt_call
        mov ah, 0x0e    ; call bios interrupt
        mov bh, 0       ; page number 0
        int 0x10        ; call 10h - BIOS video service

        jmp .loop
        
    ; finished load characters
    .done:
        pop ax
        pop si
        ret


main:
    ; setup data segments
    mov ax, 0           ; cant write directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00      ; stack grows donwards from where are loaded in memory

    ; read from disk
    mov [ebr_drive_number], dl

    mov ax, 1           ; lba = 1 (second disk sector)
    mov cl, 1           ; 1 sector to read
    mov bx, 0x7E00      ; data shoud be placed after boot
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    cli                 ; disable interrupts
    hlt                 ; Hold the CPU

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h             ; Keyboard services
    jmp 0FFFFh:0        ; jump to beginning of BIOS

    .halt:
        cli             ; disable interrupts
        jmp .halt       ; goto (infinite loop)


; ---- Disk ----

; Convert LBA to CHS

lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [dbd_sectors_per_track]    ; ax = LBA / SectorsPerTrack | dx = LBA % SectorsPerTrack

    inc dx                              ; dx = sector = (LBA % SectorsPerTrack + 1)
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [dbd_heads]                ; ax = (LBA / SectorsPerTrack) / Heads | dx = (LBA / SectorsPerTrack) % Heads

    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder
    shl ah, 6
    or cl, ah                           ; higher 2 bits of cylinder (cl)

    pop ax
    mov dl, al
    pop ax
    ret

; Reads sectors from disk

disk_read:
    push ax                             ; save registers
    push bx
    push cx
    push dx
    push di

    push cx                             ; numbers of sectors to read
    call lba_to_chs                     ; compute CHS
    pop ax                              ; al = number of sectors to read
    
    mov ah, 02h                         ; Read Sectors call
    mov di, 3                           ; retry count

    .retry:
        pusha                           ; save registers
        stc                             ; set flag
        int 13h                         ; interrupt call  - Low Level Disk Services
        jnc .done

        ; failed
        popa
        call disk_reset

        dec di                          ; retry count - 1
        test di, di                     ; inst 0
        jnz .retry                      ; jump back to retry

    .fail:
        jmp floppy_error

    .done:
        popa

        pop di
        pop dx
        pop cx
        pop bx
        pop ax                             ; restore registers
        ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello:          db 'Hello, World!', ENDL, 0
msg_read_failed:   db 'Failed to read from disk', ENDL, 0

times 510-($-$$) db 0   ; repeat N times, caculate the rest of bytes left to 510 | $ represent the current address loc | $$ represent the start address loc | db filll bytes with 0
dw 0AA55h               ; define 4 bytes value