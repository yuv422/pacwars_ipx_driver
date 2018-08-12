[BITS 16]
[ORG 0x0100]

[SECTION .text]

Start:
    lea dx, [startMsg] ; print start message
    mov ah, 9
    int 21h

    mov ax, cs
    mov ds, ax
    lea si, [recvCmd] ; ds:si = &sendCmd

    mov es, ax
    lea di, [replyBuffer] ; es:di = &replyBuffer

    mov ah, 0xe1 ; netware interrupt

    int 0x21 ; call the interrupt handler
    cmp al, 0
    jnz .exitToDos

    lea dx, [okCommand] ; print ok message
    mov ah, 9
    int 21h

.exitToDos:
    mov ax, 0x4c00
    int 21h                     ; Exit to dos.


[SECTION .data]
startMsg db 'Netware recv packet.', 0x0d, 0x0a, '$'
okCommand db 'Ok it worked.', 0x0d, 0x0a, '$'
recvCmd:
 dw 1 ; length
 db 5 ; subFunction

replyBuffer times 0x82 db 0

