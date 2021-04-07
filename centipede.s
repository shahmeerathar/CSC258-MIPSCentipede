#####################################################################
#
# CSC258H Winter 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Muhammad Shahmeer Athar, 100622471
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp) 
#
# Which milestone is reached in this submission?
# (See the project handout for descriptions of the milestones)
# - Milestone 0
#
# Which approved additional features have been implemented?
# (See the project handout for the list of additional features)
# 1. None yet
#
# Any additional information that the TA needs to know:
# - aa is the first byte of a display unit to represent a centipede
# - ee is the first byte of a display unit to represent a mushroom
# - bb for player
# - cc for flea
#
#####################################################################

.data
	displayAddress:	.word 0x10008000
	centipedeLocationX: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
	centipedeLocationY: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	centipedeDirection: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1		# 1 means right, -1 means left
	wiggleFlag: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	bugBlasterLocation: .word 16
	dart: .word 0, 0, 0	# In order: visible flag, x value, y value
	centipedeHealth: .word 3
	flea: .word 0, 0, 0
.text 

start:
jal growMushrooms
jal dispCentipede

main:				# main game loop
	jal removeCentipede
	jal moveCentipede
	jal dispCentipede
	
	jal removeBug
	jal getInput
	jal paintBug
	
	jal clearDart
	jal moveDart
	jal checkDartMushroomCollision
	jal checkDartFleaCollision
	jal checkDartCentipedeCollision
	jal renderDart
	
	jal spawnFlea
	jal clearFlea
	jal moveFlea
	jal checkFleaPlayerCollision
	jal renderFlea
	
	li $v0, 32				# Sleep op code
	li $a0, 50				# Sleep 1/20 second 
	syscall
	j main
	
#####################################################################

growMushrooms:
	li $a2, 24	 # load a2 with the loop count

outerShroomLoop:
	li $a3, 2	# 2 mushrooms per row
	li $v0, 42	# ranged random num generator
	li $a0, 0	# numgen ID
	li $a1, 24	# max offset
	sll $t0, $a2, 7		# y axis offset
	
innerShroomLoop:
	syscall
	addi $a0, $a0, 4
	sll $t1, $a0, 2		# x axis offset
	add $t3, $t0, $t1	# mushroom offset
	lw $t4, displayAddress
	add $t4, $t4, $t3	# mushroom location
	li $t5 0xeeffff00	# $t5 stores the yellow colour code + flag byte
	sw $t5, 0($t4)		# paint mushroom unit

	addi $a3, $a3, -1	 # decrement $a3 by 1
	bne $a3, $zero, innerShroomLoop
	
	addi $a2, $a2, -5	 # decrement $a2 by 1
	bgt $a2, 2, outerShroomLoop
	
	jr $ra

#####################################################################

