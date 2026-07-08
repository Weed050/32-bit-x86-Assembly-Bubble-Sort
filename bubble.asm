[bits 32]

;        esp -> [ret]  ; ret - return address to asmloader
start:

         call get_prompt  ; push on the stack the run-time address of prompt_str and jump to get_prompt
prompt_str:
         db "numbers: ", 0

get_prompt:

;        esp -> [prompt_str][ret]

         call [ebx+3*4]  ; printf(prompt_str);
         add esp, 4*1    ; esp = esp + 4

;        esp -> [ret]

         mov ebp, 0  ; ebp = 0 

read_loop:
         sub esp, 4  ; esp = esp - 4

;        esp -> [arr[n]]...[arr[0]][ret]

         push esp  ; esp -> stack

;        esp -> [esp][arr[n]]...[arr[0]][ret]

         call get_format  ; push on the stack the run-time address of format and jump to get_format
format:
         db "%d", 0
get_format:

;        esp -> [format][esp][arr[n]]...[arr[0]][ret]

         call [ebx+4*4]  ; scanf(format, esp)
         add esp, 4*2    ; esp = esp + 8
         
;        esp -> [arr[n]]...[arr[0]][ret]

         cmp eax, 1       ; eax - 1           ; OF SF ZF AF PF CF affected
         jne error_input  ; jump if not equal ; jump if ZF = 0

         inc ebp  ; ebp++

         call [ebx+2*4]  ; getchar()

         cmp eax, ' '    ; eax - ' '     ; OF SF ZF AF PF CF affected
         je read_loop    ; jump if equal ; jump if ZF = 1

         cmp eax, 0xA     ; eax - '\n'        ; OF SF ZF AF PF CF affected
         jne error_input  ; jump if not equal ; jump if ZF = 0

         cmp ebp, 2      ; eax - '\n'    ; OF SF ZF AF PF CF affected
         jb finish_sort  ; jump if below ; jump if CF = 1

         mov esi, esp  ; esi = esp

         mov ecx, ebp  ; ecx = ebp
         dec ecx       ; ecx--

.outer_loop:
         push ecx  ; ecx -> stack
         
;        esp -> [ecx][arr[n]]...[arr[0]][ret]

         mov edi, esi  ; edi = esi

.inner_loop:
         mov eax, [edi]      ; eax = *(int*)edi
         mov edx, [edi + 4]  ; edx = *(int*)(edi + 4)

         cmp eax, edx     ; eax - edx             ; OF SF ZF AF PF CF affected
         jle .no_swap     ; jump if less or equal ; jump if SF != OF or ZF = 1

         mov [edi], edx      ; *(int*)edi = edx
         mov [edi + 4], eax  ; *(int*)(edi + 4) = eax

.no_swap:
         add edi, 4       ; edi = edi + 4
         loop .inner_loop ; ecx--     ; OF SF ZF AF PF affected
                          ; jnz .loop ; jump if not zero  ; jump if ZF = 0

         pop ecx  ; ecx <- stack

;        esp -> [arr[n]]...[arr[0]][ret]

         loop .outer_loop ; ecx--      ; OF SF ZF AF PF affected
                          ; jnz .loop  ; jump if not zero  ; jump if ZF = 0

finish_sort:

         call get_sorted_str  ; push on the stack the run-time address of sorted_str and jump to get_sorted_str
sorted_str:
         db "sorted: ", 0
get_sorted_str:

;        esp -> [sorted_str][arr[n]]...[arr[0]][ret]

         call [ebx+3*4]  ; printf(sorted_str);
         add esp, 4*1    ; esp = esp + 4

;        esp -> [arr[n]]...[arr[0]][ret]


print_loop:

         call get_format2  ; push on the stack the run-time address of format2 and jump to get_format2
format2:
         db "%d ",0
get_format2:

;        esp -> [format2][arr[n]]...[arr[0]][ret]

         call [ebx+3*4]  ; printf(format2, arr[n]);
         add esp, 4*2    ; esp = esp + 8
         
;        esp -> [arr[n-1]]...[arr[0]][ret]

         dec ebp  ; ebp--

         cmp ebp, 0       ; ebp - 0           ; OF SF ZF AF PF CF affected
         jne print_loop   ; jump if not equal ; jump if ZF = 0

;        esp -> [ret]

         push 0          ; esp -> [][ret]
         call [ebx+0*4]  ; exit(0);
         

error_input:

.clear_input:
        call [ebx + 2*4]  ; getchar()

        cmp al, 10        ; al - '\n'          ; OF SF ZF AF PF CF affected
        jne .clear_input  ; jump if not equal  ; jump if ZF = 0

        jmp start  ; jump always



; asmloader API
;
; ESP points to a valid stack
; we push function arguments onto the stack
; EBX contains a pointer to the API table
;
; call [ebx + FUNCTION_NUMBER*4] ; API function call
;
; FUNCTION_NUMBER:
;
; 0 - exit
; 1 - putchar
; 2 - getchar
; 3 - printf
; 4 - scanf
;
; What the function returns is in EAX.
; After calling the function, we pop arguments from the stack.
;
; https://gynvael.coldwind.pl/?id=387

%ifdef COMMENT

API Table

ebx    -> [ ][ ][ ][ ] -> exit
ebx+4  -> [ ][ ][ ][ ] -> putchar
ebx+8  -> [ ][ ][ ][ ] -> getchar
ebx+12 -> [ ][ ][ ][ ] -> printf
ebx+16 -> [ ][ ][ ][ ] -> scanf

%endif