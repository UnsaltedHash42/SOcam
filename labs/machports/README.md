# Mach ports — class samples

Small C / asm sources used alongside the Mach microkernel / injection narrative. Filenames match historical class copies (including `reciver.c` spelling).

**Primary student lab path** for the dylib track is [`../dylib-injection/README.md`](../dylib-injection/README.md).

## Contents

- `sender.c`, `reciver.c` — basic Mach port demos  
- `loader.asm`, `shellcode.asm`, `toinject.c` — injection pipeline pieces  
- `cyberduck-inject.m`, `cyberduck-inject-dylib.m` — alternate entry points (compare with `dylib-injection/` versions)  
- `shellcode-root.asm` — copy of legacy root-level shellcode sample (if present)  

Build instructions: follow your week-2 session doc or ask the instructor; these files are support material, not a standalone graded lab unless assigned.
