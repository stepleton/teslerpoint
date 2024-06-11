#!/usr/bin/python3
"""Teslerpoint slide carousel system: modern computer-side program

Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.

"Teslerpoint" is system for displaying bitmap images on the screen of an Apple
Lisa computer. It comprises:

* `teslerpoint.x68`, a small program that runs on the Lisa's "bare metal"
  (i.e. without the presence of an operating system) and loads bitmaps directly
  from the hard drive to the video memory. See that file or README.md for more
  information on the operation of that program.

* This program, which runs on a modern computer and assembles a collection of
  720x364 image files into a bootable Teslerpoint hard drive image. An Apple
  Lisa booting from this hard drive image will boot directly into a Teslerpoint
  slide show that pages through the image files. This program contains its own
  binary copy of the assembled `teslerpoint.x68` program. Refer to the --help
  text for more information.

This program is released into the public domain without any warranty. For
details, refer to the LICENSE file distributed with this program, or, if it's
missing, to:
  - https://github.com/stepleton/teslerpoint/blob/main/LICENSE
For further information, visit http://unlicense.org.

This program originated at https://github.com/stepleton/teslerpoint, and may
have been modified if obtained elsewhere.

It was written mostly off-the-cuff, but the usual (and sincere!) thanks goes
out to documentation sites like http://www.bitsavers.org and
https://lisa.sunder.net/books.html, as well as the fine LisaList2 community.

Dependencies
------------

The PIL imaging library is used to load slide image files; the [Lisa parallel
port hard drive bootloader](https://github.com/stepleton/bootloader_hd) creates
bootable Apple Lisa drive images.

Revision history
----------------
This section records the development of this file as part of the `teslerpoint`
project at <http://github.com/stepleton/teslerpoint>.

11 June 2024: Initial release.
(Tom Stepleton, stepleton@gmail.com, London)
"""


import argparse
import base64
import PIL.Image
import struct
import sys
import textwrap

from typing import MutableSequence, Sequence, Tuple

from bootloader_hd import build_bootable_disk_image as build_image


def _define_flags():
  """Defines an `ArgumentParser` for command-line flags used by this program."""
  flags = argparse.ArgumentParser(
      description='Build a Teslerpoint hard disk image from slide image files')

  flags.add_argument('image', nargs='+',
                     help=('Images to assemble into a slide show. Must be '
                           '720x364 and in an image format supported by PIL. '
                           'Will be converted into black-and-white images '
                           'using Floyd-Steinberg dithering. The images will '
                           'be compiled into a slideshow in the order '
                           'specified.'),
                     type=str)

  flags.add_argument('-f', '--format',
                     help=('Target format for hard drive image file: dc42 is a '
                           'Disk Copy 4.2 file suitable for use with LisaEm; '
                           'blu is a disk image suitable for use with the '
                           'Basic Lisa Utility, raw is a sequential collection '
                           'of block data suitable for use with the '
                           'Cameo/Aphid hard drive emulator and with IDLE, and '
                           'usbwidex is a disk image suitable for use with the '
                           'UsbWidEx hard drive diagnostic tool.'),
                     choices=build_image.IMAGE_FORMATS,
                     default='dc42')

  flags.add_argument('-d', '--device',
                     help=('Create an image for a particular device; note that '
                           'this flag primarily determines the default number '
                           'of blocks on the device and otherwise only affects '
                           'the formatting of "blu" disk images'),
                     choices=build_image.DEVICES,
                     default='profile')

  flags.add_argument('-o', '--output',
                     help=('Where to write the resulting disk image; if '
                           'unspecified, the image is written to standard out'),
                     type=argparse.FileType('xb'))

  flags.add_argument('-t', '--teslerpoint',
                     help=('"Teslerpoint" software as a binary file '
                           'containing MC68000 machine code; if unspecified, '
                           'a built-in copy of Teslerpoint will be used'),
                     type=argparse.FileType('rb'))

  return flags


# This built-in teslerpoint binary is the version released on TODO.
_BUILT_IN_TESLERPOINT = textwrap.dedent("""\
    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""")


