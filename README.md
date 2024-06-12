Teslerpoint
===========

![An Apple Lisa 1 running Teslerpoint; the screen shows a stylistic recreation
of an old PowerPoint slide featuring the title "Teslerpoint", the Screen Beans
clipart of a stick figure having a "light bulb" moment, and the words "No
Modes!" in large, bold Comic Sans. An RC2014 kit computer sits in the
foreground for no particular reason.](splash.jpg "An Apple Lisa 1 running
Teslerpoint and displaying a stylistic recreation of an old PowerPoint slide.")

Teslerpoint is a slide carousel system that displays bitmap images on the
screen of an Apple Lisa computer. It comprises:

* [`teslerpoint.x68`](teslerpoint.x68), a small program that runs on the Lisa's
  "bare metal" (i.e. without the presence of an operating system) and loads
  bitmaps directly from the hard drive to the video memory. See below for more
  information on how to use Teslerpoint on the Lisa.

* [`build_teslerpoint_presentation.py`](build_teslerpoint_presentation.py),
  a Python program that runs on a modern computer and assembles a collection of
  720x364 image files into a bootable Teslerpoint hard drive image. An Apple
  Lisa booting from this hard drive image will boot directly into a Teslerpoint
  slide show that pages through the image files. This program contains its own
  binary copy of the assembled `teslerpoint.x68` program. Refer to this
  program's --help text for more information.


Using Teslerpoint on the Lisa
-----------------------------

Upon booting from a hard drive image (or even an actual hard drive if you
arrange for this), Teslerpoint loads and displays the first bitmap. The user
interface is minimal: press space, `.`, or the mouse button to advance to the
next bitmap, `b` or `,` to go back to the previous bitmap, `>` to advance five
bitmaps ahead, or `<` to go back five bitmaps. It's not possible to go beyond
the last or first bitmaps. Press `Q` (note capital-Q) to quit to the ROM.
Teslerpoint ignores the power button: if you wish to turn off the Lisa, quit to
the ROM first and then press power.


Assembling Teslerpoint
----------------------

The software utilities used to assemble `teslerpoint.x68` include

* the [EASy68k command-line assembler](
  https://github.com/rayarachelian/EASy68K-asm) distributed by Ray Arachelian
  and
* the `srec_cat` utility from the [srecord project](
  http://srecord.sourceforge.net/),

The Makefile executes the step-by-step process of assembling a new
`teslerpoint.bin` binary and using that to construct a test Teslerpoint slide
show. You may need to edit the contents of the Makefile to specify the correct
path to your copy of the EASy68k command-line assembler.


Acknowledgements
----------------

This program was written mostly off-the-cuff, but the usual (and sincere!)
thanks goes out to documentation sites like
[Bitsavers](http://www.bitsavers.org) and [Ray Arachelian's Lisa documents
collection](https://lisa.sunder.net/books.html), as well as the fine LisaList2
community.


Nobody owns Teslerpoint
-----------------------

`teslerpoint.x68`, `build_teslerpoint_presentation.py`, and any supporting
programs, software libraries, and documentation distributed alongside them are
released into the public domain without any warranty. See the
[LICENSE](LICENSE) file for details.


Revision history
----------------

11 June 2024: Initial release.
(Tom Stepleton, stepleton@gmail.com, London)
