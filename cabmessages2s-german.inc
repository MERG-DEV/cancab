;
; Text strings for use on CANCAB LCD display 
;
; Version 2l - German   2nd May 2011 - Translation by Michael Blank
;
; Version 2q,2s - 2012-2014 - new strings added
;   (added at version 2qBeta, released at version 2s)

; Use with CANCAB firmware version 2s onwards
; 
;
; LCD display width is 8 characters.
;
; Each string is padded to maximum length by nulls and also null terminated.

; To best display this file, with everything lining up correctly, set MPLAB or
; your text editor to a tab size of 4 characters.

; When changing text strings, they must be kept so that each string continues
; to load at the same absolute address.

; This is so that message files in different languages can be downloaded to the cab separately.

; To keep all strings at their absolute addresses:

; 1. Note that your message string must not exceed the maximum size shown in the first line of each comment
; 2. If your string is less than the maximum size, add nulls to the maximum size
; 3. Add one further null to terminate the string
;
;
;  For example, to replace the string "Error" with "Fehler", the original line reads:
;
;  Err    db  "Error",0,0,0,0           ; 8 
;
; The string has a maximum length of 8, and "Error" is only 5 characters, so 3 extra nulls are
; added, plus a fourth null as the string terminator.
;
; Fehler is 6 characters, so we only need 2 extra nulls plus the terminator. The new line is:
;
;  Err    db  "Fehler",0,0,0            ; 8
;
; If a new string is now the maximum length, you would just have a single null to terminate the string.

; To include special characters, either from the top half of the built in character set or from the custom
;   character table, use the hex value of the character. For example, to replace Over with Über:
;
;  Over_ld  db  "Over",0              ; 4
;
; becomes:
;
;  Over_ld  db  0xF5,"b","e","r",0          ; 4 




  org loadadr

; LCD text strings

; Note: The service mode strings must not wrap
;       around a 256 segment boundary, 
;   so they are placed first in the list

                  ; MAX LENGTH (some strings must allow space on an 8 character
                  ;    row for further information to be displayed)

Pmode1  db  "Prog Dir",0            ; 8
Pmode2  db  "Prog Pag",0            ; 8
Pmode3  db  "Prog Reg",0            ; 8
Pmode4  db  "Prog Adr",0            ; 8
Rmode1  db  "Lese Dir",0            ; 8
Rmode2  db  "Lese Pag",0            ; 8
Rmode3  db  "Lese Reg",0            ; 8
Rmode4  db  "Lese Adr",0            ; 8


Titlstr db  "MERG CAB",0            ; 8
Verstr  db  "Ver ",0,0              ; 5
Selstr  db  "LOK WAHL",0            ; 8
Selstep db  "FAHRSTU",0,0           ; 8
Stopstr db  "LOKHALT",0,0           ; 8
EmStopstr db "NOTHALT",0,0            ; 8
Relstr  db  "Freigb?",0,0           ; 8
Fr1lbl  db  "Fb1     ",0            ; 8
Fr2lbl  db  "Fb2     ",0            ; 8
Fnumstr db  "     F",0              ; 6
Constr  db  "Doppeltr",0            ; 8
Conclr  db  "l",0xEF,"schen?",0         ; 8
Progstr1 db "CVnummer",0            ; 8
Progstr2 db "LangeAdr",0            ; 8
Progstr3 db "CV Wert",0,0           ; 8
Str_equ db  "= ",0                ; 2
CV_equ  db  "CV= ",0              ; 4
REG_equ db  "Reg= ",0             ; 5
ADR_equ db  "Adr= ",0             ; 5
Str_tkn db  0xF5,"bernom.",0          ; 8
Str_ful db  "VOLL",0,0,0,0,0          ; 8
Prog_CV db  "Prog CV",0,0           ; 8


No_ack  db  "Nicht OK",0            ; 8
Over_ld db  0xF5,"ber",0            ; 4
Ack_OK  db  "OK",0              ; 2
Busy  db  "Busy",0            ; 4
Err db  "Fehler",0,0,0            ; 8
Address db  "Adresse ",0          ; 8
Str128  db  "s128",0            ; 4
Str28 db  "s28 ",0            ; 4
Str14 db  "s14 ",0            ; 4
Segful  db  "Segment",0,0           ; 8   First line of "Segment full", displayed when too many CBUS
                        ;   devices are already present (>110) so cannot self-enumerate.
