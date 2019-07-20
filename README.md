# mesadump

> because dumping vram into pngs and sound is something we all need in our lives

## Usage

```
mesadump --help
```

When no arguments are provided, mesadump will create a 256×256 RGB file called
`mesadump.png`.

## Note

This only works on Mesa graphics drivers on Linux (or generally any drivers that
don't clear textures and renderbuffers upon creation). Nvidia drivers are not
supported, since they clear new textures with zeroes.

## Compiling

```
git clone https://github.com/liquid600pgm/mesadump
nimble install
```
