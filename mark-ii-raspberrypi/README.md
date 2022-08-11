# Mark II Raspberry Pi OS Integration

Contains scripts and service for using Mark II hardware on Raspberry Pi OS:

* Microphone (XMOS XVF3510-INT)
* Speakers
* LED ring
* Fan
* Buttons

Tested on 5.15 aarch64 kernel of Raspbery Pi OS (64-bit lite).


## Installation

Run the installation script:

``` sh
./install.sh
```

and then reboot your Raspberry Pi.


## Microphone and Speakers

Use `arecord` and `aplay` as you normally would. For example:

``` sh
arecord -r 22050 -c 1 -f S16_LE -t wav -d 5 > test.wav
```

(say something for 5 seconds)

``` sh
aplay test.wav
```

You can adjust the amplifier volume (0-100):

``` sh
mark2-volume 50
```


## LEDs, Fan, Buttons

* `mark2-leds`
    * Off: `mark2-leds 0`
    * Red: `mark2-leds 255,0,0,0`
    * Brighter Red: `mark2-leds 255,0,0,0 100`
    * Dimmer Red: `mark2-leds 255,0,0,0 50`
    * Christmas: `mark2-leds 255,0,0,0,255,0`
    * Rainbow: `mark2-leds 255,0,0,255,127,0,255,255,0,0,255,0,0,0,255,75,0,130,147,0,211`
* `mark2-fan`
    * Full blast: `mark2-fan 100`
    * Off: `mark2-fan 0`
* `mark2-buttons`
    * Prints button names and boolean states (e.g. `volume_up true`)
    * Names
        * `volume_up`
        * `volume_down`
        * `action`
        * `mute`
    * States
        * `true` (button down, mute off)
        * `false` (button up, mute on)

---


## Debugging


### Microphone

Verify that the hardware is on the I2C bus:

``` sh
$ i2cdetect -y 1
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- 2c -- -- 2f 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
70: -- -- -- -- -- -- -- -- 
```

and in the list of available ALSA devices:

``` sh
$ arecord -l
**** List of CAPTURE Hardware Devices ****
card 2: sndrpisimplecar [snd_rpi_simple_card], device 0: simple-card_codec_link snd-soc-dummy-dai-0 [simple-card_codec_link snd-soc-dummy-dai-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

``` sh
$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: vc4hdmi0 [vc4-hdmi-0], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: vc4hdmi1 [vc4-hdmi-1], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 2: sndrpisimplecar [snd_rpi_simple_card], device 0: simple-card_codec_link snd-soc-dummy-dai-0 [simple-card_codec_link snd-soc-dummy-dai-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

Next, check the service log:

``` sh
sudo journalctl -u mycroft-xmos.service
```

and also verify that the driver module was loaded:

``` sh
lsmod | grep i2s_master_loader
```


### LEDs, Fans, and Buttons

Check the DBus service log:

``` sh
sudo journalctl -u mycroft-hal.service
```
