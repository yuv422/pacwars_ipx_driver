[BITS 16]
[ORG 0x0100]

[SECTION .text]

Start:
    lea dx, [startMsg] ; print start message
    mov ah, 9
    int 21h

    mov ax, cs
    mov ds, ax
    lea si, [sendCmd] ; ds:si = &sendCmd

    mov es, ax
    lea di, [replyBuffer] ; es:di = &replyBuffer

    mov al, byte [ds:0x82] ; this should be the location of the first character on the commandline contained in the PSP.
    sub al, 0x30 ; convert ascii char to connection number.
    mov byte [cs:connectionList], al ; write connection number argument into send command.

    mov ah, 0xe1 ; netware interrupt

    int 0x21 ; call the interrupt handler
    mov al, byte [cs:replyBuffer + 2] ; get the number of connections. This should equal the number sent.
    cmp al, 2
    jnz .exitToDos

    lea dx, [okCommand] ; print ok message
    mov ah, 9
    int 21h

.exitToDos:
    mov ax, 0x4c00
    int 21h                     ; Exit to dos.


[SECTION .data]
startMsg db 'Netware send packet.', 0x0d, 0x0a, '$'
okCommand db 'Ok it worked.', 0x0d, 0x0a, '$'
sendCmd:
 dw 4 ; length
 db 4 ; subFunction
 db 2 ; number Of connections to send to
connectionList:
 db 6, 7 ; connection list
 db 6 ; number of bytes to send
 db 0xc, 0, 0xf, 0xf, 0xe, 0xe ; payload.

replyBuffer times 0x67 db 0

