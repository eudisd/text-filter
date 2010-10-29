;-----------------------------------------------------------------;
; By Eudis Duran                                                  ;
;-----------------------------------------------------------------;

title filter.asm

.model small
.386
.stack 100h

LF equ 0ah
CR equ 0dh
FILESIZE equ 4096

.data
       ibuffer        db FILESIZE   dup(?)
       obuffer        db FILESIZE*5 dup(?)
       bytes_read     db 2 dup(?)
       bytes_to_write db 4 dup(?)
       bin_buf        db 4 dup(?)
       char_buf       db 5 dup(?)
       z              db 'z'

       starter db '<~'
       limiter db '~>'

       table64 db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

       option db 2 dup(?)  ; Holds the program switch/flag
       
       ; The input and output strings are fixed length, at 10 bytes,
       ; with an extra byte to hold the 0 value sentinel, just
       ; in case the user uses the full 10 character limit.

       input  db 11 dup(?)  ; Holds program input string name
       output db 11 dup(?)  ; Holds program output string name

       ihandle dw ?
       ohandle dw ?

       ; I did not implement exceptions for wrong file input, only
       ; wrong option input.

       version_msg db LF,"Version: 0.0.3", LF
       default_msg db LF, "Text - To - Binary Filter", LF
                   db "Fall, 2009 - www.ccny.cuny.edu", LF, '$'

       error_msg   db LF," Wrong option input!", LF, LF
       help_msg db " Usage:", LF, LF
                db " filter.exe [-option] input output", LF, LF
                db " -h        : Help Screen.", LF
                db " -e        : Encode to text (Ascii85).", LF
                db " -d        : Decode from text to binary (Ascii85).", LF
                db " -E        : Encode to text (Base64).",LF
                db " -D        : Decode from text to binary (Base64)", LF
                db " -c        : Make a copy of input to output.", LF
                db " -v        : Print version information.", LF, LF, '$'
                

       file_o_error db LF, "Error creating file!  Exiting...", LF, '$'
       file_r_error db LF, "Error reading file!  Exiting...", LF, '$'
       file_w_error db LF, "Error writing file!  Exiting...", LF, '$'
       file_i_error db LF, "Error opening file!  Exiting...", LF, '$'
       
       block_counter dw 10 dup(?)
       counter db 75, 0


.code

main proc

real_start:
       mov ax, @data
       mov ds, ax
       
       ;--------This initializes some data for use later
       mov eax, 0
       mov word ptr block_counter[0], ax
       ;--------
       call fix_filenames

       call exception

       mov al, option[1]
       
       cmp al, "h"
       jne next
       mov ax, 0900h
       mov dx, offset help_msg
       int 21h

       mov ax, 4c00h
       int 21h
next:
       cmp al, "v"
       jne next2
       mov ax, 0900h
       mov dx, offset version_msg
       int 21h
       mov ax, 4c00h
       int 21h
next2:
       cmp al, "e"
       jne next3
       call encode_Ascii85
       mov ax, 4c00h
       int 21h

next3:
       cmp al, "d"
       jne next4
       call decode_Ascii85
       mov ax, 4c00h
       int 21h

next4:
       cmp al, "c"     ; This was for testing purposes, I left it as a feature.
       jne next5
       call copy

       mov ax, 4c00h
       int 21h

next5:
       cmp al, "E"
       jne next6
       call encode_Base64

       mov ax, 4c00h
       int 21h
       
       
next6:
       cmp al, "D"
       call decode_Base64

       mov ax, 4c00h
       int 21h
      
;---------------------------- Procedures --------------------------------;

fix_filenames proc
      sub bx, bx  ; zero-out (i = 0)
      sub si, si  ; zero-out (j = 0)
      sub di, di  ; zero-out (k = 0)

option_arg:
      mov ax, word ptr es:[82h]
      mov word ptr option[0], ax

copy_arg1:
      mov al, es:[85h + bx]
      cmp al, ' '
      je copy_arg2
      mov input[di], al
      inc di
      inc bx
      jmp copy_arg1
      
copy_arg2:

      inc bx
      mov al, es:[85h + bx]

      cmp al, 0dh ; carrige return
      je exit_procedure

      mov output[si], al
      inc si

      jmp copy_arg2
      