DispStr db  "Freigb.?",0            ; 8   Release a loco whilst moving
Spdsstr db  "Lok-V",0           ; 5   Current loco speed when taking over moving loco (must leave 3 chars for speed value)
Stlstr  db  0xF5,"bern???",0          ; 8   For forced takover of a loco already taken
Stupstr db  "SETUP",0,0,0,0           ; 8
Cabstr  db  "CAB",0,0,0,0,0,0         ; 8
Cmdstr  db  "CMD STN",0,0           ; 8
LimStr  db  "Limit",0,0,0,0           ; 8
Lrnstr  db  "LERNEN",0,0,0            ; 8   Learn mode for CBUS events
LinStr  db  "LERNEN",0,0,0            ; 8
Whatstr db  "Was tun?",0            ; 8   During event learning, user responds by pressing action on cab
Monstr  db  "MONITOR",0,0           ; 8   Monitor CBUS packets
Curstr  db  "Strom",0,0,0,0           ; 8   Electrical current
FliMstr db  "FLiM Set",0            ; 8   Enters FLiM setup mode
NodeStr db  "Node id?",0            ; 8   For manual FLiM node setting
Onstr db  "Ein ",0              ; 4
Offstr  db  "Aus ",0              ; 4
Silstr  db  "lautlos",0,0           ; 8   Silent mode option
Stp2rv  db  "Stop2dir",0            ; 8   Require loco stopped before can reverse option
Wlktstr db  "Timeout",0,0           ; 8   Walkabout timeout
RecLstr db  "LList.Gr",0            ; 8   Size of list of recent Locos to choose from
Evntstr db  "Events",0,0,0            ; 8   Respond to or monitor CBUS events
DCCstr  db  "DCC",0,0,0,0,0,0         ; 8
AllStr  db  "ALL",0,0,0,0,0,0         ; 8   
Acstr db  "AC",0              ; 2   Short for "Accessory". Only 2 chars, must leave space for message like "AC103OFF" which is 8 chars
Revstr  db  "Richtung",0            ; 8   As in "change direction", not direction is reverse
Fwdstr  db  "Vorw",0xE1,"rts",0         ; 8 
Bkwdstr db  "R",0xF5,"ckwrts",0         ; 8   As in direction is backwards, to distinguish between reversal 

Testing db  "Test",0,0,0,0,0          ; 8

; For test mode to see what is in LCD CG RAM

Teststr db  0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0 ; 8
TeststEnd 

; New strings added 21/9/11 at end of table

Firmstr db  "Firmware",0            ; 8   Displayed during boot load
Updstr  db  "Update",0,0,0            ; 8   Displayed during boot load
Mom_onstr db  "Mom+",0            ; 4   Momentary on. used for Fn keys
Mom_ofstr db  "Mom-",0            ; 4   Momentary off

; Strings new for version 2q,r,s

Res_str   db  "Reset",0,0,0,0         ; 8   Reset message
Sharestr  db  "Teilen?",0,0           ; 8   Sharing cabs
Sessionstr  db  "SESSION",0,0         ; 8   Session cancelled when stolen (forced) by another cab
Cancelstr db  "GEL",0xEF,"SCHT",0       ; 8
Loststr   db  "VERLOREN",0            ; 8   Session lost when timed out or not there when reconnect after walkabout too late

;***************************************************************************************************
;
; The Everbouquet display supports 8 custom characters in character generator RAM that can
; be uploaded.  This can be used for language characters that are not in the fixed 
; character generator ROM. 
;
; This table contains the characters to be uploaded during intialisation.
; These can then be used in the strings table above.
;
; The 8 custom characters can be displayed as characters 0x00-0x07  or 0x08-0x0F.
;
; Note that character 00 cannot be referenced in the strings, because that is used as the terminator,
; so it is preferable to use them as characters 0x08-0x0F
;
; Each character is a 5x8 matrix, stored as 8 bytes, one for each row. 
; 
; Each byte represents one row, the LS 5 bits are the pixels for that row, bit 5 is unused, bits 6 and 7 
; set blinking if the blink on cursor position is used. We don't use that feature, so set bits 6 and 7 to 0.
;
; The bottom row is not actually displayed on our display, but must be declared because the
;   initialisation routine copies all the bytes from the table in sequence into the CG RAM.
;
; This table is for French characters with accents

    org 0x3800

Custchars
Char08  db  B'00001000',B'00000100' ; à
    db  B'00001110',B'00000001'
    db  B'00001111',B'00010001'
    db  B'00001111',B'00000000'

Char09  db  B'00001000',B'00000100' ; è
    db  B'00001110',B'00010001'
    db  B'00011111',B'00010000'
    db  B'00001110',B'00000000'

Char0A  db  B'00000010',B'00000100' ; é
    db  B'00001110',B'00010001'
    db  B'00011111',B'00010000'
    db  B'00001110',B'00000000'

Char0B  db  B'00000100',B'00001010' ; ô
    db  B'00001110',B'00010001'
    db  B'00010001',B'00010001'
    db  B'00001110',B'00000000'

Char0C  db  B'00000100',B'00001010' ; û
    db  B'00010001',B'00010001'
    db  B'00010001',B'00010011'
    db  B'00001101',B'00000000'

Char0D  db  B'00000100',B'00001010' ; ê
    db  B'00001110',B'00010001'
    db  B'00011111',B'00010000'
    db  B'00001110',B'00000000'

Char0E  db  B'00001000',B'00000100' ; È
    db  B'00011110',B'00010000'
    db  B'00011100',B'00010000'
    db  B'00011110',B'00000000'

Char0F  db  B'00000010',B'00000100' ; É
    db  B'00011110',B'00010000'
    db  B'00011100',B'00010000'
    db  B'00011110',B'00000000'
Custend 



