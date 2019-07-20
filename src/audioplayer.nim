import terminal

import rapid/audio/[device, sampler]

type
  Player = ref object of RSampler
    samples*: string
    pos*: int

method sample*(player: Player, dest: var seq[float], count: int) =
  dest.setLen(0)
  for i in 0..<count:
    if player.pos < player.samples.len:
      let
        sample =
          (player.samples[player.pos].uint8.float / high(uint8).float * 2 - 1)
      dest.add([sample, sample])
      player.pos.inc
    else:
      dest.add([0.0, 0.0])
  if player.pos >= player.samples.len:
    stderr.styledWriteLine(styleBright, fgGreen, " ✓ done!")
    quit(QuitSuccess)
