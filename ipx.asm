;;;;;;;;; IPX code ;;;;;;;;


struc ECB
    .linkAddressOff resw 1
    .linkAddressSeg resw 1
    .esrAddressOff  resw 1
    .esrAddressSeg  resw 1
    .inUse          resb 1
    .compCode       resb 1
    .socket         resw 1
    .ipxWorkSpc     resd 1
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

struc IPXLISTENER
    .ecb resb ECB.size
    .header resb IPXHEADER.size
    .buffer resb 128
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
; socket number passed in DX
; status returned in al. 0 == success, 0xff == socket already open, 0xfe == socket table full.
ipxopensocket:
    push bx
    mov al, 1       ; leave socket open until close called.
    mov bx,0000h
    ;socket number is in DX
    call far [cs:_ipxentry]
    mov ah,00h
    pop bx
    ret

; listen for IPX packet.
; Need to pass ECB address in es:si
; returned status in al 0 on success 0xff on error
ipxlistenforpacket:
    push bx
    mov bx,0004h
    call far [cs:_ipxentry]
    mov ah,00h
    pop bx
    ret

; Relinquish control to the ipx driver.
ipxrelinquishcontrol:
    push bx
    mov bx,000Ah
    call far [cs:_ipxentry]
    pop bx
    ret

; passing in the ESR offset in AX.
; passing in ECB in CS:DI
ipxInitListenerECB:
    push ax
    mov word [cs:di + IPXLISTENER.ecb + ECB.esrAddressOff], ax
    mov word [cs:di + IPXLISTENER.ecb + ECB.esrAddressSeg], cs
    mov word [cs:di + IPXLISTENER.ecb + ECB.socket], SOCKET_NUMBER
    mov byte [cs:di + IPXLISTENER.ecb + ECB.fragCount], 2
    mov ax, di
    add ax, IPXLISTENER.header
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragHeaderOff], ax
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragHeaderSeg], cs
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragHeaderSize], IPXHEADER.size
    mov ax, di
    add ax, IPXLISTENER.buffer
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragBufOff], ax
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragBufSeg], cs
    mov word [cs:di + IPXLISTENER.ecb + ECB.fragBufSize], 128
    pop ax
    ret

; passing in the ESR offset in AX.
ipxInitBroadcastListenerECB:
    push bx
    push ax
    lea bx, [recvBroadcastECB]
    mov word [cs:bx + ECB.esrAddressOff], ax
    mov word [cs:bx + ECB.esrAddressSeg], cs
    mov word [cs:bx + ECB.socket], BROADCAST_SOCKET_NUMBER
    mov byte [cs:bx + ECB.fragCount], 2
    lea ax, [recvBroadcastHeader]
    mov word [cs:bx + ECB.fragHeaderOff], ax
    mov word [cs:bx + ECB.fragHeaderSeg], cs
    mov word [cs:bx + ECB.fragHeaderSize], IPXHEADER.size
    lea ax, [recvBroadcastBuffer]
    mov word [cs:bx + ECB.fragBufOff], ax
    mov word [cs:bx + ECB.fragBufSeg], cs
    mov word [cs:bx + ECB.fragBufSize], 128
    pop ax
    pop bx
    ret

ipxInitBroadcastECB:
    push bx
    push ax
    lea bx, [sendECB]
    mov word [cs:bx + ECB.esrAddressOff], 0
    mov word [cs:bx + ECB.esrAddressSeg], 0
    mov word [cs:bx + ECB.socket], BROADCAST_SOCKET_NUMBER

    mov word [cs:bx + ECB.immAdd], 0xffff
    mov word [cs:bx + ECB.immAdd + 2], 0xffff
    mov word [cs:bx + ECB.immAdd + 4], 0xffff

    mov byte [cs:bx + ECB.fragCount], 2
    lea ax, [sendHeader]
    mov word [cs:bx + ECB.fragHeaderOff], ax
    mov word [cs:bx + ECB.fragHeaderSeg], cs
    mov word [cs:bx + ECB.fragHeaderSize], IPXHEADER.size
    lea ax, [sendBuffer]
    mov word [cs:bx + ECB.fragBufOff], ax
    mov word [cs:bx + ECB.fragBufSeg], cs
    mov ax, word [cs:sendPacketLength]
    mov word [cs:bx + ECB.fragBufSize], ax

    lea bx, [sendHeader]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NetAddr], 0
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NetAddr + 2], 0
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr], 0xffff
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr + 2], 0xffff
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr + 4], 0xffff
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.Socket], BROADCAST_SOCKET_NUMBER
    mov word [cs:bx + IPXHEADER.type], 4

    pop ax
    pop bx
    ret

; destination ipx address in CS:DI
ipxInitDirectSendECB:
    push bx
    push ax
    lea bx, [sendECB]
    mov word [cs:bx + ECB.esrAddressOff], 0
    mov word [cs:bx + ECB.esrAddressSeg], 0
    mov word [cs:bx + ECB.socket], SOCKET_NUMBER

    mov ax, word [cs:di + IPXADDRESS.NodeAddr]
    mov word [cs:bx + ECB.immAdd], ax
    mov ax, word [cs:di + IPXADDRESS.NodeAddr + 2]
    mov word [cs:bx + ECB.immAdd + 2], ax
    mov ax, word [cs:di + IPXADDRESS.NodeAddr + 4]
    mov word [cs:bx + ECB.immAdd + 4], ax

    mov byte [cs:bx + ECB.fragCount], 2
    lea ax, [sendHeader]
    mov word [cs:bx + ECB.fragHeaderOff], ax
    mov word [cs:bx + ECB.fragHeaderSeg], cs
    mov word [cs:bx + ECB.fragHeaderSize], IPXHEADER.size
    lea ax, [sendBuffer]
    mov word [cs:bx + ECB.fragBufOff], ax
    mov word [cs:bx + ECB.fragBufSeg], cs
    mov ax, word [cs:sendPacketLength]
    mov word [cs:bx + ECB.fragBufSize], ax

    lea bx, [sendHeader]

    mov ax, word [cs:di + IPXADDRESS.NetAddr]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NetAddr], ax
    mov ax, word [cs:di + IPXADDRESS.NetAddr + 2]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NetAddr + 2], ax

    mov ax, word [cs:di + IPXADDRESS.NodeAddr]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr], ax
    mov ax, word [cs:di + IPXADDRESS.NodeAddr + 2]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr + 2], ax
    mov ax, word [cs:di + IPXADDRESS.NodeAddr + 4]
    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.NodeAddr + 4], ax

    mov word [cs:bx + IPXHEADER.dest + IPXADDRESS.Socket], SOCKET_NUMBER
    mov word [cs:bx + IPXHEADER.type], 4

    pop ax
    pop bx
    ret

ipxsendpacket:
    push es
    push si
    push bx
    mov ax, cs
    mov es, ax
    lea si, [sendECB]            ; load sendECB into es:si

    mov bx, 3                    ;IPX send packet
    call far [cs:_ipxentry]

    pop bx
    pop si
    pop es
    ret

; send a message to all listeners on SOCKET_NUMBER
ipxsendbroadcastmessage:
    call ipxInitBroadcastECB
    call ipxsendpacket
    ret