getInput:
	la $a1, bugBlasterLocation
	lw $t1, 0($a1)
	lw $t8, 0xffff0000			# Check MMIO location for keypress 
	beq $t8, 1, keyboard_input		# If we have input, jump to handler
	j keyboard_input_done			# Otherwise, jump till end

	keyboard_input:
		lw $t8, 0xffff0004				# Read Key value into t8
		beq $t8, 0x6A, keyboard_left	# If `j`, move left
		beq $t8, 0x6B, keyboard_right	# If `k`, move right
		beq $t8, 0x78, keyboard_shoot	# If `x`, shoot
    		beq $t8, 0x72, keyboard_restart # If `r`, restart the game from end screen
    		beq $t8, 0x63, Exit 		# If `c`, terminate the program gracefully

		j keyboard_input_done		# Otherwise, ignore...

		keyboard_left:
			beq $t1, 0, keyboard_input_done	# If at left wall, warp to right
			addi $t1, $t1, -1			# Otherwise, decrement x
			j keyboard_input_done			# done

		keyboard_right:
			beq $t1, 31, keyboard_input_done	# If at left wall, warp to right
			addi $t1, $t1, 1			# Otherwise, increment x
			j keyboard_input_done
			
		keyboard_shoot:
			# Spawn dart
			la $a0, dart
			lw $t8, 0($a1)
			beq $t8, 1, dontSpawn
			sw $at, 0($a0)
			la $a1, bugBlasterLocation
			lw $t0, 0($a1)
			sw $t0, 4($a0)
			li $t2, 29
			sw $t2, 8($a0)
			dontSpawn:
			j keyboard_input_done
			
	keyboard_restart:
		jal clearScreen
		la $t2, centipedeLocationX
		la $t3, centipedeLocationY
		la $t4, centipedeDirection
		la $t5, wiggleFlag
		addi $t6, $zero, 0
		addi $t7, $zero, 0
		addi $t9, $zero, 1
		reset:
			sw $t6, 0($t2)
			sw $t7, 0($t3)
			sw $t9, 0($t4)
			sw $t7, 0($t5)
			addi $t2, $t2, 4
			addi $t3, $t3, 4
			addi $t4, $t4, 4
			addi $t5, $t5, 4
			addi $t6, $t6, 1
			bne $t6, 10, reset
		addi $t6, $zero, 16
		la $t2, bugBlasterLocation
		sw $t6, 0($t2)
		la $t3, dart
		sw $zero, 0($t3)
		sw $zero, 4($t3)
		sw $zero, 8($t3)
		la $t3, flea
		sw $zero, 0($t3)
		sw $zero, 4($t3)
		sw $zero, 8($t3)
		la $t2, centipedeHealth
		addi $t6, $zero, 3
		sw $t6, 0($t2)
		jal start
	
	Exit:
		jal clearScreen
		li $v0, 10
		syscall

	keyboard_input_done:
		sw $t1, 0($a1)
		jr $ra
		
removeBug:
	la $a1, bugBlasterLocation
	lw $t0, 0($a1)
	sll $t1, $t0, 2
	li $t2, 30
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0x000000
	sw $t7, 0($t4)
	jr $ra

paintBug:
	la $a1, bugBlasterLocation
	lw $t0, 0($a1)
	sll $t1, $t0, 2
	li $t2, 30
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0xbbffffff
	sw $t7, 0($t4)
	jr $ra
	
clearScreen:
	addi $t1, $zero, 1023
	clear:
		sll $t4, $t1, 2
		lw $t2, displayAddress
		add $t2, $t2, $t4
		li $t3, 0x000000
		sw $t3, 0($t2)
		addi $t1, $t1, -1
		bne $t1, -1, clear
	jr $ra
	
#####################################################################
	
renderDart:
	la $a1, dart
	lw $t8, 0($a1)
	beq $t8, 0, skipRender
	lw $t0, 4($a1)
	sll $t1, $t0, 2
	lw $t2, 8($a1)
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0x0000ff
	sw $t7, 0($t4)
	skipRender:
	jr $ra
	
moveDart:
	la $a0, dart
	lw $t8, 0($a0)
	beq $t8, 0, skipMove
	lw $t0, 8($a0)
	add $t0, $t0, -1
	sw $t0, 8($a0)
	bgt $t0, -1, skipMove
	sw $zero, 0($a0)
	skipMove:
	jr $ra
	
clearDart:
	la $a1, dart
	lw $t8, 0($a1)
	beq $t8, 0, skipClear
	lw $t0, 4($a1)
	sll $t1, $t0, 2
	lw $t2, 8($a1)
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0x00000000
	sw $t7, 0($t4)
	skipClear:
	jr $ra
	
checkDartMushroomCollision:
	la $a0, dart
	lw $t0, 0($a0)
	beq $t0, 0, skipMushCollisCheck
	lw $t1, 4($a0)
	lw $t2, 8($a0)
	sll $t3, $t1, 2
	sll $t4, $t2, 7
	lw $t5, displayAddress
	add $t6, $t3, $t4
	add $t7, $t5, $t6
	lw $a1, 0($t7)
	bne $a1, 0xeeffff00, skipMushCollisCheck
	li $a2 0x00000000
	sw $a2, 0($t7)
	li $t0, 0
	sw $t0, 0($a0)
	skipMushCollisCheck:
	jr $ra
	
