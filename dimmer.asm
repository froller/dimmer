#include "tn13def.inc"

#define PIN_HALF PORTB3
#define PIN_FULL PORTB4

; Internal pull-up resistors
#define PULL_UP 0

; Time quantization in ms
#define TIME_UNIT 2000

; Delays in TIME_UNIT's
#define FADEOUT_DELAY 15
#define BLACKOUT_DELAY 150

; Fixed PWM values
#define PWM_OFF 0x00
#define PWM_HALF 0x7F
#define PWM_FULL 0xFF

;#define DEBUG

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

; r18	no PWM timer settings
; r19	fast PWM timer settings
; r20	desired PWM value
; r21	black-out delay counter
; r22	fade-out delay counter
; r23	slow transition counter
		
.CSEG
		
RESET:		ldi	r16, low(RAMEND)	; Main program start
		out	SPL, r16		; Set Stack Pointer to top of RAM

		; Set up pins
#ifdef DEBUG		
		ldi	r16, 0b00000011	; Set PORTB[1:0] for output
#else
		ldi	r16, 0b00000001	; Set PORTB[1:0] for output
#endif
		out	DDRB, r16

#if PULL_UP==1
		ldi	r16, (1 << PIN_HALF) | (1 << PIN_FULL)	; Enable pull-up on PORTB[4:3]
		out	PORTB, r16
#endif

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
#if TIME_UNIT==2000
		ldi	r16, (1 << WDTIE) | (1 << WDP2) | (1 << WDP1) | (1 << WDP0)	; ~2s
#elif TIME_UNIT=500
		ldi	r16, (1 << WDTIE) | (1 << WDP2) | (0 << WDP1) | (1 << WDP0)	; ~0.5s
#else
		ldi	r16, (1 << WDTIE) | (1 << WDP2) | (1 << WDP1) | (0 << WDP0)	; ~1s
#endif
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
		;ldi	r16, (0 << WGM02) | (1 << CS02) | (0 << CS01) | (0 << CS00) ; 1/256 CLK for 146 Hz PWM @ 9.6 MHz CLK
		ldi	r16, (0 << WGM02) | (0 << CS02) | (1 << CS01) | (1 << CS00) ; 1/64 CLK for 586 Hz PWM @ 9.6 MHz CLK
		out	TCCR0B, r16

		ldi	r21, 0
		ldi     r22, 0
;
; Main loop
;
LOOP:
		ldi	r20, PWM_OFF
; Handling HALF brightness
		in	r16, PINB
		andi	r16, (1 << PIN_HALF)	; Pin 2
		breq	SKIP_CH1 
		ldi	r20, PWM_HALF
		ldi	r21, BLACKOUT_DELAY
SKIP_CH1:
; Handling FULL brightness
		in	r16, PINB
		andi	r16, (1 << PIN_FULL)	; Pin 3
		breq	SKIP_CH2
		ldi	r20, PWM_FULL
		ldi	r21, BLACKOUT_DELAY
		ldi	r22, FADEOUT_DELAY
SKIP_CH2:
		tst	r21
		breq	SKIP_BLACKOUT
		ldi	r20, PWM_HALF
SKIP_BLACKOUT:		
		tst	r22
		breq	SKIP_FADEOUT
		ldi	r20, PWM_FULL
SKIP_FADEOUT:
		sei
		sleep
		cli
		rjmp LOOP

;
; Watchdog interrupt handler
;
WATCHDOG:
; Delay befor fading out
#ifdef DEBUG
		in	r16, PORTB
		andi	r16, ~(1 << PORTB1)
#endif
		tst	r21
		breq	END_OF_FADEOUT_DELAY
		dec     r21
#ifdef DEBUG
		ori	r16, (1 << PORTB1)
#endif

END_OF_FADEOUT_DELAY:

; Delay befor blacking out
		tst	r22
		breq	END_OF_BLACKOUT_DELAY
		dec	r22
#ifdef DEBUG
		ori	r16, (1 << PORTB1)
#endif
		
END_OF_BLACKOUT_DELAY:
#ifdef DEBUG
		out	PORTB, r16
#endif
		reti

;
; Timer0 interrupt handler
; 
TIMER:
		push	r16
		inc	r23		; Used for divider by 4
		mov	r24, r23
		andi	r24, 0xFC
		in	r17, PORTB	; Read PORTB for special cases
		in	r16, OCR0A	; Read current OCR0A value
		cp	r16, r20	; Compare OCR0A with R20
		breq	WRITE		; They are equal, nothing left to do
		brlo	INCREASE	; brlo (unsigned) instead of brlt (signed)
DECREASE:	cpse	r23, r24	; Divider by 4
		dec	r16		; Decrease OCR0A
		rjmp	WRITE
INCREASE:	cpse	r23, r24	; Divider by 4
		inc	r16		; Increase OCR0A
WRITE:		out	OCR0A, r16	; Write OCR0A
		cpi	r16, 0x00	; Special case ZERO
		breq	SET_ZERO
		cpi	r16, 0xFF	; Special case FULL
		breq	SET_FULL
		out	TCCR0A, r19	; Start fast PWM
		pop	r16
		reti
SET_ZERO:	andi	r17, ~(1 << PORTB0)
		rjmp	SET_OUT
SET_FULL:	ori	r17, (1 << PORTB0)
SET_OUT:	out	TCCR0A, r18	; Stop fast PWM
		out	PORTB, r17
		pop	r16
		reti
		

