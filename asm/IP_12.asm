
.include "NI.asm"

# Receives array to be sorted from IP_33 and send back to IP_33 sorted array
main:

    # receive(array, size)
    la $a0, array
    la $a1, size
    lw $a1, 0($a1)
    jal receive
    
    # Copies messageSize from $v1 to $a1
    la $a1, size
    sw $v1, 0($a1)

bubbleSort:

    addiu   $t5, $zero, 1           # t5 = constant 1
    addiu   $t8, $zero, 1           # t8 = 1: swap performed
    
while:
    beq     $t8, $zero, end         # Verifies if a swap has ocurred
    la      $t0, array              # t0 points the first array element
    la      $t6, size               # 
    lw      $t6, 0($t6)             # t6 <- size    
    addiu   $t8, $zero, 0           # swap <- 0
    
loop:    
    lw      $t1, 0($t0)             # t1 <- array[i]
    lw      $t2, 4($t0)             # t2 <- array[i+1]
    slt     $t7, $t2, $t1           # array[i+1] < array[i] ?
    beq     $t7, $t5, swap          # Branch if array[i+1] < array[i]

continue:
    addiu   $t0, $t0, 4             # t0 points the next element
    addiu   $t6, $t6, -1            # size--
    beq     $t6, $t5, while         # Verifies if all elements were compared
    j       loop    

# Swaps array[i] and array[i+1]
swap:    
    sw      $t1, 4($t0)
    sw      $t2, 0($t0)
    addiu   $t8, $zero, 1           # Indicates a swap
    j       continue
    
# Transmit sorted array to IP_33
end: 
    
    la $a0, array
    la $a1, size
    lw $a1, 0($a1)
    jal send
    
idle:

    j idle
    
    
.data 

    # Bubble sort values
    array:       .space 400  # to be filled by receive()
    size:        .space 4
    