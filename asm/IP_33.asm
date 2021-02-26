
.include "NI.asm"

# Sends array to be sorted by IP_12 and receives back from IP_12 sorted array
main:

    # send(array, size)
    la $a0, array
    la $a1, size
    lw $a1, 0($a1)
    jal send
    
    # receive(array, size)
    la $a0, array
    la $a1, size
    lw $a1, 0($a1)
    jal receive
    
.data 

    # send() values
    array: .word 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 9 2 1 5 6 0 2 5 0 9 
    size:  .word 100
    