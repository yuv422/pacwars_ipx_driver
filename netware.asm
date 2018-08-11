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
    .ipxAddress:
    .remoteNetAddr  resb 4 ; address of the remote computer.
    .remoteNodeAddr resb 6

.size:
endstruc

struc IPX_COMMAND_HEADER
    .command resb 1
    .connectionNumber resb 1
    .length resb 1
    .data:
.size:
endstruc

struc NETWARE_SEND
    .length resw 1
    .subFunction resb 1
    .numConnections resb 1
    .connectionList:
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
    jz near checkPipeStatusHandler
    ; fall through to existing handler.

.existingHandler:
    pop ax
    jmp existingHandler ; call the original interrupt handler here.


sendPacketHandler:
    pop ax
    ; request buffer in DS:SI
    ; reply buffer in ES:DI
    ; write message to open pipes
    push ax
    push bx
    push cx
    push dx
    mov al, byte [si + NETWARE_SEND.numConnections]
    mov cl, al ; number of connections to send to.
    mov byte [es:di + 2], al ; write the number of connections to reply buffer.
    inc al
    mov ah, 0
    mov word [es:di], ax ; write length of reply data. num connections + 1

    mov dx, di
    add dx, 3      ; dx points to start of reply buffer connection status list

    mov ch, 0
    mov bx, si
    add bx, NETWARE_SEND.connectionList ; bx pointing to start of connection list.
.loopStart:
    cmp ch, cl    ; while (ch < numConnections)
    jge .loopEnd

    mov al, byte [bx] ; get next connection number from list
    call getConnectionStatus ; status returned in AH

    push bx
    mov bx, dx
    mov byte [es:bx], ah   ; write connection status out to reply buffer.
    pop bx
    cmp ah, 0
    jnz .skipSend          ; only send if connected. eg connections status == 0
    call sendPacketToPipe
.skipSend:
    inc dx
    inc bx
    inc ch
    jmp .loopStart
.loopEnd:

    pop dx
    pop cx
    pop bx
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
    mov byte [es:di + 3], ah
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
    mov al, byte [cs:netWareConnectionNumber]
    mov byte [cs:bx + IPX_COMMAND_HEADER.connectionNumber], al     ; write our connection number to msg.
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
    mov byte [es:di + 3], ah
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
    mov al, byte [cs:recvBroadcastBuffer + IPX_COMMAND_HEADER.connectionNumber] ; get the connection number of the sender.
    dec al
    lea bx, [netwarePipes]
    mov dl, NETWARE_PIPE.size
    mul dl                     ; ax = (SenderConnectionNumber - 1) * NETWARE_PIPE.size
    add bx, ax
    mov al, byte [cs:bx + NETWARE_PIPE.pipeStatus]     ; get pipe status for the sending connection number
    or al, 2 ; set the sender requested open flag in status
    mov byte [cs:bx + NETWARE_PIPE.pipeStatus], al

    call writeSenderHeaderToPipeList ; write sender address to pipe record currently pointed to by CS:BX
    cmp al, 3 ; check if we're connected now.
    jnz .exitESR
    ; We're connected here.
    ; TODO Send connection established message back to sender if we have previously attempted to connect.

    jmp .exitESR

.closePipeCommand:
    call doesCommandTargetMe ; check if this command is targeting us.
    cmp al, 0
    jz .exitESR
    ; TODO set remote connection to closed in netwarePipes
    jmp .exitESR

.exitESR:
    ; setup ECB to listen for another packet.
    lea si, [recvBroadcastECB]
    mov ax, cs
    mov es, ax
    call ipxlistenforpacket          ; listen for broadcast messages on 0x2001 and handle them with netwareESR:

    retf

