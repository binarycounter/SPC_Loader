# SPC Loader

Simple SNES Rom that transfers the SPC file stored at `$FF00` into the SNES APU RAM and plays it. Shows relevant metadata and SPC communication ports while playing. Designed so you do not need to reassemble or modify the SPC file to change the tune. Just copy the contents of the SPC file to $FF00 of the ROM and you're good. 


![screenshot](https://i.imgur.com/tS4KzFw.png)

## Assembling
1. You need a Working libSFX installation (and Cygwin on Windows)
2. git clone this repository
3. edit the Makefile to adjust the libSFX path to where you set it up
4. `make`
5. loader.sfc is your output
6. you can replace the loaded SPC file by either replacing `Data/placeholder.spc` or by copying the full contents of your SPC file to the ROM location `$FF00`.

## Releases
Of course you don't need to assemble it to get your specific SPC file to work, that's the whole point. You can download the template ROM from the Releases tab of this repo. Just patch in your SPC file at `$FF00`.