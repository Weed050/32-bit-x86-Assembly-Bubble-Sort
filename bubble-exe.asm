[bits 32]

global main

extern printf
extern exit
extern scanf
extern getchar

section .text:
;        esp -> [ret]  ; ret - return address

main:
         push prompt_str

;        esp -> [prompt_str][ret]

         call printf   ; printf(prompt_str);
         add esp, 4*1  ; esp = esp + 4

;        esp -> [ret]

         mov ebp, 0  ; ebp = 0 

read_loop:
         sub esp, 4  ; esp = esp - 4

;        esp -> [arr[n]]...[arr[0]][ret]

         push esp  ; esp -> stack

;        esp -> [esp][arr[n]]...[arr[0]][ret]

         push format

;        esp -> [format][esp][arr[n]]...[arr[0]][ret]

         call scanf    ; scanf(format, esp)
         add esp, 4*2  ; esp = esp + 8
         
;        esp -> [arr[n]]...[arr[0]][ret]

         cmp eax, 1       ; eax - 1           ; OF SF ZF AF PF CF affected
         jne error_input  ; jump if not equal ; jump if ZF = 0

         inc ebp  ; ebp++

         call getchar

         cmp eax, ' '    ; eax - ' '     ; OF SF ZF AF PF CF affected
         je read_loop    ; jump if equal ; jump if ZF = 1

         cmp eax, 0xA     ; eax - '\n'        ; OF SF ZF AF PF CF affected
         jne error_input  ; jump if not equal ; jump if ZF = 0

         cmp ebp, 2      ; eax - '\n'    ; OF SF ZF AF PF CF affected
         jb finish_sort  ; jump if below ; jump if CF = 1

         mov esi, esp  ; esi = esp

         mov ecx, ebp  ; ecx = ebp
         dec ecx       ; ecx--

outer_loop:
         push ecx  ; ecx -> stack
         
;        esp -> [ecx][arr[n]]...[arr[0]][ret]

         mov edi, esi  ; edi = esi

inner_loop:
         mov eax, [edi]      ; eax = *(int*)edi
         mov edx, [edi + 4]  ; edx = *(int*)(edi + 4)

         cmp eax, edx    ; eax - edx             ; OF SF ZF AF PF CF affected
         jle no_swap     ; jump if less or equal ; jump if SF != OF or ZF = 1

         mov [edi], edx      ; *(int*)edi = edx
         mov [edi + 4], eax  ; *(int*)(edi + 4) = eax

no_swap:
         add edi, 4      ; edi = edi + 4
         loop inner_loop ; ecx--     ; OF SF ZF AF PF affected
                         ; jnz .loop ; jump if not zero  ; jump if ZF = 0

         pop ecx  ; ecx <- stack

;        esp -> [arr[n]]...[arr[0]][ret]

         loop outer_loop ; ecx--      ; OF SF ZF AF PF affected
                         ; jnz .loop  ; jump if not zero  ; jump if ZF = 0

finish_sort:

         push sorted_str

;        esp -> [sorted_str][arr[n]]...[arr[0]][ret]

         call printf   ; printf(sorted_str);
         add esp, 4*1  ; esp = esp + 4

;        esp -> [arr[n]]...[arr[0]][ret]


print_loop:

         push format2

;        esp -> [format2][arr[n]]...[arr[0]][ret]

         call printf   ; printf(format2, arr[n]);
         add esp, 4*2  ; esp = esp + 8
         
;        esp -> [arr[n-1]]...[arr[0]][ret]

         dec ebp  ; ebp--

         cmp ebp, 0       ; ebp - 0           ; OF SF ZF AF PF CF affected
         jne print_loop   ; jump if not equal ; jump if ZF = 0

;        esp -> [ret]

         push 0     ; esp -> [][ret]
         call exit  ; exit(0)
         

error_input:

clear_input:
        call getchar

        cmp al, 10       ; al - '\n'          ; OF SF ZF AF PF CF affected
        jne clear_input  ; jump if not equal  ; jump if ZF = 0

        jmp main  ; jump always


prompt_str:
         db "numbers: ", 0

format   db "%d", 0
format2  db "%d ",0

sorted_str:
         db "sorted: ", 0

;
;        nasm bubble-exe.asm -o bubble-exe.obj -f win32
;        golink /console /entry main bubble-exe.obj msvcrt.dll
;        bubble-exe.exe
;