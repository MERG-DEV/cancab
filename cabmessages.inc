

; Text strings for use on CANCAB LCD display 
;
; Each string is null terminated.
;
; LCD display width is 8 characters.
;
; Each string is null padded to maximum length so 
; when new language files are downloaded, each string
; remains at the same memory location
;

	org	0x3000

	;	LCD text strings

												; MAX LENGTH (some strings must allow space on 8 char row for further info)
Titlstr db	"M","E","R","G"," ","C","A","B",0	; 8
Verstr	db  "V","e","r"," ",0,0					; 5
Selstr	db	"S","E","L",".","L","O","C","O",0	; 8
Selstep db 	"S","E","L",".","S","T","E","P",0	; 8
Stopstr	db	"S","T","O","P","!",0,0,0,0			; 8
EmStopstr db "S","T","O","P",0x20,"A","L","L",0	; 8
Relstr	db	"R","E","L","E","A","S","E","?",0	; 8
Fr1lbl	db	"F","r","1"," "," ",0				; 5
Fr2lbl	db	"F","r","2"," "," ",0				; 5
Fnumstr	db	" "," "," "," "," ","F",0			; 6
Constr	db	"C","o","n","s","i","s","t",0,0		; 8
Conclr	db	"c","l","e","a","r","?",0,0,0		; 8
Progstr1 db	"C","V","n","u","m","b","e","r",0	; 8
Progstr2 db "L","o","n","g"," ","A","d","r",0	; 8
Progstr3 db "C","V"," ","V","a","l","u","e",0	; 8
Str_equ	db	"="," ",0							; 2
CV_equ	db	"C","V","="," ",0					; 4
REG_equ db 	"R","e","g","="," ",0				; 5
ADR_equ db	"A","d","r","="," ",0				; 5
Str_tkn	db	"T","A","K","E","N",0,0,0,0			; 8
Str_ful	db	"F","U","L","L",0,0,0,0,0			; 8
Prog_CV db	"P","r","o","g",0x20,"C","V",0,0	; 8


No_ack	db	"N","o",0x20,"A","c","k",0,0,0		; 8
Over_ld	db	"O","v","e","r",0					; 4
Ack_OK	db	"O","K",0							; 2
Busy	db	"B","u","s","y",0					; 4
Err		db	"E","r","r","o","r",0,0,0,0			; 8
Address db	"A","d","d","r","e","s","s",0,0		; 8
Str128	db	"s","1","2","8"," ",0				; 5
Str28	db	"s","2","8"," "," ",0				; 5
Str14	db	"s","1","4"," "," ",0				; 5
Segful	db	"S","e","g","m","e","n","t",0,0		; 8
Stupstr	db	"S","E","T","U","P",0,0,0,0			; 8
Lrnstr	db  "L","E","A","R","N",0,0,0,0			; 8
Onstr	db	"O","n",0,0,0,0,0,0,0				; 8
Offstr	db	"O","f","f",0,0,0,0,0,0				; 8
Silstr	db	"S","i","l","e","n","t",0,0,0		; 8
Testing	db	"T","e","s","t","i","n","g",0,0		; 8

; Note: The service mode strings must not wrap
;       around a 256 segment boundary

Pmode1	db	"P","r","o","g",0x20,"D","i","r",0	; 8
Pmode2	db	"P","r","o","g",0x20,"P","a","g",0	; 8
Pmode3	db	"P","r","o","g",0x20,"R","e","g",0	; 8
Pmode4	db	"P","r","o","g",0x20,"A","d","r",0	; 8
Rmode1	db	"R","e","a","d",0x20,"D","i","r",0	; 8
Rmode2	db	"R","e","a","d",0x20,"P","a","g",0	; 8
Rmode3	db	"R","e","a","d",0x20,"R","e","g",0	; 8
Rmode4	db	"R","e","a","d",0x20,"A","d","r",0	; 8

; For test mode to see what is in LCD CG RAM

Teststr db	0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0 ; 8
TeststEnd 

;***************************************************************************************************
;
;	The Everbouquet display supports 8 custom characters in character generator RAM that can
;	be uploaded.  This can be used for language characters that are not in the fixed 
;	character generator ROM. 
;
;	This table contains the characters to be uploaded during intialisation.
;	These can then be used in the strings table above.
;
;	The 8 custom characters can be displayed as characters 0x00-0x07  or 0x08-0x0F.
;
;	Note that character 00 cannot be referenced in the strings, because that is used as the terminator,
;	so it is preferable to use them as characters 0x08-0x0F
;
;	Each character is a 5x8 matrix, stored as 8 bytes, one for each row. 
;	
;	Each byte represents one row, the LS 5 bits are the pixels for that row, bit 5 is unused, bits 6 and 7 
;	set blinking if the blink on cursor position is used. We don't use that feature, so set bits 6 and 7 to 0.
;
;	The bottom row is not actually displayed on our display, but must be declared because the
;   initialisation routine copies all the bytes from the table in sequence into the CG RAM.
;
;	This table is for French characters with accents

		org	0x3800

Custchars
Char08	db	B'00001000',B'00000100' ; à
		db	B'00001110',B'00000001'
		db	B'00001111',B'00010001'
		db	B'00001111',B'00000000'

Char09	db	B'00001000',B'00000100' ; è
		db	B'00001110',B'00010001'
		db	B'00011111',B'00010000'
		db	B'00001110',B'00000000'

Char0A	db	B'00000010',B'00000100' ; é
		db	B'00001110',B'00010001'
		db	B'00011111',B'00010000'
		db	B'00001110',B'00000000'

Char0B	db	B'00000100',B'00001010' ; ô
		db	B'00001110',B'00010001'
		db	B'00010001',B'00010001'
		db	B'00001110',B'00000000'

Char0C	db	B'00000100',B'00001010' ; û
		db	B'00010001',B'00010001'
		db	B'00010001',B'00010011'
		db	B'00001101',B'00000000'

Char0D	db	B'00000100',B'00001010' ; ê
		db	B'00001110',B'00010001'
		db	B'00011111',B'00010000'
		db	B'00001110',B'00000000'

Char0E	db	B'00001000',B'00000100' ; È
		db	B'00011110',B'00010000'
		db	B'00011100',B'00010000'
		db	B'00011110',B'00000000'

Char0F	db	B'00000010',B'00000100' ; É
		db	B'00011110',B'00010000'
		db	B'00011100',B'00010000'
		db	B'00011110',B'00000000'
Custend	



