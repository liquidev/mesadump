import os
import parseopt
import strutils
import terminal

import rapid/lib/glad/gl
import rapid/gfx
import rapid/res/textures
import nimPNG

include audioplayer

type
  DumpKind = enum
    dtStencil = "stencil"
    dtDepth = "depth"
    dtDepthStencil = "depth+stencil"
    dtRed = "red"
    dtGreen = "green"
    dtBlue = "blue"
    dtRgb = "rgb"
    dtBgr = "bgr"
    dtRgba = "rgba"
    dtBgra = "bgra"

var
  dumpWidth = 256
  dumpHeight = 256
  dumpKind = dtRgb
  dumpFilename = "mesadump.png"
  dumpFlip = true
  garbage: seq[string]
  dumpSound = false

const
  Version = "0.3.1"
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
  they're very likely to be included in your mesadump. usage:
    $1 --garbage:list_of_files.png:separated_by_colons.png

notes:
  · this only works on mesa drivers, on nvidia this will produce blank images
    since the driver clears freshly created textures and renderbuffers
  · the depth+stencil kind is special, it will dump the depth buffer into the
    rgb channels and the stencil buffer into the alpha channel
"""

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

let
  pixelSize =
    case dumpKind
    of dtStencil, dtDepth: 1
    of dtRed, dtGreen, dtBlue, dtRgb, dtBgr: 3
    of dtDepthStencil, dtRgba, dtBgra: 4
  dataSize = dumpWidth * dumpHeight * pixelSize

stderr.styledWriteLine(" · creating window and canvas")

var
  window = initRWindow()
    .size(dumpWidth, dumpHeight)
    .title("mesadump")
    .visible(false)
    .open() # this is just to obtain an OpenGL context
  sur = window.openGfx()

stderr.styledWriteLine(" · loading garbage")

for file in garbage:
  stdout.styledWriteLine(styleDim, "   ", file)
  discard loadRTexture(file)

var
  canvas = newRCanvas(dumpWidth.float, dumpHeight.float)
  data = newSeq[uint8](dataSize)

stderr.styledWriteLine(" · reading the canvas")

render(sur, ctx):
  ctx.begin()
  ctx.texture = canvas
  ctx.rect(0, 0, dumpWidth.float, dumpHeight.float)
  ctx.draw()
  glReadPixels(0, 0, dumpWidth.GLsizei, dumpHeight.GLsizei,
                case dumpKind
                of dtStencil: GL_STENCIL_INDEX
                of dtDepth: GL_DEPTH_COMPONENT
                of dtDepthStencil: GL_DEPTH_STENCIL
                of dtRed: GL_RED
                of dtGreen: GL_GREEN
                of dtBlue: GL_BLUE
                of dtRgb: GL_RGB
                of dtBgr: GL_BGR
                of dtRgba: GL_RGBA
                of dtBgra: GL_BGRA,
                case dumpKind
                of dtDepthStencil: GL_UNSIGNED_INT_24_8
                else: GL_UNSIGNED_BYTE,
                data[0].unsafeAddr)

var dataStr = ""

case dumpKind
of dtRed, dtGreen, dtBlue:
  stderr.styledWriteLine(" · converting the dumped pixels into rgb")
  for i in 0..<dumpWidth * dumpHeight:
    let pix = cast[char](data[i])
    dataStr.add(case dumpKind
                of dtRed: pix & '\x00' & '\x00'
                of dtGreen: '\x00' & pix & '\x00'
                of dtBlue: '\x00' & '\x00' & pix
                else: "")
else:
  dataStr = newString(dataSize)
  copyMem(dataStr[0].unsafeAddr, data[0].unsafeAddr, dataSize)

if dumpFlip:
  stderr.styledWriteLine(" · flipping the image")
  let oldData = dataStr
  dataStr = ""
  for y in countdown(dumpHeight - 1, 0):
    let
      start = y * (dumpWidth * pixelSize)
      finish = start + dumpWidth * pixelSize
    dataStr.add(oldData[start..<finish])

if not dumpSound:
  stderr.styledWriteLine(" · saving png")
  if not savePNG(dumpFilename, dataStr,
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
    player = Player(samples: dataStr)
  dev.attach(player)
  stderr.styledWriteLine(" · playing")
  dev.start()
  while true:
    dev.wait()

stderr.styledWriteLine(styleBright, fgGreen, " ✓ done!")
