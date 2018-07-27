[BITS 16]
[ORG 0x0100]

[SECTION .text]

Start:
    mov dx, startMsg ; Show start message.
    mov ah, 9
    int 21h

    mov byte [netWareConnectionNumber], 2

    call ipxinit
    cmp al, 0
    mov dx, ipxErrorMsg
    jz _ipxInitFailed

    call ipxopensocket
    cmp al, 0
    mov dx, ipxOpenErrMsg
    jnz _ipxInitFailed

    call ipxInitListenerECB

    lea si, [recvECB]
    mov ax, cs
    mov es, ax
    call ipxlistenforpacket
    cmp al, 0
    mov dx, ipxListenErrMsg
    jnz _ipxInitFailed

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

;;;;;;;; TSR Handler routine. ;;;;;;;;;;;;;;
TSRStart:
    pushf
    cmp ah, 0xdc
    jnz existingHandler
    call int21dcHandler
    popf
    iret

existingHandler:
    popf
    push WORD [cs:v21HandlerSegment]       ; Push the far address of the original 
    push WORD [cs:v21HandlerOffset]        ;   INT 21h handler onto the stack
    retf                                ; Jump to it!

int21dcHandler:
    call ipxrelinquishcontrol
    mov al, [cs:netWareConnectionNumber]   ; Handle INT 21 DC. Netware: Get connection number.
    ret

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

recvECB times ECB.size db 0
recvHeader times IPXHEADER.size db 0
recvBuffer times 128 db 0
