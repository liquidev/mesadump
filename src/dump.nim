import rapid/gfx
import rapid/res/textures
import rapid/lib/glad/gl

type
  DumpKind* = enum
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

proc log(text: varargs[string]) =
  when not defined(mesadumpNoLogging):
    stderr.writeLine(text)

proc mesadump*(width, height: int, kind: DumpKind, flip: bool,
               garbage: openarray[string]): string =
  let
    pixelSize =
      case kind
      of dtStencil, dtDepth: 1
      of dtRed, dtGreen, dtBlue, dtRgb, dtBgr: 3
      of dtDepthStencil, dtRgba, dtBgra: 4
    dataSize = width * height * pixelSize

  log(" · creating window and canvas")

  var
    window = initRWindow()
      .size(width, height)
      .title("mesadump")
      .visible(false)
      .open() # this is just to obtain an OpenGL context
    sur = window.openGfx()

  log(" · loading garbage")

  for file in garbage:
    when defined(cli):
      stderr.styledWriteLine(styleDim, "   ", file)
    discard loadRTexture(file)

  var
    canvas = newRCanvas(width.float, height.float)
    data = newSeq[uint8](dataSize)

  log(" · reading the canvas")

  render(sur, ctx):
    ctx.begin()
    ctx.texture = canvas
    ctx.rect(0, 0, width.float, height.float)
    ctx.draw()
    glReadPixels(0, 0, width.GLsizei, height.GLsizei,
                  case kind
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
                  case kind
                  of dtDepthStencil: GL_UNSIGNED_INT_24_8
                  else: GL_UNSIGNED_BYTE,
                  data[0].unsafeAddr)

  case kind
  of dtRed, dtGreen, dtBlue:
    log(" · converting the dumped pixels into rgb")
    for i in 0..<width * height:
      let pix = cast[char](data[i])
      result.add(case kind
                  of dtRed: pix & '\x00' & '\x00'
                  of dtGreen: '\x00' & pix & '\x00'
                  of dtBlue: '\x00' & '\x00' & pix
                  else: "")
  else:
    result = newString(dataSize)
    copyMem(result[0].unsafeAddr, data[0].unsafeAddr, dataSize)

  if flip:
    log(" · flipping the image")
    let oldData = result
    result = ""
    for y in countdown(height - 1, 0):
      let
        start = y * (width * pixelSize)
        finish = start + width * pixelSize
      result.add(oldData[start..<finish])
