struc NETWAREHEADER
    .length   resw 1
    .subFunction resb 1
.size:
endstruc

struc NETWARE_PIPE
    .pipeStatus resb 1     ; 0 = no connection attempts
                           ; 1 = connection request sent
                           ; 2 = connection request received
                           ; 3 = connected. :-)
    .remoteAddress resb 6  ; address of the remote computer.
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
    pop ax
    jmp _netwareExitInterrupt

getPacketHandler:
    pop ax
    jmp _netwareExitInterrupt

openPipeHandler:
    pop ax
    ; set requested pipe array based on values in
    ; number of open requests in byte at ds:si + 3
    ; connection numbers stored at ds:si + 4
    push bx
    push cx
    push dx
    push si
    push di
    mov cl, byte [ds:si + 3] ; number of connections to open
    mov bl, cl
    mov bh, 0
    inc bx
    mov word [es:di], bx ; write the size of the reply buffer. number of connectios + 1

    mov byte [es:di + 2], cl ; write the number of connections to the reply buffer.
    mov ch, 0
    add si, 3 ; advance si to point to connection number data

.loopStart:              ; loop over all requested connections
    cmp ch, cl
    jge .loopEnd
    ;TODO loop body

    mov al, byte [ds:si] ; load connection number.
    cmp al, 0      ; if(connectionNumber == 0) continue;
    jz .continue
    dec al    ; connectionNumber--
    mov dl, NETWARE_PIPE.size
    mul dl   ; ax = al * dl
    lea bx, [netwarePipes]
    add bx, ax   ; bx = netwarePipes[connectionNumber - 1];

    mov al, byte [cs:bx + NETWARE_PIPE.pipeStatus] ; get existing pipe status for connection
    or al, 1
    mov byte [cs:bx + NETWARE_PIPE.pipeStatus], al ; mark that we want to open this pipe.

    mov ah, 0xfe ; pipe connection incomplete status
    cmp al, 3 ; jump if pipe is not connected
    jnz .writeStatus
    mov ah, 0 ; successfully connected pipe status
.writeStatus:
    mov byte [es:di + 1], ah
.continue:
    inc di
    inc si ; increment si to point to next connection number.
    inc ch
    jmp .loopStart
.loopEnd:
    mov al, cl
    add al, 2
    mov byte [cs:sendPacketLength], al ; size of ipx packet. 2 header bytes + number of connection requests.
    ;TODO write out ipx packet.
    ; OPEN_PIPE_CMD
    ; number of connections
    ; connection list
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    call ipxsendbroadcastmessage ; send ipx message.
    mov al, 0 ; success.
    jmp _netwareExitInterrupt

closePipeHandler:
    pop ax
    call ipxsendbroadcastmessage
    jmp _netwareExitInterrupt

checkPipeStatusHandler:
    pop ax
    jmp _netwareExitInterrupt

_netwareExitInterrupt:
    popf
    iret