exit_procedure:
      mov al, 0
      mov input[di + 1], al
      mov output[si + 1], al
      ret

fix_filenames endp



exception proc  
     mov al, option[0]
     cmp al, "-"
     jne input_error

     mov al, option[1]

     cmp al, "d"
     jne nested
     ret
     


nested:
     cmp al, "e"
     jne nested2
     ret
nested2:
     cmp al, "v"
     jne nested3
     ret
nested3:
     cmp al, "h"
     jne nested4
     ret
nested4:
     cmp al, "c"
     jne nested5
     ret
nested5:
     cmp al, "E"
     jne nested6
     ret
nested6:
     cmp al, "D"
     jne input_error
     ret

exception endp



input_error:

     mov ax, 0900h
     mov dx, offset error_msg
     int 21h

     mov ax, 4c00h   ; exit
     int 21h

copy proc
     call open_file

     call create_file

     mov ax, 3f00h    ; read
     mov bx, ihandle
     mov dx, offset ibuffer
     mov cx, FILESIZE
     int 21h
     jc file_read_error
     push ax         ; actual bytes read put in stack

     mov ax, 4000h   ; write
     mov bx, ohandle
     mov dx, offset ibuffer
     pop cx
     int 21h
     jc file_write_error

     mov ax, 3e00h
     mov bx, ihandle
     int 21h
       
     mov ax, 3e00h
     mov bx, ohandle
     int 21h

     ret
copy endp

; Preconditions: must have byte-write amount
; and also, must have access to output iterator.
;write_file_block:

;     mov ax, word ptr block_counter[0]
;     add ax, 1
;     mov word ptr block_counter[0], ax



;     mov ax, 4000h
;     mov bx, ohandle
;     mov dx, offset obuffer
;     mov cx, si    ; the output iterator will limit the char output
;     int 21h
;     jc file_write_error

;     jmp file_count_loop
     


encode_Ascii85 proc

     call open_file
     call create_file



     mov ax, 4000h   ; write
     mov bx, ohandle
     mov cx, 2
     mov dx, offset starter   ; This inserts "<~"
     int 21h
     jc file_write_error


file_count_loop:
     mov ax, 3f00h
     mov dx, offset ibuffer
     mov bx, ihandle
     mov cx, FILESIZE
     int 21h
     jc file_open_error
     mov word ptr bytes_read[0], ax  ; save the actual bytes read



     xor si, si
     cmp ax, 1

     je case1        ; only one character is provided
     cmp ax, 2

     je case2        ; only two characters are provided
     cmp ax, 3

     je case3        ; only three characters are provided

     cmp ax, 0       ;  As per specification, if an empty file is provided
     jne continue    ;  append a "z" as opposed to (!!!!!).

     mov ax, 4000h
     mov bx, ohandle
     mov cx, 1
     mov dx, offset z
     int 21h
     jc file_write_error

     ; write limiter here
     mov ax, 4000h   ; write
     mov bx, ohandle
     mov cx, 2
     mov dx, offset limiter ; "~>"
     int 21h
     jc file_write_error

     jmp close_files  ; close files and write one char

;;;------------------------GENERAL CASE-------------------------;;;
;;;                         multiple of 4                       ;;;
;;;_____________________________________________________________;;;

continue:

     xor di, di       ; ibuffer iterator
     xor si, si       ; obuffer iterator
     load_buffer_loop:



                 ; reverse 4-byte tuple

        cont_block:

                 mov al, ibuffer[di]
                 mov bl, ibuffer[di + 3]
                 xchg al, bl
                 mov ibuffer[di], al
                 mov ibuffer[di + 3], bl

                 mov al, ibuffer[di + 1]
                 mov bl, ibuffer[di + 2]
                 xchg al, bl
                 mov ibuffer[di + 1], al
                 mov ibuffer[di + 2], bl


                 mov eax, dword ptr ibuffer[di]

                 call put85

                 mov eax, dword ptr char_buf[0]

                 mov dword ptr obuffer[si], eax
                 mov al, byte ptr char_buf[4]
                 mov byte ptr obuffer[si + 4], al
                 mov ax, word ptr bytes_read[0]
                 add di, 4h
                 add si, 5h
                 ;cmp di, FILESIZE
                 ;je write_file_block
                 cmp di, ax
                 jl load_buffer_loop


     sub ebx, ebx
     sub edx, edx
     mov bx, di
     mul ebx

     cmp edx, 1
     jne base85_cont1
     
     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 3
     mov cx, si    ; the output iterator will limit the char output
     int 21h
     jc file_write_error
     jmp close_files
     
