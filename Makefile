ASM = ../EASy68K-asm/ASM68Kv5.15.4/asy68k
BUILD_PRESO = ./build_teslerpoint_presentation.py
IMAGES = test_image_1.gif test_image_2.gif test_image_3.gif \
         test_image_4.jpg test_image_5.jpg test_image_6.jpg test_image_7.jpg

all: teslerpoint.bin preso.dc42

teslerpoint.S68: teslerpoint.x68
	! $(ASM) $^ && ! grep ERROR teslerpoint.L68

teslerpoint.bin: teslerpoint.S68
	srec_cat $^ -offset -0x800 -o $@ -binary

preso.dc42: $(BUILD_PRESO) $(IMAGES) teslerpoint.bin
	$(BUILD_PRESO) $(IMAGES) -t teslerpoint.bin -o $@

clean:
	rm -f teslerpoint.S68 teslerpoint.L68 teslerpoint.bin preso.dc42

.PHONY: all clean
