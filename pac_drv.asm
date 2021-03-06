[BITS 16]
[ORG 0x0100]

[SECTION .text]

%define SOCKET_NUMBER 0x20 ; 0x2000 reversed into big endian. This socket handles get/recv packets.
%define BROADCAST_SOCKET_NUMBER 0x0120 ; 0x2001 reversed into big endian. This socket handles all pipe open/close messages.

Start:
    mov dx, startMsg ; Show start message.
    mov ah, 9
    int 21h

    call setConnectionNumber ; load connection number from cmomand line. 1-9

    call ipxinit              ; load IPX
    cmp al, 0
    mov dx, ipxErrorMsg
    jz _ipxInitFailed

    ; open both sockets.
    mov dx, SOCKET_NUMBER
    call ipxopensocket
    cmp al, 0
    mov dx, ipxOpenErrMsg
    jnz _ipxInitFailed

    mov dx, BROADCAST_SOCKET_NUMBER
    call ipxopensocket
    cmp al, 0
    mov dx, ipxOpenErrMsg
    jnz _ipxInitFailed

    lea ax, [netwareESR]             ; pass in the ESR handler offset to initialise the ECB.
                                     ; The segment is CS so we don't send it
    call ipxInitBroadcastListenerECB
    lea si, [recvBroadcastECB]
    mov ax, cs
    mov es, ax
    call ipxlistenforpacket          ; listen for broadcast messages on 0x2001 and handle them with netwareESR:
    cmp al, 0
    mov dx, ipxListenErrMsg
    jnz _ipxInitFailed

    ; Load two direct message listener ECBs

    lea ax, [receiveMsgESR]
    lea di, [recvListeners]
    push cs
    pop es

    call ipxInitListenerECB
    mov si, di
    call ipxlistenforpacket


    add di, IPXLISTENER.size
    lea ax, [receiveMsgESR]
    call ipxInitListenerECB
    mov si, di
    call ipxlistenforpacket

    ; Get current interrupt handler for INT 21h
    ; Store it in v21HandlerSegment:v21HandlerOffset
    mov ax, 3521h                ; DOS function 35h GET INTERRUPT VECTOR for interrupt 21h
    int 21h                      ; Call DOS  (Current interrupt handler returned in ES:BX)

    mov WORD [v21HandlerSegment],ES
    mov WORD [v21HandlerOffset],BX

    ; Write new interrupt handler for INT 21h
    mov AX,2521h                ; DOS function 25h SET INTERRUPT VECTOR for interrupt 21h
    mov DX,TSRStart             ; Load DX with the offset address of the start of this TSR program
    ;   No need to set DS as DS == CS for COM files
    int 21h

    ; Exit via TSR routine.
    mov AX,3100h                ; DOS function TSR, return code 00h
    mov DX,00FFh                ; TODO work out final page size to reserve for the TSR logic.
    int 21h                     ; Call our own TSR program first, then call DOS

    ;dx should contain offset to error message string.
_ipxInitFailed:
    mov ah, 9
    int 21h

    mov ax, 0x4c00
    int 21h                     ; Exit to dos.

setConnectionNumber: ;load our connection number from command line.
    push ax
    mov al, byte [ds:0x82] ; this should be the location of the first character on the commandline contained in the PSP.
    sub al, 0x30 ; convert ascii char to connection number.
                 ; TODO this needs more work. There is no input checking and it only accepts 1-9 connection numbers.
    mov byte [cs:netWareConnectionNumber], al ; set connection number.
    pop ax
    ret

;;;;;;;; TSR Handler routine. ;;;;;;;;;;;;;;
TSRStart:
    pushf
    cmp ah, 0xdc
    jnz .checkForNetware
    call int21dcHandler    ; call int 21 dc. get connection number.
    popf
    iret

.checkForNetware:
    cmp ah, 0xe1
    jz int21e1Handler     ; handle netware interrupt calls.

existingHandler:
    popf
    push WORD [cs:v21HandlerSegment]       ; Push the far address of the original 
    push WORD [cs:v21HandlerOffset]        ;   INT 21h handler onto the stack
    retf                                ; Jump to it!

int21dcHandler:
    call ipxrelinquishcontrol
    mov al, [cs:netWareConnectionNumber]   ; Handle INT 21 DC. Netware: Get connection number.
    ret

%include 'netware.asm'
%include 'ipx.asm'

[SECTION .data]
startMsg db 'PacWars IPX driver.', 0x0d, 0x0a, '$'
ipxErrorMsg  db 'Error connecting to ipx', 0x0d, 0x0a, '$'
ipxOpenErrMsg db 'Error opening socket', 0x0d, 0x0a, '$'
ipxListenErrMsg db 'Error listening to socket', 0x0d, 0x0a, '$'
netWareConnectionNumber  db 0
v21HandlerSegment dw 0000h
v21HandlerOffset  dw 0000h
_ipxentry         dd 00000000h

sendECB times ECB.size db 0
sendHeader times IPXHEADER.size db 0
sendBuffer times 128 db 0
sendPacketLength db 0

recvListeners times IPXLISTENER.size * 2 db 0

recvBuffers times RECEIVE_BUFFER.size * NUMBER_OF_RECEIVE_BUFFERS db 0

recvBufferNextRead db 0 ; pointer to the next buffer to read data from.

recvBroadcastECB times ECB.size db 0
recvBroadcastHeader times IPXHEADER.size db 0
recvBroadcastBuffer times 128 db 0

netwarePipes times 100 * NETWARE_PIPE.size db 0