checkDartFleaCollision:
	la $a0, dart
	lw $t0, 0($a0)
	beq $t0, 0, skipFleaDartCollisCheck
	lw $t1, 4($a0)
	lw $t2, 8($a0)
	sll $t3, $t1, 2
	sll $t4, $t2, 7
	lw $t5, displayAddress
	add $t6, $t3, $t4
	add $t7, $t5, $t6
	lw $a1, 0($t7)
	bne $a1, 0xccff00ff, skipFleaDartCollisCheck
	li $a2 0x00000000
	sw $a2, 0($t7)
	li $t0, 0
	sw $t0, 0($a0)
	la $t8, flea
	sw $zero, 0($t8)
	sw $zero, 4($t8)
	sw $zero, 8($t8)
	skipFleaDartCollisCheck:
	jr $ra
	
checkDartCentipedeCollision:
	la $a0, dart
	lw $t0, 0($a0)
	beq $t0, 0, skipCentCollisCheck
	lw $t1, 4($a0)
	lw $t2, 8($a0)
	sll $t3, $t1, 2
	sll $t4, $t2, 7
	lw $t5, displayAddress
	add $t6, $t3, $t4
	add $t7, $t5, $t6
	lw $a1, 0($t7)
	beq $a1, 0xaaff0000, centDartCollision
	bne $a1, 0xaa00ff00, skipCentCollisCheck
	centDartCollision:
		la $a2 centipedeHealth
		lw $t1, 0($a2)
		add $t1, $t1, -1
		bne $t1, 0, stillAlive
		j keyboard_restart
		stillAlive:
			sw $t1, 0($a2)
			li $t0, 0
			sw $t0, 0($a0)
	skipCentCollisCheck:
	jr $ra

#####################################################################
	
spawnFlea:
	li $v0, 42	# ranged random num generator
	li $a0, 0
	li $a1, 10
	syscall
	bne $a0, 1, noSpawn
	li $a1, 31
	syscall
	addi $t8, $a0, 0
	
	la $a0, flea
	lw $t1, 0($a0)
	beq $t1, 1, noSpawn
	sw $at, 0($a0)
	sw $t8, 4($a0)
	
	noSpawn:
	jr $ra

renderFlea:
	la $a1, flea
	lw $t8, 0($a1)
	beq $t8, 0, noRender
	lw $t0, 4($a1)
	sll $t1, $t0, 2
	lw $t2, 8($a1)
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0xccff00ff
	sw $t7, 0($t4)
	noRender:
	jr $ra
	
moveFlea:
	la $a0, flea
	lw $t8, 0($a0)
	beq $t8, 0, skipMoveFlea
	lw $t0, 8($a0)
	add $t0, $t0, 1
	sw $t0, 8($a0)
	blt $t0, 32, skipMoveFlea
	sw $zero, 0($a0)
	sw $zero, 8($a0)
	skipMoveFlea:
	jr $ra
	
clearFlea:
	la $a1, flea
	lw $t8, 0($a1)
	beq $t8, 0, skipClearFlea
	lw $t0, 4($a1)
	sll $t1, $t0, 2
	lw $t2, 8($a1)
	sll $t3, $t2, 7
	lw $t4, displayAddress
	add $t5, $t1, $t3
	add $t4, $t4, $t5
	li $t7 0x00000000
	sw $t7, 0($t4)
	skipClearFlea:
	jr $ra
	
checkFleaPlayerCollision:
	la $a0, flea
	lw $t0, 0($a0)
	beq $t0, 0, skipFleaPlayerCollisCheck
	lw $t1, 4($a0)
	lw $t2, 8($a0)
	sll $t3, $t1, 2
	sll $t4, $t2, 7
	lw $t5, displayAddress
	add $t6, $t3, $t4
	add $t7, $t5, $t6
	lw $a1, 0($t7)
	bne $a1, 0xbbffffff, skipFleaPlayerCollisCheck
	j keyboard_restart
	skipFleaPlayerCollisCheck:
	jr $ra

#####################################################################

dispCentipede:
	addi $a3, $zero, 10	 # load a3 with the loop count (10)
	la $a1, centipedeLocationX # load the address of the array into $a1
	la $a2, centipedeLocationY # load the address of the array into $a2
	
