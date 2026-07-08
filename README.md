# 32-bit x86 Assembly — Bubble Sort

A low-level implementation of the Bubble Sort algorithm in 32-bit x86 Assembly, accompanied by a C reference implementation. The project demonstrates manual stack-based memory management, Position-Independent Code (PIC), strict register discipline, and the practical differences between two assembly environments: a standalone Windows executable and a shellcode-style binary loaded by a custom runtime.

---

## Files

| File | Description |
|---|---|
| `bubble.c` | High-level C reference — serves as the logical blueprint for both assembly versions. |
| `bubble-exe.asm` | Standard x86 Assembly executable for Windows (assembled with NASM and linked with GoLink). |
| `bubble.asm` | Position-Independent, shellcode-style binary designed for [asmloader](https://gynvael.coldwind.pl/?id=387). |

---

## Sample Session

Both assembly versions and the C program behave identically from the user's perspective. The application reads integers separated by spaces until the user presses `Enter`, sorts them, and prints the result.

```text
numbers: 8 3 14 1 9
sorted: 1 3 8 9 14
```


Invalid input (such as letters or symbols) is silently discarded, the input buffer is cleared, and the program restarts the prompt.

---

## Theoretical Background

Understanding this codebase requires familiarity with the CPU architecture, register conventions, and stack operations in 32-bit x86 environments.

### Registers

In 32-bit (IA-32) mode, we utilize eight general-purpose registers: EAX, EBX, ECX, EDX, ESI, EDI, EBP, and ESP. Each register can be addressed at different widths:

```text
EAX  (32-bit)
 AX  (lower 16 bits of EAX)
 AH  (upper 8 bits of AX)
 AL  (lower 8 bits of AX)
```

Important: When pushing values to the stack or passing them as function arguments, always use the full 32-bit register. Passing an 8-bit value directly causes alignment problems in 32-bit calling conventions, as the stack expects 4-byte (DWORD) aligned entries.

Registers have specific roles by convention in this project:

### Register usage in this project

| Register | Description |
|----------|-------------|
| **EAX** | Return value of function calls; accumulator for arithmetic operations. |
| **EBX** | General purpose – holds the pointer to the API table used by the C library functions. <br> **⚠️ Must never be overwritten** in `bubble.asm` (or any other version that relies on the API table). |
| **ECX** | Loop counter (used implicitly by the `loop` instruction). |
| **EDX** | General purpose; highly volatile across function calls. |
| **ESI** | Source pointer – stores the start address of the array being sorted. |
| **EDI** | Destination / iteration pointer used during the sorting passes. |
| **EBP** | Re‑used as an integer counter (tracks the number of elements read). |
| **ESP** | Stack pointer – always points to the top of the stack. |

**Volatile Registers**: EAX, ECX, and EDX are overwritten by calls to standard C functions like printf or scanf. Any value that must survive a function call needs to be saved in EBX, ESI, EDI, or EBP, or temporarily pushed to the stack.


### Why **EBX** must stay intact

`bubble.asm` (the position‑independent version) loads the **API table** – a structure that contains pointers to the C runtime functions (`printf`, `malloc`, `free`, …).  
The loader (or the tiny stub that jumps into the shellcode) expects `EBX` to keep that table address for the whole lifetime of the payload. Overwriting `EBX` would:

1. Lose the reference to the API table.  
2. Cause any subsequent call to a C library routine to jump to a garbage address → crash or undefined behaviour.

If you need a temporary scratch register, use `EAX`, `ECX`, `EDX` (remember they are volatile) **or** push a value onto the stack and pop it later.

## Quick checklist for safe assembly coding

- **Never modify `EBX`** unless you first save the original value (e.g., `push ebx … pop ebx`).  
- Use `push dword <reg>` / `pop <reg>` for all stack operations – never `push al` or `push bl`.  
- Save any value that must survive a C call in `EBX`, `ESI`, `EDI`, or `EBP`.  
- Restore the stack pointer (`ESP`) to its original value before returning from a function.  

## The Stack

The stack grows **downward** – toward lower memory addresses.  
`ESP` always points to the **topmost (lowest‑address) element** currently on the stack.

### Layout (plain‑text diagram)

``` text

high addresses
  ...
  [ret]         <- return address (pushed by the caller / asmloader)
  [arr[0]]      <- first element read
  [arr[1]]      <- second element read
  ...
  [arr[n]]      <- last element read   <- ESP points here
low addresses

```


### Allocating space on the stack  *(no `malloc` needed)*

```asm
; Allocating space on the stack (no malloc needed)
sub esp, 4        ; reserve 4 bytes (one `int`) on the stack 

; Freeing space (no "free" (c function) needed)
add esp, 4        ; discard the previously reserved 4 bytes
```

### Cleaning up after a function call
Standard C functions use the cdecl calling convention: the caller must remove the arguments it pushed.

```asm
push format       ; 4 bytes – address of the format string
push esp          ; 4 bytes – pointer to the integer to read
call scanf        ; scanf reads one int
add esp, 4*2      ; discard both arguments (8 bytes total)
```

### The Call Trick (Position‑Independent Strings)
Why we need it

- In bubble-exe.asm the binary is linked, so string literals live in a .data section and can be referenced by a fixed label:

    ```asm
    push format       ; address known at link time
    call scanf
    ```

- In bubble.asm the code is position‑independent shellcode loaded by asmloader at an unpredictable address. There is no .data section, so push format would embed a hard‑coded address that becomes invalid at runtime.

### The trick

The call instruction automatically pushes the address of the **next instruction** onto the stack before jumping.
If we place the string **immediately after the call**, the pushed return address is exactly the runtime address of the string – the perfect argument for functions like printf/scanf.

```asm

        call get_format      ; pushes the address of the next byte (the string) onto the stack
format: db "%d", 0           ; the actual format string, right after the call
get_format:                  ; execution continues here after the string
        ; at this point the top of the stack holds the correct address of `format`
        ; you can now call scanf/printf without an explicit `push format`

```

No explicit push is required, making the code fully position‑independent and safe to run from any memory location.

## Quick Recap

| Operation                                   | Assembly snippet |
|---------------------------------------------|------------------|
| Reserve space for one **int**               | `sub esp, 4` |
| Release that space                          | `add esp, 4` |
| Call a C function (**cdecl**) and clean up  | <pre>push arg1<br>push arg2<br>call func<br>add esp, 8</pre> |
| Position‑independent string argument        | <pre>call get_fmt<br>fmt: db "...",0<br>get_fmt:</pre> |


##  EBX API Table (bubble.asm only)


`bubble.asm` is a **shell‑code‑style** binary – it has **no external symbols**.  
Before jumping to the program’s entry point, the loader places a pointer to a **table of standard C function pointers** in the **EBX** register.

All I/O (and the only way to call any library routine) must go through this table.  
Because EBX is the sole gateway, **never overwrite it** – use other registers (ESI, EDI, EBP) for temporary data or state.

---

### Table Layout

| Offset (bytes) | Index | Function | Description |
|----------------|-------|----------|-------------|
| `ebx + 0`      | 0     | `exit`   | Terminate the process |
| `ebx + 4`      | 1     | `putchar`| Write a single character to stdout |
| `ebx + 8`      | 2     | `getchar`| Read a single character from stdin |
| `ebx + 12`     | 3     | `printf` | Formatted output |
| `ebx + 16`     | 4     | `scanf`  | Formatted input |

*Each entry is a **4‑byte pointer** (32‑bit mode).*

---

### Calling a Function

Use the `call [ebx + index*4]` syntax.  
Below are the most common calls used by `bubble.asm`:

```asm
; call printf   (index 3)
call [ebx + 3*4]

; call scanf    (index 4)
call [ebx + 4*4]

; call getchar  (index 2)
call [ebx + 2*4]

; call exit     (index 0)
call [ebx + 0*4]
```

Tip:

- Push arguments right‑to‑left (cdecl convention) before the call.
- Clean the stack after the call (add esp, N) because the functions use the cdecl calling convention.

Why EBX Must Stay Intact:
- EBX is the only reference to the loader‑provided API.
- Overwriting EBX would lose the function table, causing any subsequent I/O call to jump to garbage.
- Consequently, the code keeps EBX constant for the whole program and relies on ESI, EDI, and EBP for any temporary storage or loop counters.

## Code Walkthrough (High‑Level)
###  1. C Reference (bubble.c)

```c
int capacity = 2;
int count = 0;
int *arr = malloc(capacity * sizeof(int));
```

- The C version allocates a dynamic array on the heap.
- The assembly version allocates on the stack by repeatedly sub esp, 4 (or push).

### 2. Input Loop

```c
while (1) {
    int n, result;
    result = scanf("%d", &n);
    if (result != 1) {
        clear_input();
        goto start;
    }
    /* … */
    int c = getchar();
    if (c == '\n') break;
    else if (c != ' ') { clear_input(); goto start; }
}
```

- scanf returns the number of successfully read items.
- If it isn’t 1, the input is invalid → clear the input buffer and restart.
- getchar reads the delimiter:
    - ' ' → continue reading numbers.
    - '\n' → end of the list.
    - Anything else → error → clear and restart.

The assembly mirrors this logic with cmp, jne, je branches.

### 3. Sorting (Bubble Sort)

- **Outer loop counter** → ECX (saved on the stack across iterations).
- **Inner‑loop pointer** → EDI.
- Handling the loop counters automatically.

###  Quick Checklist for Modifying bubble.asm

|  Item            | What to Verify                                                                                                 |
|--------------------|-----------------------------------------------------------------------------------------------------------------|
| **EBX preserved** | No `mov ebx, …` or `push ebx / pop ebx` that changes its value.                                                 |
| **Argument order**| Arguments pushed **right‑to‑left** before each call.                                                            |
| **Stack cleanup** | After each cdecl call, `add esp, N` where **N = 4 × args**.                                                   |
| **Register usage**| Use **ESI / EDI / EBP** for temporary data; keep **EBX** untouched.                                            |
| **Delimiter handling**| `getchar` result must be compared to `' '` and `'\n'` exactly as shown.                                   |
| **Dynamic growth**| If you need to expand the array, keep the same `sub esp, 4` pattern (or allocate on the heap via a wrapper). |

## Assembly Deep Dive (bubble.asm)

 ### Input Loop & Dynamic Stack Allocation

```asm
 ; ---------- read_loop ----------
read_loop:
    sub     esp, 4          ; allocate 4 bytes for the next integer
    push    esp             ; push pointer to that slot (scanf needs &n)

    call    get_format
    ; -----------------------------
    ; format string (null‑terminated)
    format:     db "%d", 0
    ; --------------------------------
    get_format:
        call    [ebx+4*4]   ; scanf("%d", &slot)
        add     esp, 4*2    ; discard format pointer and &slot
; --------------------------------------------------------------
```
*`After add esp, 4*2 the arguments are cleaned up, but the value written by scanf stays on the stack – it becomes a permanent array element.`*

### Bubble Sort In‑Place

```asm 

; ---------- inner_loop ----------
inner_loop:
    mov     eax, [edi]        ; load element at EDI
    mov     edx, [edi+4]      ; load next element
    cmp     eax, edx
    jle     .no_swap          ; already in order -> skip swap

    ; ---- swap ----
    mov     [edi], edx        ; store next element at current slot
    mov     [edi+4], eax      ; store current element at next slot
.no_swap:
    add     edi, 4            ; advance pointer to next pair
    loop    .inner_loop       ; ECX--, repeat while ECX ≠ 0
; --------------------------------------------------------------

```

*The array lives on the stack in reverse insertion order.*

*The sort works directly on this memory using [edi] and [edi+4].*

*Because both the outer and inner loops need a counter, the outer ECX counter is pushed before the inner loop starts and popped afterward so it isn’t overwritten.*

### Output (Printing the Sorted Array)

```asm

; ---------- print_loop ----------
print_loop:
    call    get_format2

    ; -----------------------------

    format2:    db "%d ", 0

    ; --------------------------------

    get_format2:
        call    [ebx+3*4]   ; printf("%d ", arr[n])
        add     esp, 4*2    ; discard format pointer and pop one array element
; --------------------------------------------------------------

```

*Adding 8 to ESP after printf cleans up the string‑pointer argument **and** “pops” the printed element off the stack.*
*Printing from the top of the stack down therefore yields the numbers in **ascending order**.*

##  Stand‑alone Executable (bubble‑exe.asm)
The core algorithm is identical to bubble.asm; the differences are purely environmental:


| Aspect                | Details                                                                                                   |
|-----------------------|-----------------------------------------------------------------------------------------------------------|
| **Strings**           | Stored in a `.data` section with fixed labels.                                                            |
| **Position‑independence** | None. Relies on standard fixed‑address linking (no Call Trick).                                          |
| **External symbols**  | Declares `extern printf`, `extern scanf`, `extern exit`, etc.                                             |
| **API table**         | Not used. Calls standard imported functions directly (does not use `[ebx + N*4]`).                        |
| **Entry point**       | `global main` (standard entry point for the OS / C runtime).                                             |
| **Target**            | Standard Windows PE executable (stand‑alone).                                                             |
| **Runtime**           | Windows OS directly (linked dynamically with `msvcrt.dll`).                                              |


## Building & Execution

### bubble‑exe.asm (Windows, Standalone)  
*Requires NASM and GoLink.*

| Platform | Command |
|----------|---------|
| **Windows**  | `nasm bubble-exe.asm -o bubble-exe.obj -f win32` |
|          | `golink /console /entry main bubble-exe.obj msvcrt.dll` |
|          | `bubble-exe.exe` |

### bubble.asm (asmloader)  
*Requires NASM and the asmloader by Gynvael Coldwind.*

| Platform | Command |
|----------|---------|
| **Windows**  | `nasm bubble.asm -o bubble.bin -f bin` |
|          | `asmloader.exe bubble.bin` |

### bubble.c (Cross‑Platform)

| Platform | Command |
|----------|---------|
| **Bash** | `gcc bubble.c -o bubble` |
|          | `./bubble` |

---

## References

-   [**asmloader by Gynvael Coldwind**](https://gynvael.coldwind.pl/?id=387) – The custom runtime used by `bubble.asm`.  


-   [**Intel 64 and IA‑32 Architectures Software Developer Manuals**](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) – Comprehensive instruction‑set reference.  


- [**NASM Documentation**](https://www.nasm.us/doc/) – Official NASM reference manual.  
  
