.include "./cs47_proj_macro.asm"
.text
.globl au_logical
# TBD: Complete your project procedures
# Needed skeleton is given
#####################################################################
# Implement au_logical
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)
# Notes:
#####################################################################
au_logical:
	addi  	$sp, $sp, -48
	sw      $fp, 48($sp)
	sw      $ra, 44($sp)
	sw 	$a0, 40($sp)
	sw      $a1, 36($sp)
	sw 	$a2, 32($sp)
	sw 	$s0, 28($sp)
	sw 	$s1, 24($sp)
	sw 	$s2, 20($sp)
	sw 	$s3, 16($sp)
	sw 	$s4, 12($sp)
	sw 	$s5,  8($sp)
	addi    $fp, $sp, 48
	
	beq	$a2, '+', add_logical		# if $a2 == + then go to add			
	beq	$a2, '-', sub_logical		# if $a2 == - then go to sub			
	beq	$a2, '*', mul_logical		# if $a2 == * then go to mult			
	beq	$a2, '/', div_logical		# if $a2 == div then go to div
add_logical:
	addi	$a2, $zero, 0		# $a2 = 0x00000000
	jal	add_sub_logical		
	j	exit
sub_logical:
	addi	$a2, $zero, 0xFFFFFFFF	# $a2 = 0xFFFFFFFF
	jal	add_sub_logical		
	j	exit
add_sub_logical:
	addi 	$s2, $zero, 0		# i = 0
	addi  	$s3, $zero, 0 		# s = 0
	la   	$s0, 0($a1) 		# Entered Argument
	la	$s1, 0($a0) 		# Entered Argument
	la    	$a0, 0($a2)		 
	extract_nth_bit($s4, $a0, $zero)# Save LSB	
	beqz	$s4, adding	
	nor	$s0, $s0, $zero		# $s0 = ~$s0
adding:
	la 	$a0, 0($s1)			
	la 	$a1, 0($s2)	
	extract_nth_bit($s5, $a0, $a1)  # Save ith bit of Argument
	la 	$a0, 0($s0)			
	la 	$a1, 0($s2)			
	extract_nth_bit($t0, $a0, $a1) 	# Save ith bit of Argument
	la 	$a0, 0($s5)					
	la 	$a1, 0($t0)					
	la 	$a2, 0($s4) 			
	generic_carry($t1, $s4, $a0, $a1, $a2)	# Save $t1 for insertion check		
	la 	$a0, 0($s5)			# and store $s4 overflow bit
	la 	$a1, 0($t0)				
	la 	$a2, 0($s4) 				
	generic_carry($zero, $s4, $a0, $a1, $a2) # Save overflow bit into $s4
	beqz 	$t1, ignore_insert	# if $t1 = 0, dont insert anything
	la 	$a0, 0($s3)	
	la 	$a1, 0($s2)					
	la 	$a2, 0($t1)				
	insert_to_nth_bit($s3, $a0, $a1, $a2) # Save S[i]
ignore_insert:
	addi	$s2, $s2, 1		# i++
	bge	$s2, 32, end		
	j	adding			
end:
	la 	$v0, 0($s3)		# S			
	la 	$v1, 0($s4)		# Overflow bit
	jr 	$ra		
mul_logical:
	mul_signed($a0, $a1)
	j	exit
div_logical:
	div_signed($a0, $a1)
	j 	exit
exit:
	lw      $fp, 48($sp)
	lw      $ra, 44($sp)
	lw 	$a0, 40($sp)
	lw      $a1, 36($sp)
	lw 	$a2, 32($sp)
	lw 	$s0, 28($sp)
	lw 	$s1, 24($sp)
	lw 	$s2, 20($sp)
	lw 	$s3, 16($sp)
	lw 	$s4, 12($sp)
	lw 	$s5,  8($sp)
	addi	$sp, $sp, 48
	jr 	$ra