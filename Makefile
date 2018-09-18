name        := loader
debug		:= 0



derived_files	:= Data/font.png.palette 
derived_files	+= Data/font.png.tiles 

#This is basically so it doesn't mess up tile to ascii order by deleting duplicate tiles
Data/font.png.palette: palette_flags= --no-discard --no-flip
Data/font.png.tiles: tiles_flags= --no-discard --no-flip
Data/font.png: map_flags= --no-discard --no-flip

# Include libSFX.make, edit this to your libSFX location
libsfx_dir	:= ../../../Resources/SDKs/libSFX
include $(libsfx_dir)/libSFX.make



