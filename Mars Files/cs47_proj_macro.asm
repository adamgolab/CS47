# Add you macro definition here - do not touch cs47_common_macro.asm"
#<------------------ MACRO DEFINITIONS ---------------------->#

# Extracts nth bit
.macro extract_nth_bit($storeReg, $source, $pos)
    srlv    $storeReg, $source, $pos
    and     $storeReg, 1
.end_macro

# Sets register to 1
.macro set_n_to_one($storeReg ,$source, $pos)
    li 	    $t7, 1
    sllv    $storeReg, $t7, $pos
    or 	    $storeReg, $storeReg, $source		
.end_macro

# Sets register to 0-1
.macro insert_to_nth_bit($storeReg, $pos, $insert, $mask)
    bne     $mask, $zero, set_one
    set_n_to_one($storeReg, $mask, $insert)	# insert 1
    nor     $storeReg, $storeReg, $zero		# invert
    and     $storeReg, $storeReg, $pos	
    j       end
set_one:
    set_n_to_one($storeReg, $pos, $insert)
end:
.end_macro

# Utility bit by bit generic ripple carry circuit
.macro generic_carry($storeOne, $storeTwo, $one, $two, $carry)
    xor	    $t7, $one, $two	
    xor	    $storeOne, $t7, $carry	
    and     $t6, $one, $two	       
    and     $t5, $carry, $t7		
    or 	    $storeTwo, $t5, $t6	
.end_macro

# Returns two's comp of a number
.macro twos_complement($num)
    nor     $a0, $num, $zero
    li 	    $a1, 1
    li 	    $a2, '+'
    jal     au_logical
.end_macro

# Returns two's comp of a negative number
.macro twos_complement_if_neg($num)
    bge     $num, $zero, positive 	# if num > 0, go to positive
    move    $a0, $num           	# shift num
    twos_complement($a0)                        
    j       end
positive:
    la      $v0, 0($num)
end:
.end_macro

# Utility macro
.macro twos_complement_64bit($lo, $hi)
    nor     $s0, $lo, $zero  
    nor     $s1, $hi, $zero   

    la      $a0, 0($s0)              # shift lo
    addi    $a1, $zero, 1            # ++
    li	    $a2, '+'
    jal     au_logical               # lo++
    move    $s0, $v0                 # save lo++
    la      $t7, 0($v1)                 
    la      $a0, 0($s1)              # shift hi
    move    $a1, $t7                 # shift $t7
    li	    $a2, '+'
    jal     au_logical               # hi + $t7
    move    $s1, $v0                 # save hi + $t7

    la      $v0, 0($s0)
    la      $v1, 0($s1)
.end_macro

# Returns replicated bit
.macro bit_replicator($bit)
    addi    $t7, $zero, 0                       # $t7 = 0
    beq     $bit, 0, zero       		# if bit is zero, continue to zero
    addi    $t7, $zero, 0xFFFFFFFF              # $t7 = 1
zero:
    la      $v0, 0($t7)
.end_macro

# Unsigned multiplication
.macro mul_unsigned($mcnd, $mplr)
    addi    $sp,   $sp, -28
    sw      $fp,   28($sp)
    sw      $ra,   24($sp)
    sw      $mcnd, 20($sp)
    sw      $mplr, 16($sp)
    sw 	    $s0,   12($sp)
    sw 	    $s1,    8($sp)
    addi    $fp,   $sp, 28

    li      $s0, 0         	# i = 0
    li      $s1, 0           	# h = 0
    la      $s2, 0($mplr)     	# L = Multiplier
    la      $s3, 0($mcnd)      	# M = Multiplicand
