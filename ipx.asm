;;;;;;;;; IPX code ;;;;;;;;

struc ECB
  .LinkAddressOff resw 1
  .LinkAddressSeg resw 1
  .ESRAddressOff  resw 1
  .ESRAddressSeg  resw 1
  .InUse          resb 1
  .CompCode       resb 1
  .SockNum        resw 1
  .IPXWorkSpc     resd 1
  .DrvWorkSpc     resb 12
  .ImmAdd         resb 6
  .FragCount      resw 1
  .FragAddOfs     resw 1
  .FragAddSeg     resw 1
  .FragSize       resw 1
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
    mov dx, 0x4001  ; socket number ok
    mov bx,0000h
    call far [_ipxentry]
    mov ah,00h
    ret