arr_loop:			#iterate over the loops elements to draw each body in the centipede
	lw $t1, 0($a1)		 # load a word from the centipedeLocation array into $t1
	lw $t5, 0($a2)		 # load a word from the centipedeDirection  array into $t5
	#####
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0xaaff0000	# $t3 stores the red colour code
	li $t6 0xaa00ff00	# $t6 stores the green colour code
	
	sll $t4,$t1, 2		# $t4 is the bias of the old body location in memory (offset*4)
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sll $t5, $t5, 7
	add $t4, $t5, $t4
	sw $t3, 0($t4)		# paint the body with red
	
	bne $a3, 1, skip_green	# only paint the head green
	sw $t6, 0($t4)	
	
skip_green:
	addi $a1, $a1, 4	 # increment $a1 by one, to point to the next element in the array
	addi $a2, $a2, 4
	addi $a3, $a3, -1	 # decrement $a3 by 1
	bne $a3, $zero, arr_loop
	
	jr $ra
	
#####################################################################

removeCentipede:
	addi $a3, $zero, 10	 # load a3 with the loop count (10)
	la $a1, centipedeLocationX # load the address of the array into $a1
	la $a2, centipedeLocationY # load the address of the array into $a2
	
arr_loop2:			#iterate over the loops elements to draw each body in the centipede
	lw $t1, 0($a1)		 # load a word from the centipedeLocation array into $t1
	lw $t5, 0($a2)		 # load a word from the centipedeDirection  array into $t5
	#####
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000	# $t3 stores the blck colour code
	
	sll $t4,$t1, 2		# $t4 is the bias of the old body location in memory (offset*4)
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sll $t5, $t5, 7
	add $t4, $t5, $t4
	sw $t3, 0($t4)		# paint the body with red
	
	addi $a1, $a1, 4	 # increment $a1 by one, to point to the next element in the array
	# addi $a2, $a2, 4
	addi $a3, $a3, -1	 # decrement $a3 by 1
	bne $a3, $zero, arr_loop2
	
	jr $ra
	
#####################################################################

moveCentipede:
	addi $t7, $zero, 10	 # load t7 with the loop count (10)
	la $a1, centipedeLocationX # load the address of the array into $a1
	la $a2, centipedeLocationY # load the address of the array into $a2
	la $a3, centipedeDirection # load the address of the array into $a3
	la $a0, wiggleFlag # should the centipede change direction
	
arr_loop3:			#iterate over the loops elements to update each body in the centipede
	lw $t1, 0($a1)		 # load a word from the centipedeLocationX array into $t1
	lw $t2, 0($a2)		 # load a word from the centipedeLocationY array into $t2
	lw $t3, 0($a3)		 # load a word from the centipedeDirection array into $t3
	lw $t4, 0($a0)		 # load a word from the wiggleFlag array into $t4
	
	beq $t1, 31, increment_y
	beq $t1, 0, increment_y
	j increment_x
	increment_y:
	beq $t4, 0, increment_x
		beq $t2, 30, flip_dir
		if2:
			addi $t2, $t2, 1
			sw $t2, 0($a2)
		flip_dir:
			sw $zero, 0($a0)
			beq $t3, 1, subtract
			j sum
			subtract:
				addi $t3, $t3, -2
				j store
			sum:
			addi $t3, $t3, 2
			store:
			sw $t3, 0($a3)
			j next
	increment_x:
	addi $t5, $zero, 1
	sw $t5, 0($a0)
	add $t1, $t1, $t3
	### Check if next unit is a mushroom
	lw $t8, displayAddress
	sll $t9, $t1, 2
	add $t8, $t8, $t9
	sll $t9, $t2, 7
	add $t8, $t8, $t9
	lw $t9, 0($t8)
	beq $t9, 0xeeffff00, increment_y
	####################################
	sw $t1, 0($a1)
	
	next:
	### Check if collides with  player
	lw $t8, displayAddress
	sll $t9, $t1, 2
	add $t8, $t8, $t9
	sll $t9, $t2, 7
	add $t8, $t8, $t9
	lw $t9, 0($t8)
	beq $t9, 0xbbffffff, keyboard_restart
	##################################
	
	addi $a1, $a1, 4	 # increment $a1 by one, to point to the next element in the array
	addi $a2, $a2, 4
	addi $a3, $a3, 4
	addi $a0, $a0, 4
	addi $t7, $t7, -1	 # decrement $a0 by 1
	bne $t7, $zero, arr_loop3
	
	jr $ra

#####################################################################
