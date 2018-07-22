;;;;;;;;; IPX code ;;;;;;;;

%define SOCKET_NUMBER 0x4001

struc ECB
    .linkAddressOff resw 1
    .linkAddressSeg resw 1
    .esrAddressOff  resw 1
    .esrAddressSeg  resw 1
    .inUse          resb 1
    .compCode       resb 1
    .socket         resw 1
    .ipxWorkSpc     resw 1
    .drvWorkSpc     resb 12
    .immAdd         resb 6
    .fragCount      resw 1
    .fragHeaderOff  resw 1
    .fragHeaderSeg  resw 1
    .fragHeaderSize resw 1
    .fragBufOff     resw 1
    .fragBufSeg     resw 1
    .fragBufSize    resw 1
.size:
endstruc

struc IPXADDRESS
    .NetAddr  resb 4
    .NodeAddr resb 6
    .Socket   resw 1
.size:
endstruc

struc IPXHEADER
    .checksum resw 1
    .length   resw 1
    .tc       resb 1
    .type     resb 1
    .dest     resb IPXADDRESS.size
    .source   resb IPXADDRESS.size
.size:
endstruc

; init IPX, load entry pointer into _ipxentry
; return al = 1 on success, ah = 0 on failure.
ipxinit:
    push di
    push es
    push dx
    mov dl, 0
    mov ax, 0x7A00
    int 0x2F
    cmp al, 0xFF
    jnz _ipxinit0
    mov word [_ipxentry+0],di
    mov word [_ipxentry+2],es
    mov dl, 1
_ipxinit0:
    mov al, dl
    pop dx
    pop es
    pop di
    ret

; open ipx socket.
; status returned in al. 0 == success, 0xff == socket already open, 0xfe == socket table full.
ipxopensocket:
    mov al, 1       ; leave socket open until close called.
    mov dx, SOCKET_NUMBER  ; socket number ok
    mov bx,0000h
    call far [_ipxentry]
    mov ah,00h
    ret