def place_image(
    image: PIL.Image.Image,
    slide_number: int,
    tags: MutableSequence[bytes],
    data: MutableSequence[bytes],
) -> Tuple[MutableSequence[bytes], MutableSequence[bytes]]:
  """Place a graphical image into a Teslerpoint hard drive image.

  Args:
    image: A 720x364 pixel PIL image, which will be converted to a
        black-and-white bitmap using PIL's built-in Floyd-Steinberg dithering.
    slide_number: Place the bitmap on the drive image in the location where the
        slide_number'th slide should go.
    tags: A list of 20-byte binary tags for the drive image; the drive image
        must already have a bootloader and a loadable program (ideally the
        teslerpoint.x68 binary or why are we here?) written to it.
    data: A list of 512-byte binary data blocks for the drive image; see note
        on the `tags` argument.

  Returns: The `tags` and `data` arguments, just for convenience's sake.
  """
  if image.size != (720, 364): raise ValueError(
      f'Teslerpoint slide images must be 720x364, not {image.width}x'
      f'{image.height}.')

  # Convert the image to black-and-white (where 0 is white and 1 is black) and
  # get raw bytes.
  raw_bytes = image.convert('1').point(lambda x: 255 - x).tobytes()

  # Find the block index where data for the first slide begins, then jump from
  # there to the block where data for the slide_number'th slide begins.
  first_block = _block_index_of_first_slide(tags) + 62 * slide_number

  # Copy raw slide bytes into the drive image. The first 61 chunks will fill up
  # entire blocks.
  for i in range(61):
    chunk_start = i * 532
    tags[first_block + i] = raw_bytes[chunk_start:chunk_start+20]
    data[first_block + i] = raw_bytes[chunk_start+20:chunk_start+532]
  # The final chunk will only fill part of a block, so we must pad.
  chunk_start = 61 * 532
  tags[first_block + 61] = raw_bytes[chunk_start:chunk_start+20]
  data[first_block + 61] = raw_bytes[chunk_start+20:] + b'\x00' * 224
  assert len(data[first_block + 61]) == 512

  # Return tags and data for convenience, I guess.
  return tags, data


def _block_index_of_first_slide(tags: Sequence[bytes]) -> int:
  """Identify the block that should hold the beginning of the first bitmap.

  Uses a linear search through the block tags, but in nearly all cases the
  first block will be near the beginning of the drive image.

  Args:
    tags: Block tags for the hard drive image that will host this Teslerpoint
        slide show.

  Returns: Block index of the block that shold be used as the first block of
      the first bitmap in the slide show.
  """
  for i, tag in enumerate(tags):
    if tag.endswith(build_image.TAG_FOR_LAST_BLOCK): return i + 1
  else: raise RuntimeError(
      'Drive image under construction appears not to make use of the '
      '"bootloader_hd" hard drive bootloader? Giving up.')


def main(FLAGS):
  # No output file listed? Use stdout in binary mode.
  output_file = FLAGS.output or sys.stdout.buffer

  # Load the Teslerpoint binary and make block tags and data for a drive image
  # that boots it.
  teslerpoint = (FLAGS.teslerpoint.read() if FLAGS.teslerpoint else
                 base64.decodebytes(bytes(_BUILT_IN_TESLERPOINT, 'ascii')))
  tags, data = build_image.make_tags_and_data(FLAGS.device, teslerpoint)

  # Load and place all images into the file.
  for i, image_filename in enumerate(FLAGS.image):
    with PIL.Image.open(image_filename) as image:
      place_image(image, i, tags, data)

  # Update the first block and number of slides values stored at the head of
  # the Teslerpoint program.
  first_block = _block_index_of_first_slide(tags)
  num_slides = len(FLAGS.image)
  if data[2][2:4] != b'\xa5\xa5': raise ValueError(
      "The teslerpoint binary's third and fourth bytes aren't $A5A5; not sure "
      'where to sub in the presentation length')
  if data[2][4:7] != b'\x5a\x5a\x5a': raise ValueError(
      "The teslerpoint binary's fifth through sixth bytes aren't $5A5A5A; not "
      "sure where to sub in the presentation's first block")
  data[2] = (data[2][:2] +
             struct.pack('>H', num_slides) +
             struct.pack('>L', first_block)[1:] +
             data[2][7:])

  # Update the checksum for the block containing the head of the Teslerpoint
  # program so that the bootloader will still load it. Note that the bootloader
  # will never (we hope!) occupy more than two blocks.
  tags[2] = build_image.checksum(data[2]) + tags[2][2:]

  # Save the resulting hard drive image.
  drive_image = build_image.make_drive_image(
      tags, data, FLAGS.format, FLAGS.device)
  output_file.write(drive_image)


if __name__ == '__main__':
  flags = _define_flags()
  FLAGS = flags.parse_args()
  main(FLAGS)
