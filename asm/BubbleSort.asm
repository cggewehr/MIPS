# Programa: BubbleSort
# Descrição: Ordenação crescente

.text
main:
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
    
end: 
    j       end 

.data 
    array:      .word 4 2 1 5 4 7 3
    size:       .word 7
