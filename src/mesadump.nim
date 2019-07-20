import os
import parseopt
import strutils
import terminal

import nimPNG

include audioplayer
include dump

when isMainModule:
  var
    dumpWidth = 256
    dumpHeight = 256
    dumpKind = dtRgb
    dumpFilename = "mesadump.png"
    dumpFlip = true
    garbage: seq[string]
    dumpSound = false

  const
    Version = "0.3.2"
    Help = """
mesadump v""" & Version & '\n' & """
„because dumping vram into pngs and sound is something we all need in our lives”

usage:
  $1 [options] [filename.png]
  default filename: mesadump.png

options:
  -w:256 --width:256      set the width of the dump
  -h:256 --height:256     set the height of the dump
  -k:rgb --kind:rgb       set what to dump
  --flip:n                flip the dump vertically
  --garbage:[files]       see below
  -s, --sound             play as sound instead of saving to a file

dump kinds:
  png format  |  dump kind
  ----------  |  --------------------------
  grayscale   |  stencil, depth
  rgb         |  red, green, blue, rgb, bgr
  rgba        |  rgba, bgra, depth+stencil

garbage:
  mesadump is capable of loading some garbage PNG files into VRAM so that
  they're more likely to be included in your mesadump. usage:
    $1 --garbage:list_of_files.png:separated_by_colons.png

notes:
  · this only works on mesa drivers, on nvidia this will produce blank images
    since the driver clears freshly created textures and renderbuffers
  · the depth+stencil kind is special, it will dump the depth buffer into the
    rgb channels and the stencil buffer into the alpha channel"""

  stderr.styledWriteLine(styleBright, "mesadump v" & Version)

  for kind, key, val in getopt(commandLineParams()):
    if kind in {cmdShortOption, cmdLongOption}:
      case key
      of "help": quit(Help % [paramStr(0)], QuitSuccess)
      of "w", "width": dumpWidth = val.parseInt
      of "h", "height": dumpHeight = val.parseInt
      of "k", "kind": dumpKind = val.parseEnum[:DumpKind]
      of "flip": dumpFlip = val.parseBool
      of "garbage":
        for file in split(val, ':'):
          garbage.add(file)
      of "s", "sound": dumpSound = true
    elif kind == cmdArgument:
      dumpFilename = key

  let dump = mesadump(dumpWidth, dumpHeight, dumpKind, dumpFlip, garbage)

  if not dumpSound:
    stderr.styledWriteLine(" · saving png")
    if not savePNG(dumpFilename, dump,
                  case dumpKind
                  of dtStencil, dtDepth: LCT_GREY
                  of dtRed, dtGreen, dtBlue, dtRgb, dtBgr: LCT_RGB
                  of dtDepthStencil, dtRgba, dtBgra: LCT_RGBA,
                  8, dumpWidth, dumpHeight):
      quit("error: could not write PNG", 1)
  else:
    stderr.styledWriteLine(" · opening audio device")
    var
      dev = newRAudioDevice("mesadump")
      player = Player(samples: dump)
    dev.attach(player)
    stderr.styledWriteLine(" · playing")
    dev.start()
    while true:
      dev.poll()

  stderr.styledWriteLine(styleBright, fgGreen, " ✓ done!")
