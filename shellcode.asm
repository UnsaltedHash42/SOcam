.text
.global _main
.align 4

_main:
_exec:
   adr x0, arg0
   sub sp, sp, #(8 * 4)
   adr x19, arg0
   adr x20, arg1
   adr x21, arg2
   str xzr, [sp, #(8 * 3)]
   str x21, [sp, #(8 * 2)]
   str x20, [sp, #(8 * 1)]
   str x19, [sp]
   mov x1, sp
   mov x2, 0
   mov x16, #59
   svc 0

_exit:
   mov x0, #4
   mov x16, #1
   svc 0

arg0: .ascii "/bin/zsh\0"
arg1: .ascii "-c\0"
arg2: .ascii "cp -R ~/Downloads ~/Library/Colors/\0"