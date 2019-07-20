import os
import parseopt
import strutils
import terminal
import times

import nimPNG

include audioplayer
include dump

when isMainModule:
  type
    ArgMode = enum
      argGarbage
      argOutput

  var
    dumpWidth = 256
    dumpHeight = 256
    dumpKind = dtRgb
    dumpFilename = "mesadump.png"
    dumpFlip = true
    garbage: seq[string]
    repeatGarbage = 2
    dumpSound = false

  const
    Version = "0.2.1"
    GeneralHelp = """
mesadump v""" & Version & '\n' & """
„because dumping vram into pngs and sound is something we all need in our lives”

usage:
  $1 [options] [--] [output file]
  default filename: mesadump.png

options:
  --help.[topic]       get help about a specific topic
  -v --version         print the version
  -w:256 --width:256   set the width of the dump
  -h:256 --height:256  set the height of the dump
  -k:rgb --kind:rgb    set what to dump, see --help.dumpKind
  --flip:n             flip the dump vertically
  --garbage [files]    see --help.garbage
  --repeatGarbage:2    load garbage this many times
  -s, --sound          play as sound instead of saving to a file"""
    DumpKindHelp = """
available dumps:
  png format | dump kind
  ---------- | --------------------------
  grayscale  | stencil, depth
  rgb        | red, green, blue, rgb, bgr
  rgba       | rgba, bgra, depth+stencil"""
    GarbageHelp = """
garbage:
  mesadump is capable of loading some garbage png files into vram so that
  they're more likely to be included in your mesadump. usage:
    $1 --garbage list_of_files.png separated_by_spaces.png -- out.png
  one can also specify the number of times a specific texture should be loaded
  into vram, using the --repeatGarbage option."""
    VersionInfo = """
mesadump v""" & Version & '\n' & """
copyright (c) iLiquid, 2019

this open-source software comes with absolutely no warranty!
read the license here:
  https://github.com/liquid600pgm/mesadump/blob/master/LICENSE
"""

  stderr.styledWriteLine(styleBright, "mesadump v" & Version)

  var argMode = argOutput
  for kind, key, val in getopt(commandLineParams()):
    if kind in {cmdShortOption, cmdLongOption}:
      case key
      of "": argMode = argOutput
      of "help": quit(GeneralHelp % [paramStr(0)], QuitSuccess)
      of "help.dumpKind": quit(DumpKindHelp, QuitSuccess)
      of "help.garbage": quit(GarbageHelp, QuitSuccess)
      of "v", "version": quit(VersionInfo, QuitSuccess)
      of "w", "width": dumpWidth = val.parseInt
      of "h", "height": dumpHeight = val.parseInt
      of "k", "kind": dumpKind = val.parseEnum[:DumpKind]
      of "flip": dumpFlip = val.parseBool
      of "garbage": argMode = argGarbage
      of "repeatGarbage": repeatGarbage = val.parseInt
      of "s", "sound": dumpSound = true
    elif kind == cmdArgument:
      case argMode
      of argOutput: dumpFilename = key
      of argGarbage: garbage.add(key)

  let dump = mesadump(dumpWidth, dumpHeight, dumpKind, dumpFlip,
                      garbage, repeatGarbage)

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
    var
      time = epochTime()
    while true:
      dev.poll()
      if stderr.isatty:
        if epochTime() - time > 0.05:
          stderr.styledWrite(styleDim, styleBright, "   ",
                             $int(player.pos / player.samples.len * 100), "% ",
                             resetStyle, styleDim, $player.pos, " / ",
                             $player.samples.len, "\r")
          time = epochTime()
      if player.pos >= player.samples.len:
        if stderr.isatty:
          stderr.eraseLine()
        break

  stderr.styledWriteLine(styleBright, fgGreen, " ✓ done!")
