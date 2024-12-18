org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 Header
;

jmp short start
nop

bdb_oem db 'MSWIN4.1'
bdb_bytes_per_sector dw 512
bdb_sectors_per_cluster db 1
bdb_reserved_sectors dw 1
bdb_fat_count db 2
bdb_dir_entries dw 0E0h
bdb_total_sectors dw 2880
bdb_media_descriptor_type db 0F0h
bdb_sectors_per_fat dw 9
bdb_sectors_per_track dw 18
bdb_heads dw 2
bdb_hidden_sectors dd 0
bdb_total_sectors_large dd 0

; Extended boot record
ebr_drive_number db 0
                 db 0 ;reserved
ebr_signature db 29h
ebr_volume_id db 12h,34h,56h,78h
ebr_volume_label db 'ICEBREAKER '
ebr_system_id db 'FAT12   '

start:
    jmp main

puts:
    push si
    push ax

.loop:
    lodsb
    or al,al
    jz done
    mov ah,0x0E
    mov bh,0
    int 0x10
    jmp .loop

done:
    pop ax
    pop si
    ret

main:
    ;Setup data segment
    mov ax,0
    mov ds,ax
    mov es,ax

    mov ss,ax
    mov sp,0x7C00

    ;read from disk
    mov [ebr_drive_number],dl
    mov ax,1 ;LBA=1
    mov cl,1 ;1 read 1 sector
    mov bx,0x7E00 ;bootloader data padding
    call disk_read

    mov si,msg_hello
    call puts

    cli
    hlt

;
;Error handlers
;
read_error:
    mov si,msg_read_failed
    call puts
    jmp wait_and_reboot

wait_and_reboot:
    mov ah,0
    int 16h
    jmp 0FFFFh:0

.halt:
    cli
    hlt

;
; Disk routines
;
lba_to_chs:
    push ax
    push dx
    xor dx,dx                        ;dx = 0
    div word [bdb_sectors_per_track] ;ax=LBA/SectorPerTrack
    inc dx
    mov cx,dx                        ;cx=Sector

    xor dx,dx
    div word [bdb_heads]
    mov dh,dl                        ;dh=Head
    mov ch,al                        ;ch=Cylinder(lower 8-bit)
    shl ah,6
    or cl,ah                         ;upper 2 bit

    pop ax
    mov dl,al                        ;restore DL
    pop ax
    ret

disk_read:
    push ax                          ;save registers
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax                           ;AL = num of sectors to read

    mov ah,02h                       ;read sector
    mov di,3                         ;retry counter

.retry:
    pusha
    stc ;carry flag
    int 13h
    jnc .done

    ;failed case
    popa
    call disk_reset
    dec di
    test di,di
    jnz .retry

.fail:
    jmp read_error

.done:
    popa

    pop di ;restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_reset:
    pusha
    mov ah,0
    stc
    int 13h
    jc read_error
    popa
    ret

msg_hello: db 'Hello bootloader!', ENDL,0
msg_read_failed: db 'Failed to read disk', ENDL,0

times 510-($-$$) db 0
dw 0xAA55