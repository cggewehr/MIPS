
.text

# receive(receivePointer)
# Polls NI status register and fills "receivePointer" array with received flits

# $a0: Pointer to where received message to be stored at

# $v0: Pointer to where received message to be stored at
# $v1: Message size

# $t0: NI input buffer data in address
# $t1: NI status register address
# $t2: mask for input buffer available bit
# $t3: mask for input buffer EOP bit
# $t4: status register value
# $t5: mask operations temporary & NI input buffer value

# Initializes registers
receive: 

	# $t0 <= NI input buffer data in address
	la $t0, NIBufferAddress
	lw $t0, 0($t0)
	
	# $t1 <= NI status register address
	la $t1, NIStatusRegisterAddress
	lw $t1, 0($t1)
	
	# $t2 <= mask for input buffer available status bit (bit 2)
	li $t2, 0x0004
	
	# $t3 <= mask for EOP status bit (bit 0)
	li $t3, 0x0001
	
	# $v0 <= message pointer
	add $v0, $zero, $a0
	
	# $v1 <= 0 (message size)
	add $v1, $zero, $zero
	
# Polls buffer available bit of NI status register
receivePollingLoop:

	# $t4 <= status register
	lw $t4, 0($t1)
	
	# $t5 <= (Status register) and (Input buffer available mask)
	and $t5, $t4, $t2
	
	# Loops if NI status register bit = '0'
	beq $t5, $zero, receivePollingLoop

# Transfers received flit from buffer to target array
receiveStoreFlit:

	# Copies flit from NI input buffer to target array
	lw $t5, 0($t0)  # $t5 <= NI input buffer
	sw $t5, 0($a0)  # flit
	
	# Increment target array pointer, pointing now to next flit to be received
	addiu $a0, $a0, 4
	
	# Increment message size
	addiu $v1, $v1, 1
	
# Checks if this was the last flit in message
receiveCheckForEOP:

	# $t5 <= (Status register) and (EOP mask)
	and $t5, $t4, $t3
	
	# Loop if not EOP flit, else, return
	beq $t5, $zero, receivePollingLoop
	
# Acknowledges EOP and returns
receiveExit:
	
	# $t5 <= EOP mask (upper 16 bits) & EOP value = '0' (bit 0) (all other data bit are masked off, and so, are irrelevant)
	lui $t5, 0x0001
	
	# Writes EOP ACK to status register
	sw $t5, 0($t1)
	
	# Returns to caller
	jr $ra


# send(messagePointer, messageSize)
# Writes message and control signals to NI output buffer

# $a0: messagePointer
# $a1: messageSize

# $t0: NI input buffer data in address
# $t1: NI status register address
# $t2: mask for output buffer lock bit
# $t3: flit counter
# $t4: status register value

# Initializes registers
send: 

	# $t0 <= NI input buffer data in address
	la $t0, NIBufferAddress
	lw $t0, 0($t0)
	
	# $t1 <= NI status register address
	la $t1, NIStatusRegisterAddress
	lw $t1, 0($t1)
	
	# $t2 <= mask for output buffer ready status bit (bit 1)
	li $t2, 0x0002
	
	# $t3 <= 1 (flit counter) (inits to 1 so that a direct comparison to "messageSize" is possible, without a "-1" offset)
	li $t3, 1

# Polls output buffer lock bit of NI status register
sendPollingLoop:

	# $t4 <= status register
	lw $t4, 0($t1)
	
	# $t5 <= (Status register) and (Input buffer available mask)
	and $t5, $t4, $t2
	
	# Loops if NI status register bit = '0'
	beq $t5, $zero, sendPollingLoop

# Writes message[i] to output buffer
sendWriteFlit:

	# OutputBuffer <= message[i]
	sw $t0, 0($a0)
	
	# Increment messagePointer (i++)
	addi $a0, $a0, 4
	
	# Increment flit counter
	addi $t3, $t3, 1

# Check if this is the last flit in message
sendCheckLastFlit:
	
	# Loop if flitCounter ($t3) < messageSize ($a1)
	blt $t3, $a1, sendPollingLoop
	
# Write txGoAhead control signal and returns to caller
sendExit:

	# Write txGoAhead control bit (bit 1 in status register)
	lui $t5, 0x0002
	ori $t5, $t5 0x0002
	sw $t1, 0($t5)
	
	# Return to caller
	jr $ra

.data

	# MMIO Ni addresses
	NIBufferAddress:		.word	0xffff0000
	NIStatusRegisterAddress:	.word	0xffff0004	
	