loop:
    move    $a0, $s2             # L
    extract_nth_bit($t0, $a0, $zero) # Save LSB of L
    la      $a0, 0($t0)  
    bit_replicator($a0)  
    la      $t2, 0($v0)          # R = R final
    and     $t1, $s3, $t2        # X = M & R
    la      $a0, 0($s1)          # $a0 = H
    la      $a1, 0($t1)          # $a1 = X
    li	    $a2, '+'
    jal     au_logical           # sum = H + X
    move    $s1, $v0             # H = H + X
    srl     $s2, $s2, 1          # L = L >> 1
    la      $a0, 0($s1)          # H
    extract_nth_bit($a2, $a0, $zero)  # Save LSB of H
    la      $a0, 0($s2)             
    addi    $a1, $zero, 31       
    insert_to_nth_bit($s2, $a0, $a1, $a2) # Save L
    srl     $s1, $s1, 1          # H = H >> 1
    addi    $s0, $s0, 1          # I = I + 1
    bge     $s0, 32, return   	 # if i == 32, return
    j       loop     
return:
    la      $v0, 0($s2)       
    la      $v1, 0($s1)        
    
    lw      $fp,   28($sp)
    lw      $ra,   24($sp)
    lw      $mcnd, 20($sp)
    lw      $mplr, 16($sp)
    lw 	    $s0,   12($sp)
    lw 	    $s1,    8($sp)
    addi    $sp,   $sp, 28
.end_macro

# Signed multiplication
.macro mul_signed($mcnd, $mplr)
    addi    $sp,   $sp, -28
    sw      $fp,   28($sp)
    sw      $ra,   24($sp)
    sw      $mcnd, 20($sp)
    sw      $mplr, 16($sp)
    sw 	    $s0,   12($sp)
    sw 	    $s1,    8($sp)
    addi    $fp,   $sp, 28
    
    la      $s0, 0($mcnd)    # initial N1
    la      $s1, 0($mplr)    # initial N2
    
    la      $a0, 0($s0)         
    twos_complement_if_neg($a0)  # two's comp for N1
    la      $s2, 0($v0)      # new N1
    move    $a0, $s1         
    twos_complement_if_neg($a0)  # two's comp for N2
    la      $t7, 0($v0)      # new N2
    la      $a0, 0($s2)          
    la      $a1, 0($t7)        
    mul_unsigned($a0, $a1)   # N1 * N2
    la      $t6, 0($v0)      # Rlo
    la      $t0, 0($v1)      # Rhi
    la      $a0, 0($s0)      # initial N1
    addi    $a1, $zero, 31         
    extract_nth_bit($s6, $a0, $a1)  # Rlo - $s6
    la      $a0, 0($s1)      # initial N2
    addi    $a1, $zero, 31          
    extract_nth_bit($s7, $a0, $a1)  # Rhi - $s7  
    xor     $s0, $s6, $s7    # $s0 = $a0[31] xor $a1[31]
    bne     $s0, 1, return
    la      $a0, 0($t6)      # $a0 = Rlo
    la      $a1, 0($t0)      # $a1 = Rhi
    twos_complement_64bit($a0, $a1) 
    la      $t6, 0($v0)      # new Rlo
    la      $t0, 0($v1)      # new Rhi
return:
    move    $v0, $t6         # return Rlo
    move    $v1, $t0         # return Rhi
end:
    lw      $fp,   28($sp)
    lw      $ra,   24($sp)
    lw      $mcnd, 20($sp)
    lw      $mplr, 16($sp)
    lw 	    $s0,   12($sp)
    lw 	    $s1,    8($sp)
    addi    $sp,   $sp, 28
.end_macro

# Unsigned Division
.macro div_unsigned($dvnd, $dvsr)
    addi    $sp,   $sp, -28
    sw      $fp,   28($sp)
    sw      $ra,   24($sp)
    sw      $dvnd, 20($sp)
    sw      $dvsr, 16($sp)
    sw      $s0,   12($sp)
    sw      $s1,    8($sp)
    addi    $fp,   $sp, 28

    li      $s0, 0           	# i = 0
    la      $s1, 0($dvnd)  	# Q = dvnd
    li      $s2, 0  		# R = 0
    la      $s3, 0($dvsr)       # D = dvsr 
