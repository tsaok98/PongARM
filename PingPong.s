@ ********************************************************
@ Author:   Kevis Tsao       				 *
@ Class:    CS2231                                       *
@ Date:     March, 2017                                	 *
@ File:	    PingPong.s                                   *
@ Version:  1.0                                          *
@ ********************************************************
	
@ ---------------------------------------------------------------
@            Declare global variables for grading/unit testing.
@ ---------------------------------------------------------------
	.global	racketL
	.global racketR
	.global hitCnt
	.global ballGradInit
	.global ballGrad
	.global ballRow
	.global ballCol
	.global newBall
	.global	movBall
	.global movBallUp
	.global movBallDown
	.global movRacket
@ ---------------------------------------------------------------
	.equ 	L_LED, 0x02		@ bit patterns for left LED
	.equ 	R_LED, 0x01		@ bit patterns for right LED
	.equ 	SWI_SetLed, 0x201      	@ LEDs on/off

	.equ	L_BTN, 0x02 		@ bit patterns for left black buttons
	.equ	R_BTN, 0x01 		@ and for right black button
	.equ	SWI_CheckBlack, 0x202	@ Check black button

	.equ 	SWI_DrawString,0x204	@ Draw string to LCD
	.equ	SWI_DrawInt, 0x205	@ Draw integer to LCD
	.equ 	SWI_ClearDisplay,0x206  @ clear LCD
	.equ 	SWI_DrawChar,	0x207   @ display a char on LCD
	.equ 	SWI_ClearLine,	0x208   @ clear specific line on LCD
	.equ	SWI_GetTicks,0x6d  	@ Get current time.
	.equ	SWI_Exit,0x11 		@ Halt execution.
	.equ 	Stdin,0	        	@ 0 is the file descriptor for STDIN
	.equ 	Stdout,1       		@ Set output target to be Stdout

	.equ	maxRow, 14		@ Board rows 0..maxRow
	.equ	maxCol, 39		@ Board columns 0..maxCol
	.equ	maxCellCnt, maxRow * maxCol
	.equ	ball, 'O'		@ The ball
	.equ	space, ' '		@ To erase ball
	.equ	left, -1		@ Direction for racket move
	.equ	right, +1
	.equ	maxGrad, 8		@ Gradient is in ]-8..+8[

	.DATA
timerDelay:
	.word	150			@ 150 ms as time delay seems to work nice
ballsToPlay:
	.word	10			@ Maximum number of balls do play
racketL:
	.word	15			@ 15Left column for racket
racketR:
	.word	23			@ 23Right column for racket
racket:
	.ascii	"========="
hitCnt:
	.word	0 			@ Number of times racket hits
ballGradInit:
	.word	1 			@ Initial value for ball gradient
ballGrad:
	.word	0 			@ Ball gradient (-4..+4)
ballRow:
	.word	0
ballCol:
	.word	0
msgBye:
	.asciz	"End of a fun homework."
msgScore:
	.asciz	"Your score: "
		.TEXT
start:
		swi	SWI_ClearDisplay
		mov	r0, #9		@ draw a new racket
		bl	drawRacket 	@ and a new ball
		bl	newBall
loop:
		ldr	r0, =timerDelay	@ load imer delay
		ldr	r0, [r0]
		bl	timer
		bl	eraseBall
		bl	movBall
		cmp	r0, #0		@ End of game?
		beq	exit		@ Yes
		bl	drawBall
		bl	checkBtn	
		b	loop		@ and loop
exit:
		bl	displayScore
		swi	SWI_Exit
@==========================================================
@ Subroutine displayScore: erase LCD screen and print 
@   the number of time racket was hit.
@
@ Parameters: None
@ Return: Nothing
@ Registers r4-r12 used: 
@==========================================================
displayScore:
	swi	SWI_ClearDisplay
	mov	r0, #10
	mov	r1, #7
	ldr	r2, =msgBye
	swi	SWI_DrawString
	mov	r1, #8
	ldr	r2, =msgScore
	swi	SWI_DrawString
	mov	r0, #22
	ldr	r2, =hitCnt
	ldr	r2, [r2]
	swi	SWI_DrawInt

_displayScore:
	mov	pc, lr

@==========================================================
@ Subroutine drawBall: display ball at position X,Y.
@
@ Parameters: None
@ Return: Nothing
@ Registers r4-r12 used: 
@==========================================================
drawBall:
	ldr	r0, =ballCol
	ldr	r0, [r0]
	ldr	r1, =ballRow
	ldr	r1, [r1]
	ldr	r2, =ball
	swi	SWI_DrawChar

_drawBall:
	mov	pc, lr
@==========================================================
@ Subroutine eraseBall: erase ball at position X,Y.
@
@ Parameters: None
@ Return: Nothing
@ Registers r4-r12 used: 
@==========================================================
eraseBall:
	ldr	r0, =ballCol
	ldr	r0, [r0]
	ldr	r1, =ballRow
	ldr	r1, [r1]
	ldr	r2, =space
	swi	SWI_DrawChar

_eraseBall:
	mov	pc, lr
@==========================================================
@ Subroutine newBall: set ball parameters when dropping from 
@   ceiling (row = 0 and col = midscreen). Get gradient from
@   ballGradInit and increment ballGradInit. When gradient 
@   reaches max value, reset to 1.
@
@ Parameters: None
@ Return: Nothing
@ Registers r4-r12 used: 
@==========================================================
newBall:
	stmfd	sp!, {lr}
	ldr	r0, =ballsToPlay
	ldr	r1, [r0]
	sub	r1, r1, #1
	str	r1, [r0]		@decrements ball counter

	mov	r0, #0
	ldr	r1, =ballRow
	str	r0, [r1]

	mov	r0, #maxCol
	mov	r0, r0, lsr#1
	ldr	r1, =ballCol
	str	r0, [r1]

	ldr	r1, =ballGradInit
	ldr	r0, [r1]
	mov	r2, r0			@Copies gradient for increment
	mov	r3, #maxGrad
	sub	r3, r3, #1		@Resets gradient at 7
	cmp	r2, r3
	moveq	r2, #0
	add	r2, r2, #1
	str	r2, [r1]		@Stores the new initial val
	ldr	r1, =ballGrad
	str	r0, [r1]		@Stores the gradient val
	bl	drawBall

_newBall:
	ldmfd 	sp!, {lr}
	mov	pc, lr
@==========================================================
@ Subroutine movBall: updates ball position according to 
@   gradient (call routines to go up or down). 
@   If racket missed ball set up a new ball.
@
@ Parameters: None
@ Return: 	r0 = 0 <=> End of game (all balls played)
@               else   <=> game should continue
@
@ Registers r4-r12 used: 
@==========================================================
movBall:
	stmfd 	sp!, {lr}
	ldr	r0, =ballGrad
	ldr	r0, [r0]
	cmp	r0, #0
	blt	movUp
	bgt	movDown
	b	_movBall
movUp:
	bl	movBallUp
	mov	r0, #1
	b	_movBall
movDown:
	bl	movBallDown
	cmp	r0, #0
	beq	miss

	cmp	r0, #1
	movne	r0, #1
	bne	_movBall
	ldr	r1, =hitCnt
	ldr	r0, [r1]
	add	r0, r0, #1
	str	r0, [r1]		@Adds one hit to counter

	mov	r0, #1
	b	_movBall
miss:
	ldr	r0, =ballsToPlay	@Remove one ball to play and restart
	ldr	r0, [r0]
	cmp	r0, #0
	beq	_movBall
	bl	eraseBall
	bl	drawRacket
	bl	newBall
	mov	r0, #1
_movBall:
	ldmfd 	sp!, {lr}
	mov	pc, lr
@==========================================================
@ Subroutine movBallUp: move ball up according to gradient.
@   If gradient is invalid (>=0) or <= -maxGrad do nothing.
@
@ Parameters: None
@ Return: nothing
@
@ Registers r4-r12 used: 
@	r4: address of ballRow
@	r5: address of ballCol
@==========================================================
movBallUp:
	stmfd	sp!, {r4-r5, lr}
	ldr	r0, =ballGrad
	ldr	r0, [r0]
	cmp	r0, #0
	bge	_movBallUp
	cmp	r0, #-maxGrad
	bls	_movBallUp		@Checks if the gradient is valid

	ldr	r4, =ballRow
	ldr	r5, =ballCol
	ldr	r2, [r4]
	ldr	r3, [r5]
	ldr	r0, =ballGrad
	ldr	r0, [r0]		@Loads in gradient
	
	cmp	r0, #-1
	subeq	r2, r2, #1
	subeq	r3, r3, #2

	cmp	r0, #-2
	subeq	r2, r2, #1
	subeq	r3, r3, #1

	cmp	r0, #-3
	subeq	r2, r2, #2
	subeq	r3, r3, #1

	cmp	r0, #-4
	subeq	r2, r2, #1

	cmp	r0, #-5
	subeq	r2, r2, #2
	addeq	r3, r3, #1

	cmp	r0, #-6
	subeq	r2, r2, #1
	addeq	r3, r3, #1

	cmp	r0, #-7
	subeq	r2, r2, #1
	addeq	r3, r3, #2		@Deals with row and column changes

	cmp	r3, #0			@Checks if left wall hit
	blle	upLeftBounce
	cmp	r3, #maxCol		@Checks if right wall hit
	blge	upRightBounce

	cmp	r2, #0			@Checks if the top is hit
	blle	topBounce
	
	str	r2, [r4]
	str	r3, [r5]
	ldr	r1, =ballGrad
	str	r0, [r1]
	b	_movBallUp

upLeftBounce:
	mov	r3, #0
	cmp	r0, #-1
	moveq	r0, #-7

	cmp	r0, #-2
	moveq	r0, #-6
	
	cmp	r0, #-3
	moveq	r0, #-5

	mov	pc, lr

upRightBounce:
	mov	r3, #maxCol
	cmp	r0, #-7
	moveq	r0, #-1
	
	cmp	r0, #-6
	moveq	r0, #-2

	cmp	r0, #-5
	moveq	r0, #-3

	mov	pc, lr

topBounce:
	mov	r2, #0

	mvn	r0, r0
	add	r0, r0, #1

	cmp	r0, #4
	bgt	topBounceLeft
	blt	topBounceRight

	mov	pc, lr
topBounceLeft:
	cmp	r0, #7
	moveq	r0, #1
	
	cmp	r0, #6
	moveq	r0, #2

	cmp	r0, #5
	moveq	r0, #3

	mov	pc, lr

topBounceRight:
	cmp	r0, #1
	moveq	r0, #7
	
	cmp	r0, #2
	moveq	r0, #6
	
	cmp	r0, #3
	moveq	r0, #5

	mov	pc, lr

_movBallUp:
	ldmfd	sp!, {r4-r5, lr}
	mov	pc, lr

@==========================================================
@ Subroutine movBallDown: move ball according to gradient.
@   If gradient is invalid (<=0) or >= maxGrad do nothing.
@
@ Parameters: None
@
@ Return:  r0 = 0 <=> racket miss
@             = 1 <=> racket hit
@             > 1 <=> racket not impacted
@ 
@ Registers r4-r12 used: 
@	r4: address of ballRow
@	r5: address of ballCol
@==========================================================
movBallDown:
	stmfd	sp!, {r4-r5, lr}
	ldr	r0, =ballGrad
	ldr	r0, [r0]
	cmp	r0, #0
	bls	_movBallDown
	cmp	r0, #maxGrad
	bge	_movBallDown		@Checks if the gradient is valid

	ldr	r4, =ballRow
	ldr	r5, =ballCol
	ldr	r2, [r4]
	ldr	r3, [r5]
	ldr	r0, =ballGrad
	ldr	r0, [r0]		@Loads in gradient
	
	cmp	r0, #1
	addeq	r2, r2, #1
	addeq	r3, r3, #2

	cmp	r0, #2
	addeq	r2, r2, #1
	addeq	r3, r3, #1

	cmp	r0, #3
	addeq	r2, r2, #2
	addeq	r3, r3, #1

	cmp	r0, #4
	addeq	r2, r2, #1

	cmp	r0, #5
	addeq	r2, r2, #2
	subeq	r3, r3, #1

	cmp	r0, #6
	addeq	r2, r2, #1
	subeq	r3, r3, #1

	cmp	r0, #7
	addeq	r2, r2, #1
	subeq	r3, r3, #2		@Deals with row and column changes

	cmp	r3, #0			@Checks if left wall hit
	blle	downLeftBounce
	cmp	r3, #maxCol		@Checks if right wall hit
	blge	downRightBounce

	cmp	r2, #maxRow		@Checks if the bottom is hit
	blge	racketBounce

	str	r2, [r4]
	str	r3, [r5]
	ldr	r1, =ballGrad
	str	r0, [r1]
	mov	r0, #2
	b	_movBallDown
	
downLeftBounce:
	mov	r3, #0
	cmp	r0, #7
	moveq	r0, #1
	
	cmp	r0, #6
	moveq	r0, #2

	cmp	r0, #5
	moveq	r0, #3

	mov	pc, lr

downRightBounce:
	mov	r3, #maxCol
	cmp	r0, #1
	moveq	r0, #7
	
	cmp	r0, #2
	moveq	r0, #6
	
	cmp	r0, #3
	moveq	r0, #5

	mov	pc, lr

racketBounce:
	ldr	r1, =racketL
	ldr	r1, [r1]
	cmp	r3, r1
	movlt	r0, #0
	blt	_movBallDown		@Checks if it misses the left side

	ldr	r1, =racketR
	ldr	r1, [r1]
	cmp	r3, r1
	movgt	r0, #0
	bgt	_movBallDown		@Checks if it misses the right side

	mov	r2, #maxRow
	sub	r2, r2, #1		@Reverses direction and places above racket
	mvn	r0, r0
	add	r0, r0, #1
	
	cmp	r0, #-4
	bgt	racketBounceLeft
	blt	racketBounceRight

continueDown:
	str	r2, [r4]
	str	r3, [r5]
	ldr	r1, =ballGrad
	str	r0, [r1]
	mov	r0, #1
	b	_movBallDown

racketBounceLeft:
	cmp	r0, #-1
	moveq	r0, #-7

	cmp	r0, #-2
	moveq	r0, #-6
	
	cmp	r0, #-3
	moveq	r0, #-5

	b	continueDown

racketBounceRight:
	cmp	r0, #-7
	moveq	r0, #-1
	
	cmp	r0, #-6
	moveq	r0, #-2

	cmp	r0, #-5
	moveq	r0, #-3

	b	continueDown

_movBallDown:
	ldmfd	sp!, {r4-r5, lr}
	mov	pc, lr

@==========================================
@ Subroutine checkBtn. Check black buttons. 
@   Left button depressed => move racket one
@   column to the left.
@   Right button depressed => move racket one
@   column to the right.
@   If racket moves, call for redraw.
@
@ Parameters: None
@ Return: nothing
@
@ Registers r4-r12 used: 
@==========================================
checkBtn:
	stmfd	sp!, {lr}
	swi	SWI_CheckBlack
	cmp	r0, #2
	beq	btnLeft
	cmp	r0, #1
	beq	btnRight
	b	_checkBtn

btnLeft:
	mov	r0, #left
	bl	movRacket
	bl	drawRacket
	b	_checkBtn

btnRight:	
	mov	r0, #right
	bl	movRacket
	bl	drawRacket
	b	_checkBtn

_checkBtn:
	ldmfd	sp!, {lr}
	mov	pc, lr

@==========================================
@ Subroutine movRacket. Move racket right
@   or left 2 columns at a time 
@   for speed but check it stays on screen:
@   If left and against left border: do nothing
@   same for right
@
@ Parameters: r0 = direction to move
@             #right or #left
@             else do nothing
@
@ Return: Nothing
@
@ Registers r4-r12 used: 
@	r4:	Holds the racketL address
@	r5:	Holds the racketR address
@==========================================
movRacket:
	stmfd	sp!, {r4-r5, lr}
	ldr	r4, =racketL
	ldr	r5, =racketR
	cmp	r0, #right
	beq	movRight
	cmp	r0, #left
	beq	movLeft
	b	_movRacket		@Decides the direction to move
movRight:
	ldr	r1, [r4]
	ldr	r2, [r5]
	cmp	r2, #maxCol
	addne	r1, r1, #1
	addne	r2, r2, #1
	cmp	r2, #maxCol
	addne	r1, r1, #1
	addne	r2, r2, #1
	str	r1, [r4]
	str	r2, [r5]
	b	_movRacket

movLeft:
	ldr	r1, [r4]
	ldr	r2, [r5]
	cmp	r1, #0
	subne	r1, r1, #1
	subne	r2, r2, #1
	cmp	r1, #0
	subne	r1, r1, #1
	subne	r2, r2, #1
	str	r1, [r4]
	str	r2, [r5]
	b	_movRacket

_movRacket:
	ldmfd	sp!, {r4-r5, lr}
	mov	pc, lr

@==========================================================
@ Subroutine drawRacket: erase line and redraw racket 
@   at its position.
@
@ Parameters: None
@
@ Registers r4-r12 used: 
@==========================================================
drawRacket:
	mov	r0, #maxRow
	swi	SWI_ClearLine		@Erases the bottom row
	ldr	r0, =racketL
	ldr	r0, [r0]
	mov	r1, #maxRow
	ldr	r2, =racket
	swi	SWI_DrawString

_drawRacket:
	mov	pc, lr
@==========================================
@ Subroutine timer. Wait for x milliseconds 
@ Parameters:
@   r0 : number of ms to wait
@
@ Return: nothing
@
@ Registers r4-r12 used: 
@==========================================
timer:
	mov	r1, r0
	swi	SWI_GetTicks
	add	r1, r0, r1
timer1:
	swi	SWI_GetTicks
	cmp	r0, r1
	beq	_timer
	b	timer1
_timer:
	mov	pc, lr

	.END
