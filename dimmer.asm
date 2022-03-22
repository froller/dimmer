#include "tn13def.inc"

.CSEG
		rjmp	RESET		; Reset Handler
		reti			; IRQ0 Handler
		reti			; PCINT0 Handler
		rjmp	TIMER		; Timer0 Overflow Handler
		reti			; EEPROM Ready Handler
		reti			; Analog Comparator Handler
		reti			; Timer0 CompareA Handler
		reti			; Timer0 CompareB Handler
		rjmp	WATCHDOG	; Watchdog Interrupt Handler
		reti			; ADC Conversion Handler



.CSEG
		
RESET:		ldi	r16, low(RAMEND)	; Main program start
		out	SPL, r16		; Set Stack Pointer to top of RAM

		; Set up pins
		ldi	r16, 0b00000011 ; Set PORTB[1:0] for output
		out	DDRB, r16
		ldi	r16, 0b00011100	; Enable pull-up on PORTB[4:2]
		out	PORTB, r16

		; Set up CLK prescaler
		ldi	r16, (1 << CLKPCE)
		out	CLKPR, r16
		ldi	r16, (0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0)
		out	CLKPR, r16

		; Set up watchdog
		in	r16, WDTCR
		ori	r16, (1 << WDCE)
		out	WDTCR, r16
		; 4 clock cycles to set WDT
		ldi	r16, (1 << WDTIE) | (1 << WDP2) | (1 << WDP0)	; 0.5 s
		out	WDTCR, r16
		wdr

		; Set up timer0
		ldi	r19, (1 << COM0A1) | (0 << COM0A0) | (0 << COM0B1) | (0 << COM0B0) | (1 << WGM01) | (1 << WGM00)	; Fast PWM with OCR0A
		ldi	r18, (0 << COM0A1) | (0 << COM0A0) | (0 << COM0B1) | (0 << COM0B0) | (0 << WGM01) | (0 << WGM00)	; Normal mode
		out	TCCR0A, r18
		ldi	r16, 0x00	; 0 PWM
		out	OCR0A, r16
		mov	r20, r16
		ldi	r16, (1 << TOIE0)	; Enable timer interrupt
		out	TIMSK0, r16
		ldi	r16, (0 << WGM02) | (0 << CS02) | (1 << CS01) | (1 << CS00) ; 1/64 CLK for 586 Hz PWM @ 9.6 MHz CLK
		ldi	r16, (0 << WGM02) | (1 << CS02) | (0 << CS01) | (0 << CS00) ; 1/256 CLK for 146 Hz PWM @ 9.6 MHz CLK
		out	TCCR0B, r16

LOOP:
B0:		in	r16, PINB
		andi	r16, (1 << PORTB3)	; Pin 2
		brne	B1
		ldi	r20, 0x40
		rjmp	B3

B1:		in	r16, PINB
		andi	r16, (1 << PORTB4)	; Pin 3
		brne	B2
		ldi	r20, 0x80
		rjmp	B3

B2:		in	r16, PINB
		andi	r16, (1 << PORTB2)	; Pin 7
		brne	B3
		ldi	r20, 0xFF

B3:		sei
		sleep
		cli
		rjmp LOOP

WATCHDOG:	in	r21, PORTB
		ldi	r22, (1 << PORTB1)
		eor	r21, r22
		out	PORTB, r21
		reti

TIMER:		in	r17, PORTB	; Read PORTB for special cases
		in	r16, OCR0A	; Read current OCR0A value
		cp	r16, r20	; Compare OCR0A with R20
		breq	WRITE		; They are equal, nothing left to do
		brlo	INCREASE	; brlo (unsigned) instead of brlt (signed)
DECREASE:	dec	r16		; Decrease OCR0A
		rjmp	WRITE
INCREASE:	inc	r16		; Increase OCR0A
WRITE:		out	OCR0A, r16	; Write OCR0A
		cpi	r16, 0x00	; Special case ZERO
		breq	SET_ZERO
		cpi	r16, 0xFF	; Special case FULL
		breq	SET_FULL
		out	TCCR0A, r19	; Start fast PWM
		reti
SET_ZERO:	andi	r17, ~(1 << PORTB0)
		rjmp	SET_OUT
SET_FULL:	ori	r17, (1 << PORTB0)
SET_OUT:	out	TCCR0A, r18	; Stop fast PWM
		out	PORTB, r17
		reti
		

