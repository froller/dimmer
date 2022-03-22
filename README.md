Dimmer
=====

4 level PWM brightness controll for LED lighting

Hardware
--------

This project is designed for [ATtiny13A](https://www.microchip.com/en-us/product/ATtiny13A).

### Hardware Interface

| Pin # | Pin Name | Function |
| --- | --- | --- |
| 1 | !RESET | Output off |
| 2 | PB3 | Set 25% output |
| 3 | PB4 | Set 50% output |
| 4 | GND | Power supply +5V |
| 5 | PB0 | PWM out |
| 6 | PB1 | Healthcheck 1 Hz square |
| 7 | PB2 | Set 100% output |
| 8 | Vcc | Power supply +5V |

To set desired level of output tie corresponding pin to ground for at least 20 ms.

**NOTE**: Pins 1-3 and 7 have internal pull-up resistors enabled. So these pins will source current when tied to ground.