base85_cont1:
     cmp edx, 2
     jne base85_cont2

     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 2
     mov cx, si    ; the output iterator will limit the char output
     int 21h
     jc file_write_error
     jmp close_files

     

base85_cont2:
     cmp edx, 3
     jne base85_cont3
     
     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 1
     mov cx, si    ; the output iterator will limit the char output
     int 21h
     jc file_write_error
     jmp close_files


base85_cont3:
     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     mov cx, si    ; the output iterator will limit the char output
     int 21h
     jc file_write_error
     ; check cases
     ; if ax%4 == 0, then continue
     ;else if ax%3 == 0 then case3 on last block
     ;else if ax%2 == 0 then case2 on last block
     ;else if ax%2 == 1 then case1 on last block

     mov ax, word ptr bytes_read[0]
     cmp ax, cx
     jg file_count_loop


     ; write limiter here
     mov ax, 4000h   ; write
     mov bx, ohandle
     mov cx, 2
     mov dx, offset limiter ; "~>"
     int 21h
     jc file_write_error



close_files:
     ; close both input/output files
     mov ax, 3e00h
     mov bx, ihandle
     int 21h

     mov ax, 3e00h
     mov bx, ohandle
     int 21h

     ret


case1:

     xor eax, eax
     mov al, ibuffer[si]
     shl eax, 24
     call put85


     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset char_buf
     mov cx, 2h
     int 21h
     jc file_write_error
     jmp cases_end


case2:    

     xor eax, eax
     mov ah, ibuffer[si]
     mov al, ibuffer[si + 1]
     shl eax, 16
     call put85


     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset char_buf
     mov cx, 3h
     int 21h
     jc file_write_error
     jmp cases_end

case3:
     

     xor eax, eax
     mov ah, ibuffer[si]
     mov al, ibuffer[si + 1]
     shl eax, 16
     mov ah, ibuffer[si + 2]
     call put85

     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset char_buf
     mov cx, 4h
     int 21h
     jc file_write_error
     jmp cases_end



cases_end:
      ; write limiter here
     mov ax, 4000h   ; write
     mov bx, ohandle
     mov cx, 2
     mov dx, offset limiter ; "~>"
     int 21h
     jc file_write_error

     jmp close_files  ; close files and write one char

encode_Ascii85 endp




decode_Ascii85 proc

     call open_file
     call create_file

     
dec_file_count_loop:
     mov ax, 3f00h
     mov dx, offset ibuffer
     mov bx, ihandle
     mov cx, FILESIZE
     int 21h
     jc file_open_error
     mov word ptr bytes_read[0], ax  ; save the actual bytes read

     xor si, si

     ;cmp ax, 3

     ;je dec_case1        ; only one valid byte is provided
     ;cmp ax, 4

     ;je dec_case2        ; only two valid bytes are provided
     ;cmp ax, 5

     ;je dec_case3        ; only three valid bytes are provided

     cmp ax, 0
     jne dec_continue


     jmp dec_close_files  ; close files if nothing is in the ibuffer

;;;------------------------GENERAL CASE-------------------------;;;
;;;                         multiple of 4                       ;;;
;;;_____________________________________________________________;;;

dec_continue:

     xor di, di
     add di, 2        ; ibuffer iterator, ignore the "<~" characters
     xor si, si       ; obuffer iterator
     dec_load_buffer_loop:
     
                 ; reverse 5-byte tuple

                 mov al, ibuffer[di]
                 mov bl, ibuffer[di + 4]
                 xchg al, bl
                 mov ibuffer[di], al
                 mov ibuffer[di + 4], bl
                 
                 mov al, ibuffer[di + 1]
                 mov bl, ibuffer[di + 3]
                 xchg al, bl
                 mov ibuffer[di + 1], al
                 mov ibuffer[di + 3], bl

                 mov eax, dword ptr ibuffer[di] ; first four-bytes
                 mov bl, ibuffer[di + 4]        ; last byte

                 call get85

                 mov eax, dword ptr bin_buf[0]

                 mov dword ptr obuffer[si], eax
                 mov al, byte ptr char_buf[4]
                 mov byte ptr obuffer[si + 4], al
                 mov ax, word ptr bytes_read[0]
                 add di, 5h
                 add si, 4h
                 cmp di, ax
                 jl dec_load_buffer_loop



     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 4
     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error

     ; check cases
     ; if ax%4 == 0, then continue
     ;else if ax%3 == 0 then case3 on last block
     ;else if ax%2 == 0 then case2 on last block
     ;else if ax%2 == 1 then case1 on last block

     mov ax, word ptr bytes_read[0]
     cmp ax, cx
     jg dec_file_count_loop




