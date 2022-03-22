ASM=avra
ASM_ARGS=-I /usr/share/avra

PROG=avrdude
PROG_ARGS=-p t13 -c avrisp2 -P /dev/ttyUSB0

all: firmware

firmware: dimmer.hex

dimmer.hex:  dimmer.asm
	$(ASM) $(ASM_ARGS) -l dimmer.lst -m dimmer.map -o dimmer.hex dimmer.asm

install: flash eeprom

flash: dimmer.hex
	$(PROG) $(PROG_ARGS) -U flash:w:dimmer.hex:i

eeprom: dimmer.eep.hex
	$(PROG) $(PROG_ARGS) -U eeprom:w:dimmer.eep.hex:i

clean:
	rm -f *.obj *.hex *.map *.lst *.cof
