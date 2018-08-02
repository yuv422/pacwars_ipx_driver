struc NETWAREHEADER
    .length   resw 1
    .subFunction resb 1
.size:
endstruc

%define SEND_PACKET_CMD 1
%define OPEN_PIPE_CMD 2
%define CLOSE_PIPE_CMD 3
%define CONN_ESTABLISHED_CMD 3

int21e1Handler:
    ;TODO dispatch to other functions based on sub function code.
    push ax
    mov al, byte [ds:si + NETWAREHEADER.subFunction]
    cmp al, 4
    jnz .checkSubfunction5
    jmp sendPacketHandler

.checkSubfunction5:
    cmp al, 5
    jnz .checkSubfunction6
    jmp getPacketHandler

.checkSubfunction6:
    cmp al, 6
    jnz .checkSubfunction7
    jmp openPipeHandler

.checkSubfunction7:
    cmp al, 7
    jnz .checkSubfunction8
    jmp closePipeHandler

.checkSubfunction8:
    cmp al, 8
    jz checkPipeStatusHandler
    ; fall through to existing handler.

.existingHandler:
    pop ax
    jmp existingHandler ; call the original interrupt handler here.


sendPacketHandler:
    jmp _netwareExitInterrupt

getPacketHandler:
    jmp _netwareExitInterrupt

openPipeHandler:
    ; set requested pipe array based on values in
    ; number of open requests in byte at ds:si + 3
    ; connection numbers stored at ds:si + 4
    call ipxsendbroadcastmessage
    jmp _netwareExitInterrupt

closePipeHandler:
    call ipxsendbroadcastmessage
    jmp _netwareExitInterrupt

checkPipeStatusHandler:
    jmp _netwareExitInterrupt

_netwareExitInterrupt:
    pop ax
    popf
    iret