dec_close_files:
     ; close both input/output files
     mov ax, 3e00h
     mov bx, ihandle
     int 21h

     mov ax, 3e00h
     mov bx, ohandle
     int 21h

     ret


decode_Ascii85 endp


open_file proc
       mov ax, 3d00h    ; open for reading only
       mov dx, offset input
       int 21h
       jc file_open_error
       mov ihandle, ax
       ret
open_file endp


create_file proc
       mov ax, 3c00h
       mov dx, offset output
       sub cx, cx    ; no attributes
       int 21h
       jc file_create_error
       mov ohandle, ax
       ret
create_file endp



file_create_error:
       mov ax,0900h
       mov dx, offset file_o_error
       int 21h
       mov ax, 4c00h
       int 21h ;exit


file_open_error:
       mov ax, 0900h
       mov dx, offset file_i_error
       int 21h
       mov ax, 4c00h
       int 21h

       
file_read_error:
       mov ax, 0900h
       mov dx, offset file_r_error
       int 21h
       mov ax, 4c00h
       int 21h

file_write_error:
       mov ax, 0900h
       mov dx, offset file_w_error
       int 21h
       mov ax, 4c00h
       int 21h
       

   
; @Precondition: eax needs to hold the current 4-byte tuple; this will be
;                accessed from the input stream buffer.
; @Postcondition: The char_buf is filled with the proper bytes.  The order by which
;                 the bytes are loaded into the output buffer follows the Ascii85
;                 specification (i.e. big-endian).
put85 proc

      push di
      push si
      mov ebx, 85
      xor si, si

      mov dword ptr bin_buf[0], eax

L1:

      mov eax, dword ptr bin_buf[0]
      mov dword ptr bin_buf[0], eax

      mov cx, si
      add cx, 1


L2:
      xor edx, edx
      div ebx
      dec cx
      cmp cx, 0h
      jne L2

      inc si
      xor dh, dh
      add dl, 33

      mov di, 5h
      sub di, si
      mov char_buf[di], dl

      cmp si, 5h
      jne L1
      pop si
      pop di
      

      ret

put85 endp


; @Precondition: eax needs to hold the current 4-byte tuple; The last byte must be 
;                supplied to the bl register.  These bytes will be accessed from the input
;                stream buffer.
; @Postcondition: The bin_buf is filled with the proper bytes.
get85 proc

      push di
      push si
      xor si, si
      xor edi, edi ; accumulator

      mov dword ptr char_buf[0], eax

      mov char_buf[4], bl

      ; Reverse the ascii addition of 33---
      push si
      xor si, si
      rm_ascii:
               mov bl, char_buf[si]
               sub bl, 33
               mov char_buf[si], bl
               inc si
               cmp si, 5h
               jne rm_ascii
      pop si
      ;-------------------------------------

      mov ebx, 85

dec_L1:

      xor eax, eax
      mov al, char_buf[si + 1]

      mov cx, si
      add cx, 1


dec_L2:
      xor edx, edx
      mul ebx
      dec cx
      cmp cx, 0h
      jne dec_L2

      inc si

      add edi, eax

      cmp si, 4h
      jne dec_L1
      
      xor eax, eax
      mov al, char_buf[0]
      add edi, eax  ; add first index to the lot
      
      mov dword ptr bin_buf[0], edi

      mov al, bin_buf[3]
      mov bl, bin_buf[0]
      xchg al, bl
      mov bin_buf[3], al
      mov bin_buf[0], bl
      mov al, bin_buf[2]
      mov bl, bin_buf[1]
      xchg al, bl
      mov bin_buf[2], al
      mov bin_buf[1], bl
      


      pop si
      pop di
      

      ret