loop:
    sll     $s2, $s2, 1  	# R = R << 1
    la      $a0, 0($s1)           
    add     $a1, $zero, 31      
    extract_nth_bit($a2, $a0, $a1)   # $v0 = Q[31]
    la      $a0, 0($s2)         
    li      $a1, 0                
    insert_to_nth_bit($s2, $a0, $a1, $a2)  # $s2 = R
    sll     $s1, $s1, 1         # Q = Q << 1
    la      $a0, 0($s2)           
    la      $a1, 0($s3)            
    addi    $a2, $zero, '-'           
    jal     au_logical         
    move    $t7, $v0            # $t7 = R - D
    blt     $t7, 0, neg     	# if $t7 is negative, jump to neg
    la      $s2, 0($t7)         # R = S
    la      $a0, 0($s1)                
    addi    $a2, $zero, 1              
    insert_to_nth_bit($s1, $a0, $zero, $a2) # Q[0] = 1 
neg:
    addi    $s0, $s0, 1     	# i++
    bge     $s0, 32, exit
    j       loop
exit:
    la      $v0, 0($s1)		# Load Address $s1 to return register
    la      $v1, 0($s2)		# Load Address $s3 to return register

    lw      $fp,   28($sp)
    lw      $ra,   24($sp)
    lw      $dvnd, 20($sp)
    lw      $dvsr, 16($sp)
    lw      $s0,   12($sp)
    lw      $s1,    8($sp)
    addi    $sp,   $sp, 28
.end_macro

# Signed Division
.macro div_signed($dvnd, $dvsr)
    addi    $sp,   $sp, -28
    sw      $fp,   28($sp)
    sw      $ra,   24($sp)
    sw      $dvnd, 20($sp)
    sw      $dvsr, 16($sp)
    sw      $s0,   12($sp)
    sw      $s1,    8($sp)
    addi    $fp,   $sp, 28

    la      $s0, 0($dvnd)    	# Initial $a0 = N1
    la      $s1, 0($dvsr)    	# Initial $a1 = N2
    la      $a0, 0($s0)     
    twos_complement_if_neg($a0) # Positive $a0
    la      $s2, 0($v0)         # New N1
    la      $a0, 0($s1)        
    twos_complement_if_neg($a0) # Positive $a1
    la      $t5, 0($v0)         # New N2
    move    $a0,    $s2         
    move    $a1,    $t5         
    div_unsigned($a0, $a1)      
    la	    $s3, 0($v0)       	# Q
    la	    $s4, 0($v1)       	# R
    la      $a0, 0($s0)        
    addi    $a1, $zero, 31           
    extract_nth_bit($t2, $a0, $a1)  # $t2 = N1[31]
    la	    $a0, 0($s1)         
    addi    $a1, $zero, 31            
    extract_nth_bit($s7, $a0, $a1)  # $s7 = N2[31]    
    xor     $t7, $t2, $s7     	# $t7 = N1[31] xor N2[31]
    ble     $t7, $zero, Q  	 # if Q is positive, go to Q
    la	    $a0, 0($s3)             
    twos_complement($a0)         
    la      $s3, 0($v0)         # Q = Positive Q
Q:
    ble     $t2, $zero, R	   # if R is positive, go to R
    la      $a0, 0($s4)                
    twos_complement($a0)              
    la      $s4, 0($v0)         # R = Positive R
R:
    la      $v0, 0($s3)         # return Q
    la      $v1, 0($s4)         # return R

    lw      $fp,   28($sp)
    lw      $ra,   24($sp)
    lw      $dvnd, 20($sp)
    lw      $dvsr, 16($sp)
    lw      $s0,   12($sp)
    lw      $s1,    8($sp)
    addi    $sp,   $sp, 28
.end_macro
