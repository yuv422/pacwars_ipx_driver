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

struc IPX_COMMAND_HEADER
    .command resb 1
    .length resb 1
    .data:
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

;;;;;;;;;;;;;;;; Netware - Open connection pipes ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
    mov word [es:di], bx ; write the size of the reply buffer. number of connections + 1

    mov byte [es:di + 2], cl ; write the number of connections to the reply buffer.
    mov ch, 0
    add si, 4 ; advance si to point to connection number data

.loopStart:              ; loop over all requested connections
    cmp ch, cl
    jge .loopEnd
    ;TODO loop body

    mov al, byte [ds:si] ; load connection number.
    lea bx, [sendBuffer]
    add bx, IPX_COMMAND_HEADER.size       ; skip over ipx command header bytes
    push ax
    mov al, ch
    mov ah, 0
    add bx, ax           ; bx = &sendBuffer[2 + ch]
    pop ax
    mov byte [cs:bx], al ; write connection number to ipx send buffer.

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
    add al, IPX_COMMAND_HEADER.size
    mov byte [cs:sendPacketLength], al ; size of ipx packet. 2 header bytes + number of connection requests.

    lea bx, [sendBuffer]              ; write ipx send header details
    mov byte [cs:bx + IPX_COMMAND_HEADER.command], OPEN_PIPE_CMD   ; write command byte
    mov byte [cs:bx + IPX_COMMAND_HEADER.length], cl               ; write number of connections

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    call ipxsendbroadcastmessage ; send ipx message.
    mov al, 0 ; success.
    jmp _netwareExitInterrupt

;;;;;;;;;;;;;;;; Netware - Close pipes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

closePipeHandler:
    pop ax
    call ipxsendbroadcastmessage
    jmp _netwareExitInterrupt


;;;;;;;;;;;;;;;; Netware - Check pipe status ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

checkPipeStatusHandler:
    pop ax
    ; check pipe status for connection array based on values in
    ; number of pipe requests in byte at ds:si + 3
    ; connection numbers stored at ds:si + 4
    push bx
    push cx
    push dx
    push si
    push di
    mov cl, byte [ds:si + 3] ; number of connections to check
    mov bl, cl
    mov bh, 0
    inc bx
    mov word [es:di], bx ; write the size of the reply buffer. number of connections + 1

    mov byte [es:di + 2], cl ; write the number of connections to the reply buffer.
    mov ch, 0
    add si, 4 ; advance si to point to connection number data

.loopStart:              ; loop over all pipe connections to check
    cmp ch, cl
    jge .loopEnd

    mov al, byte [ds:si] ; load connection number.

    cmp al, 0      ; if(connectionNumber == 0) continue;
    jz .continue
    dec al    ; connectionNumber--
    mov dl, NETWARE_PIPE.size
    mul dl   ; ax = al * dl
    lea bx, [netwarePipes]
    add bx, ax   ; bx = netwarePipes[connectionNumber - 1];

    mov al, byte [cs:bx + NETWARE_PIPE.pipeStatus] ; get existing pipe status for connection

    mov ah, 0xfe ; pipe connection incomplete status
    cmp al, 0 ; check if pipe is closed
    jnz .checkForOpen
    mov ah, 0xff ; closed status
    jmp .writeStatus
.checkForOpen:
    cmp al, 3 ; check if pipe connected
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
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov al, 0 ; success.
    jmp _netwareExitInterrupt

_netwareExitInterrupt:
    popf
    iret

;;;;;;;;;; Netware broadcast listener ESR ;;;;;;;;;;;;;;;;;;;
; call back used to process broadcast messages open/close pipe, connection established.

netwareESR:
    ; TODO handle send/close/conn established messages here.
    mov al, byte [cs:recvBroadcastBuffer + IPX_COMMAND_HEADER.command] ; read the command from the incoming message
    cmp al, OPEN_PIPE_CMD
    jz .openPipeCommand
    cmp al, CLOSE_PIPE_CMD
    jz .closePipeCommand
    jmp .exitESR

.openPipeCommand:
    call doesCommandTargetMe ; check if this command is targeting us.
    cmp al, 0
    jz .exitESR
    ; TODO set remote connection open in netwarePipes and send connection established message.
    jmp .exitESR

.closePipeCommand:
    call doesCommandTargetMe ; check if this command is targeting us.
    cmp al, 0
    jz .exitESR
    ; TODO set remote connection to closed in netwarePipes
    jmp .exitESR

.exitESR:
    ; TODO re-listen to ECB here.
    retf

; returns 1 in AL if our connection number is contained in the connection list. 0 is returned otherwise.
; AH is trashed.
doesCommandTargetMe:
    push bx
    push cx
    lea bx, [recvBroadcastBuffer]
    mov cl, byte [cs:recvBroadcastBuffer + IPX_COMMAND_HEADER.length] ; get number of connections in the command
    mov ch, 0 ; loop counter
.loopStart:
    cmp ch, cl
    jge .loopEnd
    mov ah, byte [cs:bx + IPX_COMMAND_HEADER.data] ; get the connection number
    mov al, byte [cs:netWareConnectionNumber]
    cmp ah, al
    jz .foundEntry ; if current connection number == our connection number then return true.
    inc bx
    inc ch
    jmp .loopStart
.loopEnd:
    mov al, 0   ; we didn't find out connection number in the list
    jmp .return
.foundEntry:
    mov al, 1   ; success we founbd our connection number.
.return:
    pop cx
    pop bx
    ret