get85 endp



; ----------------------------- BASE64 SECTION -------------------------;





encode_Base64 proc



     call open_file
     call create_file

     
base64_file_count:
     mov ax, 3f00h
     mov dx, offset ibuffer
     mov bx, ihandle
     mov cx, FILESIZE
     int 21h
     jc file_open_error

     mov word ptr bytes_read[0], ax  ; save the actual bytes read
     





     ;cmp ax, 3

     ;je dec_case1        ; only one valid byte is provided
     ;cmp ax, 4

     ;je dec_case2        ; only two valid bytes are provided
     ;cmp ax, 5

     ;je dec_case3        ; only three valid bytes are provided

     cmp ax, 0
     jne base64_continue
     jmp base64_close_files  ; close files if nothing is in the ibuffer

;;;------------------------GENERAL CASE-------------------------;;;
;;;                                                             ;;;
;;;_____________________________________________________________;;;

base64_continue:

     xor di, di
     xor si, si       ; obuffer iterator

     base64_load_buffer:

                 ; cut it at 70 char per line
                 ;mov ebx, 70

                 ;cmp si, 0
                 ;je mod_fail
                 ;xor eax, eax
                 ;xor edx, edx
                 ;mov ax, si

                 ;div ebx
                 ;cmp edx, 0
                 ;jne mod_fail

                 ;mov obuffer[si], CR
                 ;mov obuffer[si + 1], LF
                 ;inc si
                 ;inc si


           mod_fail:

                 mov al, ibuffer[di]
                 mov bl, ibuffer[di + 2]
                 xchg al, bl
                 mov ibuffer[di], al
                 mov ibuffer[di + 2], bl

                 mov eax, dword ptr ibuffer[di] ; first four-bytes

                 call put64

                 mov eax, dword ptr char_buf[0]

                 mov dword ptr obuffer[si], eax  


                 mov ax, word ptr bytes_read[0]


                 add di, 3h
                 add si, 4h

                 cmp di, ax
                 jl base64_load_buffer


     xor eax, eax
     mov ax, word ptr bytes_read[0]


     sub edx, edx
     mov ebx, 3
     div ebx


     cmp edx, 2



     jne next_trunc


     ; per specification
     mov obuffer[si - 1], '='

     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     mov cx, si
     int 21h
     jc file_write_error
     jmp base64_close_files

next_trunc:

     cmp edx, 1
     jne end_trunc
     ; per speficication
     mov obuffer[si - 1], '='
     mov obuffer[si - 2], '='


     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer

     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error
     
     jmp base64_close_files

     ; check cases
     ; if ax%4 == 0, then continue
     ;else if ax%3 == 0 then case3 on last block

     ;else if ax%2 == 0 then case2 on last block
     ;else if ax%2 == 1 then case1 on last block

     mov ax, word ptr bytes_read[0]
     cmp ax, FILESIZE
     jl base64_file_count

  end_trunc:
     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer

     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error

base64_close_files:
     ; close both input/output files
     mov ax, 3e00h
     mov bx, ihandle
     int 21h

     mov ax, 3e00h
     mov bx, ohandle
     int 21h

     ret

encode_Base64 endp



decode_Base64 proc

     call open_file
     call create_file

     
dec64_file_count:   ; case 1: =
     mov ax, 3f00h
     mov dx, offset ibuffer
     mov bx, ihandle
     mov cx, FILESIZE
     int 21h
     jc file_open_error
     mov word ptr bytes_read[0], ax  ; save the actual bytes read
     




done_sentinel:
     cmp ax, 0
     jne dec64_continue


     jmp dec64_close_files  ; close files if nothing is in the ibuffer

;;;------------------------GENERAL CASE-------------------------;;;
;;;                         multiple of 4                       ;;;
;;;_____________________________________________________________;;;

dec64_continue:



     xor di, di       ; ibuffer iterator
     xor si, si       ; obuffer iterator
     dec64_load_buffer:
     

                 ; reverse 4-byte tuple
                 mov al, ibuffer[di]
                 mov bl, ibuffer[di + 3]
                 xchg al, bl
                 mov ibuffer[di], al
                 mov ibuffer[di + 3], bl

                 mov al, ibuffer[di + 1]
                 mov bl, ibuffer[di + 2]
                 xchg al, bl
                 mov ibuffer[di + 1], al
                 mov ibuffer[di + 2], bl


                 mov eax, dword ptr ibuffer[di] ; First four-bytes


                 call get64

                 mov eax, dword ptr bin_buf[0]

                 mov dword ptr obuffer[si], eax
                 mov ax, word ptr bytes_read[0]
                 add di, 4h
                 add si, 3h
                 cmp di, ax
                 jl dec64_load_buffer
     ; -----------------------------------------


     mov bx, ax




     mov al, ibuffer[bx - 3]
     cmp al, '='         ; case 2:==

     jne next_sentinel

     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 2
     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error
     jmp dec64_close_files




next_sentinel:   ; case 1: =

     mov al, ibuffer[bx - 4]
     cmp al, '='

     jne no_truncate




     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     sub si, 1
     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error
     jmp dec64_close_files

     




no_truncate:

     ;----------------------------------------
     mov ax, 4000h
     mov bx, ohandle
     mov dx, offset obuffer
     ;sub si, 4
     mov cx, si ; the output iterator will limit the bin output
     int 21h
     jc file_write_error

     ; check cases
     ; if ax%4 == 0, then continue
     ;else if ax%3 == 0 then case3 on last block
     ;else if ax%2 == 0 then case2 on last block
     ;else if ax%2 == 1 then case1 on last block


     mov ax, word ptr bytes_read[0]
     cmp ax, cx
     je dec64_file_count


dec64_close_files:
     ; close both input/output files
     mov ax, 3e00h
     mov bx, ihandle
     int 21h

     mov ax, 3e00h
     mov bx, ohandle
     int 21h

     ret

decode_Base64 endp



; @Precondition: eax needs to hold the current 3-byte tuple;These bytes will be accessed from the input
;                stream buffer.
; @Postcondition: The bin_buf is filled with the proper bytes.
put64 proc


      push di
      push si

      mov ebx, 64
      xor si, si

      mov dword ptr bin_buf[0], 0h
      mov dword ptr bin_buf[0], eax

L1_64:

      mov eax, dword ptr bin_buf[0]
      mov dword ptr bin_buf[0], eax

      mov cx, si
      add cx, 1


L2_64:
      xor edx, edx
      div ebx
      dec cx
      cmp cx, 0h
      jne L2_64

      inc si
      xor dh, dh

      push si
      xor dh, dh
      mov si, dx
      mov dl, table64[si]
      pop si

      mov di, 4h
      sub di, si
      mov char_buf[di], dl

      cmp si, 4h
      jne L1_64


      pop si
      pop di
      



      ret

put64 endp


get64 proc

      push di
      push si

      mov dword ptr char_buf[0], eax

      ; Reverse the table lookup
      xor di, di
reverse_lookup:
      xor bx, bx
      mov al, char_buf[di]
      loop1:
            cmp al, table64[bx]
            je outhere
            inc bx
            cmp bx, 64
            jne loop1
      outhere:

      mov char_buf[di], bl

      inc di
      cmp di,4h
      jne reverse_lookup

      xor esi, esi
      xor edi, edi ; accumulator

      mov ebx, 64

dec64_L1:

      xor eax, eax
      mov al, char_buf[si + 1] ; The first term is 64^0 * char_buf[si + 1]
                               ; which means there is no point in multiplying
                               ; against it.

      mov cx, si
      add cx, 1


dec64_L2:
      xor edx, edx
      mul ebx
      dec cx
      cmp cx, 0h
      jne dec64_L2

      add edi, eax
      ;mov dword ptr bin_buf[si],  eax

      inc si


      


      cmp si, 3h
      jne dec64_L1


      xor eax, eax
      mov al, char_buf[0]

      add edi, eax  ; add first index to the lot
      
      mov dword ptr bin_buf[0], edi

      mov al, bin_buf[2]
      mov bl, bin_buf[0]
      xchg al, bl
      mov bin_buf[2], al
      mov bin_buf[0], bl


      pop si
      pop di


      ret


get64 endp



; @Precondition: al contains the sentinel value
; @Postcondition: ebx holds the strlen


main endp
end main