;;; write the sender address to the netwarePipe record.
; netware pipe record address passed in BX
writeSenderHeaderToPipeList:
    ; copy from ECB.header.source to cs:BX + remoteNetAddr. 10 bytes
    push ax
    mov ax, word [cs:recvBroadcastHeader + IPXHEADER.source]
    mov word [cs:bx + NETWARE_PIPE.remoteNetAddr], ax
    mov ax, word [cs:recvBroadcastHeader + IPXHEADER.source + 2]
    mov word [cs:bx + NETWARE_PIPE.remoteNetAddr + 2], ax
    mov ax, word [cs:recvBroadcastHeader + IPXHEADER.source + 4]
    mov word [cs:bx + NETWARE_PIPE.remoteNetAddr + 4], ax
    mov ax, word [cs:recvBroadcastHeader + IPXHEADER.source + 6]
    mov word [cs:bx + NETWARE_PIPE.remoteNetAddr + 6], ax
    mov ax, word [cs:recvBroadcastHeader + IPXHEADER.source + 8]
    mov word [cs:bx + NETWARE_PIPE.remoteNetAddr + 8], ax
    pop ax
    ret

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
    mov al, 1   ; success we found our connection number.
.return:
    pop cx
    pop bx
    ret

; gets the current connection status for a given connection number
; connection number passed in with AL
; status returned in AH
; 0xff not connected
; 0xfe partially connected
; 0 connected
getConnectionStatus:
    push bx
    push dx

    mov ah, 0xff   ; not connected.
    cmp al, 0
    jz .return

    push ax
    dec al
    lea bx, [netwarePipes]
    mov dl, NETWARE_PIPE.size
    mul dl                     ; ax = (ConnectionNumber - 1) * NETWARE_PIPE.size
    add bx, ax
    pop ax ; restore al back to original connection number.

    mov dl, byte [cs:bx + NETWARE_PIPE.pipeStatus]     ; get pipe status for the sending connection number

    ; check the connection status
    mov ah, 0xfe ; incomplete connection.
    cmp dl, 0
    jnz .checkForConnected
    mov ah, 0xff ; not connected
    jmp .return
.checkForConnected:
    cmp dl, 3
    jnz .return
    mov ah, 0 ; connected status
.return:
    pop dx
    pop bx
    ret

; send the netware packet to a given pipe.
; connection number passed in through AL
; netware request in DS:SI
sendPacketToPipe:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov dl, al ; dl = connectionNumber to send to.


    mov al, byte [si + NETWARE_SEND.numConnections] ; number of connections to send to
    add si, NETWARE_SEND.connectionList
    mov ah, 0
    add si, ax ; advance si pointer to the start of the packet data.
               ; NETWARE_SEND.connectionList + number of connections

    mov al, [si] ; number of bytes to send
    inc si       ; si points to packet data.

    mov cx, ax   ; cx = number of bytes to send.

    inc al
    mov byte [cs:sendPacketLength], al ; store total packet length. netware packet + 1 byte for connection number.

    mov ax, cs
    mov es, ax           ; es=cs
    lea di, [sendBuffer] ; es:di = &sendBuffer

    mov al, byte [cs:netWareConnectionNumber]
    mov byte [es:di], al   ; write our connection number to start of sendBuffer.
    inc di

    ; write packet to sendBuffer
    ;cx number of bytes to copy.
    ;si netware packet data
    ;di &sendBuffer[1]
    rep movsb   ; copy bytes.

    ; get netwarePipe address for destConnectionNumber.

    lea di, [netwarePipes]
    dec dl  ; destConnectionNumber - 1
    mov al, NETWARE_PIPE.size
    mul dl  ; ax = (destConnectionNumber - 1) * netwarePipes.size
    add di, ax ; di now pointing at netwarePipes[destConnectionNumber-1]
    add di, NETWARE_PIPE.ipxAddress ; di = &netwarePipes[destConnectionNumber-1].remoteNetAddr

    ; send packet

    call ipxInitDirectSendECB ; destination address in CS:DI
    call ipxsendpacket        ; send to remote computer.

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret