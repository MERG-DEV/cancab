;     TITLE   "Source for DCC CAB for CBUS"
; 
; 
; Uses 4 MHz resonator and PLL for 16 MHz clock
; CAB with OTM and service mode programming, one speed knob and self enum for CAN_ID

; Emergency Stop and Emergency Stop all facility
; Includes Consist setting and clearing.
; Ability to set long address into loco in one instruction.
; Walkaround facility
; Firmware updatable over CBUS (using FCU)
; Has no node number facility yet. 

; Drives an 8 char by 2 line display (Everbouquet MC0802A used in prototype but protocol is standard for most displays)
; Use command station firmware cancmd_n or later for full functionality of emergency stop all
; Use command station firmware cancmd3b or later for correct service mode programming of all decoders


; The setup timer is TMR3. 
; CAN bit rate of 125 Kbits/sec
; Standard frame only 


; this code is for 18F2480
; 

; use with PCB CAB1 rev B

; 

; 
; rev c 31/03/09  various mods to error routine and consist clear

; rev d 11/04/09  is with final arrangement for row scan - tested with CAB1 

; rev e.        BOR voltage set lower to prevent resets
;           keepalive added using TMR0
;           ignores prog button if no loco
;           no loco selected till handle granted
;           Changed error message format to show loco number

; Rev f. 11/07/09 Changes to save handle etc. for walkaround
;           Seems to be working OK. Difficult to test everything.  

; Rev g.      As rev f but added beep using PWM module.
; Rev h. 18/08/09 change to CAN config sequence. Change in sendTX1. Added beeps. 

; Rev k.      (no rev i or j). Added clear of COMSTAT and Tx1con in setup
;           Added clear of Tx1con in sendTXa. Changes to enum sequence.
;           Changed keepalive so it continues during programming etc. uses lpint with TMR0.

; Rev m       (no rev l)major changes for service mode programming. 
; Rev n       same as Rev m but for bootload

; Rev p       (no rev o) moved LCD strings to flash. Not enough room in eeprom
;         added FR2 support. added speed step select. 
;         modified speed display to blank leading zeros and for different speed steps

; Rev q. 15/12/09 Changed response to master reset so EEPROM is reset
;         modified loco release to stop speed / dir and keepalives  

; Rev r. 05/02/10 Fix in long address for CV number CV sent = CV and not CV-1
;         Mods to bootloader for WDT and LEDs. Fixed beep problem.
;         Modified speed so display starts at 1 but sent speed still 2.
;         Change to consist set direction bit
;         Correction to cv_ans 
 
; Rev s 16/03/10  Changed so Handle is cleared to 0xFF on reset or release.  
;         cv_ans also changed so non-selected cabs don't show CV answers

; Rev t       Change in RTR response sequence
; Rev u  23/03/10 Major change for new enum scheme.
 
; Rev v  26/11/10 PNB - Double press of emergency stop does emergency stop all 
; Rev w       PNB - Emergency stop all now also works when zero speed set
;         Sorted out some display issues during stop all
; Rev x  26/12/10 PNB - Set emergency stop mode in response to "track stopped" packet as well as stop request
;             Reinstate stop message after programming whilst in emergency stop
;             Display banner and firmware version at startup - timer 0 used for banner display time
; Rev y 05/03/11    RKH - Add CAB Node Id to parameters, set version to "Y"
; Rev y 07/03/11  MB - Mods so config can read individual node parameters using RQNPN  (0x73)
;         Displayed version letter is now that in the params table.
; Rev 2a 28/3/11  PNB - Reconciled Mike's and Roger's changes, moved definition of parameter sequence to inc file
;             Added display of both major and minor version to LCD display
;             Added build number just to be displayed for test versions to confirm bootloading
;             Changed default from prog to read CV in service mode programming
; Rev 2b 8/4/11   PNB - Fixed displaying prog or read correctly (but introduced when making read the default in ver 2a)
;             Fixed blank screen when turning knob to zero during emergency stop all with no loco selected (now displays loco prompt)
;             Loco prompt now a separate subroutine
; Rev 2c 29/4/11    PNB - Changed strings to null terminated (so msbit set chars can be used - required for some languages)
;                         String table can now exceed 255 bytes (lcd_str changed)
;             String table now a separate include file
;             Custom character table added which is loaded into the LCD CG RAM at startup, default is French chars with accents
;             When built as a test version (uncomment test_ver below), press Prog when no loco to display custom chars
; Rev2d 2/5/11    PNB - String table now uses db "string" rather than db "s","t","r","i","n","g" for better readability
;             Messages added for all features on wishlist, so language files will not be obsoleted as features are implemented
;             Service mode messages moved to start of table, so no risk of them wrapping around 256 byte boundary as messages added.
;             Better instructions in cabmessages.inc for those doing translations.
;             Test mode sequences through all messages 

; 
; Assembly options
  LIST  P=18F2480,r=hex,N=75,C=120,T=ON

  include   "p18f2480.inc"
  
  ;definitions  Change these to suit hardware.

  include "cbuslib/cbusdefs.inc"  
  include "cabmessages.inc"

; Define the node parameters to be stored at node_id

Man_no      equ MANU_MERG ;manufacturer number
Major_Ver equ 2 
Minor_Ver equ "d"   
Module_id   equ MTYP_CANCAB ; id to identify this type of module
EVT_NUM     equ 0           ; Number of events
EVperEVT    equ 0           ; Event variables per event
NV_NUM      equ 0           ; Number of node variables  

; test_ver  equ 1     ; A test version not to be distributed - comment out for release versions
build_no  equ 6     ; Displayed on LCD at startup for test versions only  



; note. there seem to be differences in the naming of the CONFIG parameters between
; versions of the p18F2480.inf files

  CONFIG  FCMEN = OFF, OSC = HSPLL, IESO = OFF
  CONFIG  PWRT = ON,BOREN = BOHW, BORV=1
  CONFIG  WDT=ON, WDTPS = 16
  CONFIG  MCLRE = ON
  CONFIG  LPT1OSC = OFF, PBADEN = OFF
  CONFIG  DEBUG = OFF
  CONFIG  XINST = OFF,LVP = OFF,STVREN = ON,CP0 = OFF
  CONFIG  CP1 = OFF, CPB = OFF, CPD = OFF,WRT0 = OFF,WRT1 = OFF, WRTB = OFF
  CONFIG  WRTC = OFF,WRTD = OFF, EBTR0 = OFF, EBTR1 = OFF, EBTRB = OFF

;original config left for reference
;set config registers
  
; __CONFIG  _CONFIG1H,  B'00100110' ;oscillator HS with PLL
; __CONFIG  _CONFIG2L,  B'00001110' ;brown out voltage and PWT  
; __CONFIG  _CONFIG2H,  B'00000000' ;watchdog time and enable (disabled for now)
; __CONFIG  _CONFIG3H,  B'10000000' ;MCLR enable  
; __CONFIG  _CONFIG4L,  B'10000001' ;B'10000001'  for   no debug
; __CONFIG  _CONFIG5L,  B'00001111' ;code protection (off)  
; __CONFIG  _CONFIG5H,  B'11000000' ;code protection (off)  
; __CONFIG  _CONFIG6L,  B'00001111' ;write protection (off) 
; __CONFIG  _CONFIG6H,  B'11100000' ;write protection (off) 
; __CONFIG  _CONFIG7L,  B'00001111' ;table read protection (off)  
; __CONFIG  _CONFIG7H,  B'01000000' ;boot block protection (off)

; processor uses  4 MHz. Resonator

;********************************************************************************

;   definitions used by CAB

LCD_PORT equ  PORTC
LCD_EN   equ  1
LCD_RS   equ  3


; definitions used by bootloader

#define MODE_SELF_VERIFY  ;Enable self verification of written data (undefine if not wanted)

#define HIGH_INT_VECT 0x0808  ;HP interrupt vector redirect. Change if target is different
#define LOW_INT_VECT  0x0818  ;LP interrupt vector redirect. Change if target is different.
#define RESET_VECT  0x0800  ;start of target
#define CAN_CD_BIT  RXB0EIDL,0  ;Received control / data select bit
#define CAN_PG_BIT  RXB0EIDL,1  ;Received PUT / GET bit
#define CANTX_CD_BIT  TXB0EIDL,0  ;Transmit control/data select bit
#define CAN_TXB0SIDH  B'10000000' ;Transmitted ID for target node
#define CAN_TXB0SIDL  B'00001000'
#define CAN_TXB0EIDH  B'00000000' ;
#define CAN_TXB0EIDL  B'00000100'
#define CAN_RXF0SIDH  B'00000000' ;Receive filter for target node
#define CAN_RXF0SIDL  B'00001000'
#define CAN_RXF0EIDH  B'00000000'
#define CAN_RXF0EIDL  B'00000111'
#define CAN_RXM0SIDH  B'11111111' ;Receive masks for target node
#define CAN_RXM0SIDL  B'11101011'
#define CAN_RXM0EIDH  B'11111111'
#define CAN_RXM0EIDL  B'11111000'
#define CAN_BRGCON1   B'00000011' ;CAN bit rate controls. As for other CBUS modules
#define CAN_BRGCON2   B'10011110'
#define CAN_BRGCON3   B'00000011'
#define CAN_CIOCON    B'00100000' ;CAN I/O control  
; ************************************************************ ** * * * * * * * * * * * * * * *
; ************************************************************ ** * * * * * * * * * * * * * * *
#ifndef EEADRH    
#define EEADRH  EEADR+ 1  
#endif      
#define TRUE  1 
#define FALSE 0 
#define WREG1 PRODH ; Alternate working register
#define WREG2 PRODL 
#define MODE_WRT_UNLCK  _bootCtlBits, 0 ; Unlock write and erase
#define MODE_ERASE_ONLY _bootCtlBits, 1 ; Erase without write
#define MODE_AUTO_ERASE _bootCtlBits, 2 ; Enable auto erase before write
#define MODE_AUTO_INC _bootCtlBits, 3 ; Enable auto inc the address
#define MODE_ACK    _bootCtlBits, 4 ; Acknowledge mode
#define ERR_VERIFY    _bootErrStat, 0 ; Failed to verify if set
#define CMD_NOP     0x00  
#define CMD_RESET   0x01  
#define CMD_RST_CHKSM 0x02  
#define CMD_CHK_RUN   0x03
#define CMD_BOOT_TEST   0x04  



;****************************************************************
; define RAM storage

; RAM addresses used by boot. can also be used by application.

  CBLOCK 0
  _bootCtlMem
  _bootAddrL    ; Address info
  _bootAddrH    
  _bootAddrU    
  _unused0    ;(Reserved)
  _bootCtlBits  ; Boot Mode Control bits
  _bootSpcCmd   ; Special boot commands
  _bootChkL   ; Chksum low byte fromPC
  _bootChkH   ; Chksum hi byte from PC    
  _bootCount    
  _bootChksmL   ; 16 bit checksum
  _bootChksmH   
  _bootErrStat  ;Error Status flags
  ENDC
  
  ; end of bootloader RAM
  
  CBLOCK  0   ;file registers - access bank
          ;interrupt stack for low priority
          ;hpint uses fast stack
          ;save on interrupt only used if needed.
  W_tempL
  St_tempL
  Bsr_tempL
  PCH_tempH   ;save PCH in hpint
  PCH_tempL   ;save PCH in lpint (if used)
  Fsr_temp0L    ;temps for FSRs
  Fsr_temp0H 
  Fsr_temp1L
  Fsr_temp1H 
  Fsr_temp2L
  Fsr_temp2H
  Fsr_temp0Li   ;temps for FSRs in LPINT
  Fsr_temp0Hi 
  Fsr_temp1Li
  Fsr_temp1Hi 
  Fsr_temp2Li
  Fsr_temp2Hi
  
  TempCANCON
  TempCANSTAT
  TempINTCON
  CanID_tmp ;temp for CAN Node ID
  IDtemph   ;used in ID shuffle
  IDtempl
  W_temp    ;temp store for W reg
  NN_temph  ;node number in RAM
  NN_templ
  
  IDcount   ;used in self allocation of CAN ID.
  Datmode   ;flag for data waiting and other states
                ;Bit 0 set if valid CAN frame to be processed
  Count   ;counter for loading
  Count1
  Count2
  Keepcnt   ;keep alive counter
  Latcount  ;latency counter

  Temp    ;temps
  Temp1
  Err_tmp
  Intemp
  Intemp1
  Inbit
  Incount
  Input
  Atemp   ;port a temp value
  Dlc     ;data length

  Key     ;key number
  Key_temp  ;for debounce
  Debcount  ;debounce counter
  Keyflag   ;keyboard mode

  Adtemp    ;temp for speed
  Speed   ;current speed value from A/D
  Speed1    ;speed to send to loco
  Speed2    ;used in speed to ASCII conversion
  Emspeed   ;holds Em stop speed - not used!
  Smode   ;speed step mode
  
  Handle    ;handle given by CS
  Modstat   ;node status. Used when finding a CAN_ID and handle.
        ;bit 0 set if it has CANid
        ;bit 1 set if waiting for handle
        ;bit 2 set if checking handle on reset.
        ;bit 3 set if reset by CBUS command
        ;bit 4 set if needing keepalive
        ;bit 5 set when stop button pressed (flag for emergency stop all)
        ;bit 6 set during startup banner/version display

  Locstat   ;status of loco and cab
        ;bit 0  loco selected
        ;bit 1  loco release
        ;bit 2  consist set
        ;bit 3  a numeric key
        ;bit 4  em. stop
        ;bit 5  consist clear
        ;bit 6  program mode
        ;bit 7  is direction, 1 is foward

  
  Char    ;store char for LCD
  Adr1    ;ASCII address
  Adr2
  Adr3
  Adr4

  Num1    ;numeric input values
  Num2
  Num3
  Num4
  Numcount  ;numbers entered
  Numtemp   ;save number for display
  Numtemp1  ;additional save for service mode display
  Numcv   ;number of digits in CV number
  Numcvv    ;number of digits in CV value
  Adr_hi    ;address hi byte
  Adr_lo    ;address lo byte
  Hi_temp   ;address hi byte in hex to ascii conversion
  Lo_temp   ;address lo byte in hex to ascii conversion
  Spd1    ;ASCII speed
  Spd2
  Spd3

  Fr1     ;function bits  0 to 4
  Fr2     ;function bits  5 to 8
  Fr3     ;function bits  9 to 12
  Fr4     ;function bits  13 to 20
  Fr5     ;function bits  21 to 28
  Funtemp
  Fnmode    ;flags for function mode

  Conadr    ;consist address (hex)
  
  Con1    ;consist numbers
  Con2
  Con3

  Progmode    ;program mode flags
          ;bit 0    ready to enter CV number
          ;bit 1    consist mode
          ;bit 2    ready for CV value
          ;bit 3    ready to send
          ;bit 4    set for service mode
          ;bit 5    set for speed step mode 
          ;bit 6
          ;bit 7

  Sermode     ;mode when in service
          ; 0 is direct
          ; 1 is page
          ; 2 is register
          ; 3 is address if needed
          ; bit 2 is 1 for read and 0 for write

  CVnum_hi    ;hex value of CV number
  CVnum_lo
  CV_1    ;ASCII values of CV number
  CV_2
  CV_3
  CV_4
  CVnum1    ;entered CV number (4 digits max)
  CVnum2
  CVnum3
  CVnum4
  
  CVval   ;CV value  Hex
  CVval1    ;entered CV value (3 digits)
  CVval2
  CVval3
  CVchr2    ;for CV read
  CV1
  CV2
  CV3

  L_adr_hi
  L_adr_lo
  La_1    ;ASCII values of long address number (prog)
  La_2
  La_3
  La_4
  L_adr1    ;long address for programming
  L_adr2
  L_adr3
  L_adr4
  
  Setupmode ; Status of setup mode
        ;bit 0  Prog pressed oncde for setup mode
                ;bit 1  Prog pressed again - now in setup mode

  TststrL   ; Address of current test string
    TststrH   ;


          ;the above variables must be in access space (00 to 5F)
        
    
  Rx0con      ;start of receive packet 0
  Rx0sidh
  Rx0sidl
  Rx0eidh
  Rx0eidl
  Rx0dlc
  Rx0d0
  Rx0d1
  Rx0d2
  Rx0d3
  Rx0d4
  Rx0d5
  Rx0d6
  Rx0d7
  
  Cmdtmp    ;command temp for number of bytes in frame jump table
  
  
  
  
  Eadr    ;temp eeprom address
  
  Tx1con      ;start of transmit frame  1
  Tx1sidh
  Tx1sidl
  Tx1eidh
  Tx1eidl
  Tx1dlc
  Tx1d0
  Tx1d1
  Tx1d2
  Tx1d3
  Tx1d4
  Tx1d5
  Tx1d6
  Tx1d7

  Roll    ;rolling bit for enum
  
  Fsr_tmp1Le  ;temp store for FSR1
  Fsr_tmp1He 
  Enum0   ;bits for new enum scheme.
  Enum1
  Enum2
  Enum3
  Enum4
  Enum5
  Enum6
  Enum7
  Enum8
  Enum9
  Enum10
  Enum11
  Enum12
  Enum13
  
  ;add variables to suit

    
  ENDC
  

; This is the bootloader section

;*  Filename Boot2.asm  30/10/09

;*************************************************************** * * * * * * * * * * * * * * ;*
;*  CBUS bootloader

;*  Based on the Microchip botloader 'canio.asm' tho which full acknowledgement is made.
;*  Relevant information is contained in the Microchip Application note AN247

;*
;* Basic Operation:
;* The following is a CAN bootloader designed for PIC18F microcontrollers
;* with built-in CAN such as the PIC18F458. The bootloader is designed to
;* be simple, small, flexible, and portable.
;*
;
;
;*
;* Commands:
;* Put commands received from source (Master --> Slave)
;* The count (DLC) can vary.
;* XXXXXXXXXXX 0 0 8 XXXXXXXX XXXXXX00 ADDRL ADDRH ADDRU RESVD CTLBT SPCMD CPDTL CPDTH
;* XXXXXXXXXXX 0 0 8 XXXXXXXX XXXXXX01 DATA0 DATA1 DATA2 DATA3 DATA4 DATA5 DATA6 DATA7
;*


;*
;* ADDRL - Bits 0 to 7 of the memory pointer.
;* ADDRH - Bits 8 - 15 of the memory pointer.
;* ADDRU - Bits 16 - 23 of the memory pointer.
;* RESVD - Reserved for future use.
;* CTLBT - Control bits.
;* SPCMD - Special command.
;* CPDTL - Bits 0 - 7 of 2s complement checksum
;* CPDTH - Bits 8 - 15 of 2s complement checksum
;* DATAX - General data.
;*
;* Control bits:
;* MODE_WRT_UNLCK-Set this to allow write and erase operations to memory.
;* MODE_ERASE_ONLY-Set this to only erase Program Memory on a put command. Must be on 64-byte
;*  boundary.
;* MODE_AUTO_ERASE-Set this to automatically erase Program Memory while writing data.
;* MODE_AUTO_INC-Set this to automatically increment the pointer after writing.
;* MODE_ACK-Set this to generate an acknowledge after a 'put' (PG Mode only)
;*
;* Special Commands:
;* CMD_NOP      0x00  Do nothing
;* CMD_RESET    0x01  Issue a soft reset after setting last EEPROM data to 0x00
;* CMD_RST_CHKSM  0x02  Reset the checksum counter and verify
;* CMD_CHK_RUN    0x03  Add checksum to special data, if verify and zero checksum
;* CMD_BOOT_TEST  0x04  Just sends a message frame back to verify boot mode.

;*  Modified version of the Microchip code by M Bolton  30/10/09
;
; The user program must have the folowing vectors

; User code reset vector  0x0800
; User code HPINT vector  0x0808
; user code LPINT vector  0x0818

; Checksum is 16 bit addition of all programmable bytes.
; User sends 2s complement of addition at end of program in command 0x03 (16 bits only)

;**********************************************************************************
  


; This is the bootloader
; ***************************************************************************** 
;_STARTUPCODE 0x00
  ORG 0x0000
; *****************************************************************************
  bra _CANInit
  bra _StartWrite
; ***************************************************************************** 
;_INTV_H CODE 0x08
  ORG 0x0008
; *****************************************************************************

  goto  HIGH_INT_VECT

; ***************************************************************************** 
;_INTV_L CODE 0x18
  ORG 0x0018
; *****************************************************************************

  goto  LOW_INT_VECT 

; ************************************************************** 
; Code start
; **************************************************************
  ORG 0x0020
;_CAN_IO_MODULE CODE
; ************************************************************ ** * * * * * * * * * * * * * * * 
; Function: VOID _StartWrite(WREG _eecon_data)
;PreCondition: Nothing
;Input: _eecon_data
;Output: Nothing. Self write timing started.
;Side Effects: EECON1 is corrupted; WREG is corrupted.
;Stack Requirements: 1 level.
;Overview: Unlock and start the write or erase sequence to protected
; memory. Function will wait until write is finished.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_StartWrite
  movwf   EECON1
  btfss   MODE_WRT_UNLCK  ; Stop if write locked
  return
  movlw   0x55  ; Unlock
  movwf    EECON2 
  movlw  0xAA 
  movwf    EECON2
  bsf  EECON1, WR ; Start the write
  nop
  btfsc   EECON1, WR  ; Wait (depends on mem type)
  bra $ - 2
  return
; ************************************************************ ** * * * * * * * * * * * * * * *

; Function: _bootChksm _UpdateChksum(WREG _bootChksmL)
;
; PreCondition: Nothing
; Input: _bootChksmL
; Output: _bootChksm. This is a static 16 bit value stored in the Access Bank.
; Side Effects: STATUS register is corrupted.
; Stack Requirements: 1 level.
; Overview: This function adds a byte to the current 16 bit checksum
; count. WREG should contain the byte before being called.
;
; The _bootChksm value is considered a part of the special
; register set for bootloading. Thus it is not visible. ;
;*************************************************************** * * * * * * * * * * * *
_UpdateChksum:
  addwf _bootChksmL,  F ; Keep a checksum
  btfsc STATUS, C
  incf  _bootChksmH,  F
  return
;************************************************************ ** * * * * * * * * * * * * * * *
;
; Function: VOID _CANInit(CAN,  BOOT)
;
; PreCondition: Enter only after a reset has occurred.
; Input: CAN control information, bootloader control information ; Output: None.
; Side Effects: N/A. Only run immediately after reset.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
; return when called. It has been written in a linear form to
; save space.Thus 'call' and 'return' instructions are not
; included, but rather they are implied. ;
; This routine tests the boot flags to determine if boot mode is
; desired or normal operation is desired. If boot mode then the
; routine initializes the CAN module defined by user input. It
; also resets some registers associated to bootloading.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CANInit:
  clrf  EECON1
  setf  EEADR ; Point to last location of EEDATA
  setf  EEADRH
  bsf EECON1, RD  ; Read the control code
  incfsz EEDATA, W

  goto  RESET_VECT


  clrf  _bootSpcCmd   ; Reset the special command register
  movlw   0x1C    ; Reset the boot control bits
  movwf   _bootCtlBits 
  movlb d'15'   ; Set Bank 15
  bcf   TRISB, CANTX  ; Set the TX pin to output 
  movlw   CAN_RXF0SIDH  ; Set filter 0
  movwf   RXF0SIDH
  movlw   CAN_RXF0SIDL 
  movwf   RXF0SIDL
  comf  WREG    ; Prevent filter 1 from causing a receive event





  movwf RXF1SIDL  ;   
  movlw CAN_RXF0EIDH  
  movwf RXF0EIDH  
  movlw CAN_RXF0EIDL  
  movwf RXF0EIDL  
  movlw CAN_RXM0SIDH  ; Set mask
  movwf RXM0SIDH  
  movlw CAN_RXM0SIDL  
  movwf RXM0SIDL  
  movlw CAN_RXM0EIDH  
  movwf RXM0EIDH  
  movlw CAN_RXM0EIDL  
  movwf RXM0EIDL  
  movlw CAN_BRGCON1 ; Set bit rate
  movwf BRGCON1 
  movlw CAN_BRGCON2 
  movwf BRGCON2 
  movlw CAN_BRGCON3 
  movwf BRGCON3 
  movlw CAN_CIOCON  ; Set IO
  movwf CIOCON  
  
  clrf  CANCON  ; Enter Normal mode
  movlw B'00001110'
  movwf ADCON1
  bcf TRISA,1
  bcf TRISA,2
  bsf PORTA,1   ;FWD LED on  Both LEDs on to indicate boot mode
  bsf PORTA,2   ;REV LED


; ************************************************************ ** * * * * * * * * * * * * * * * 
; This routine is essentially a polling loop that waits for a
; receive event from RXB0 of the CAN module. When data is
; received, FSR0 is set to point to the TX or RX buffer depending
; upon whether the request was a 'put' or a 'get'.
; ************************************************************ ** * * * * * * * * * * * * * * * 
_CANMain
  bcf RXB0CON, RXFUL  ; Clear the receive flag
_wait clrwdt      ; Clear WDT while waiting
  btfss   RXB0CON, RXFUL  ; Wait for a message  
  bra _wait



_CANMainJp1
  lfsr  0, RXB0D0
  movf  RXB0DLC, W 
  andlw   0x0F
  movwf   _bootCount 
  movwf   WREG1
  bz  _CANMain 
_CANMainJp2       ;?
  


; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _ReadWriteMemory()
;
; PreCondition:Enter only after _CANMain().
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
; return when called. It has been written in a linear form to
; save space.Thus 'call' and 'return' instructions are not
; included, but rather they are implied.
;This is the memory I/O engine. A total of eight data bytes are received and decoded. In addition two control bits are received, put/get and control/data.
;A pointer to the buffer is passed via FSR0 for reading or writing. 
;The control register set contains a pointer, some control bits and special command registers.
;Control
;<PG><CD><ADDRL><ADDRH><ADDRU><_RES_><CTLBT>< SPCMD><CPDTL><CPDTH>
;Data
;<PG>< CD>< DATA0>< DATA1>< DATA2>< DATA3>< DATA4>< DATA5>< DATA6>< DATA7>
;PG bit:  Put = 0, Get = 1
;CD bit:  Control = 0, Data = 1

; ************************************************************ ** * * * * * * * * * * * * * * *
_ReadWriteMemory:
  btfsc CAN_CD_BIT  ; Write/read data or control registers
  bra _DataReg
; ************************************************************ ** * * * * * * * * * * * * * * * ; This routine reads or writes the bootloader control registers,
; then executes any immediate command received.
_ControlReg
  lfsr  1, _bootAddrL   ;_bootCtlMem
_ControlRegLp1

  movff   POSTINC0, POSTINC1 
  decfsz  WREG1, F
  bra _ControlRegLp1

; ********************************************************* 
; This is a no operation command.
  movf  _bootSpcCmd, W    ; NOP Command
  bz  _CANMain
; bz  _SpecialCmdJp2    ; or send an acknowledge

; ********************************************************* 
; This is the reset command.
  xorlw   CMD_RESET   ; RESET Command 
  btfss   STATUS, Z
  bra   _SpecialCmdJp4
  setf  EEADR   ; Point to last location of EEDATA
  setf  EEADRH
  clrf  EEDATA    ; and clear the data (FF for now)
  movlw   b'00000100' ; Setup for EEData
  rcall   _StartWrite
  bcf   PORTB,6   ;yellow LED off
  reset
; *********************************************************
; This is the Selfcheck reset command. This routine 
; resets the internal check registers, i.e. checksum and 
; self verify.
_SpecialCmdJp4
  movf  _bootSpcCmd, W 
  xorlw   CMD_RST_CHKSM
  bnz   _SpecialCmdJp1
  clrf  _bootChksmH
  clrf  _bootChksmL
  bcf   ERR_VERIFY    
  clrf  _bootErrStat
  bra   _CANMain
; RESET_CHKSM Command
; Reset chksum
; Clear the error verify flag

;This is the Test and Run command. The checksum is
; verified, and the self-write verification bit is checked. 
; If both pass, then the boot flag is cleared.
_SpecialCmdJp1
  movf  _bootSpcCmd, W    ; RUN_CHKSM Command
  xorlw   CMD_CHK_RUN 
  bnz _SpecialCmdJp3
  movf  _bootChkL, W  ; Add the control byte
  addwf  _bootChksmL, F
  bnz _SpecialCmdJp2
  movf  _bootChkH, W 
  addwfc  _bootChksmH, F
  bnz _SpecialCmdJp2
  btfsc   ERR_VERIFY    ; Look for verify errors
  bra _SpecialCmdJp2

  bra   _CANSendOK  ;send OK message


_SpecialCmdJp2

  bra _CANSendNOK ; or send an error acknowledge


_SpecialCmdJp3
  movf  _bootSpcCmd, W    ; RUN_CHKSM Command
  xorlw   CMD_BOOT_TEST 
  bnz _CANMain
  bra _CANSendBoot

; ************************************************************** * * * * * * * * * * * * * * * 
; This is a jump routine to branch to the appropriate memory access function.
; The high byte of the 24-bit pointer is used to determine which memory to access. 
; All program memories (including Config and User IDs) are directly mapped. 
; EEDATA is remapped.
_DataReg
; *********************************************************
_SetPointers
  movf  _bootAddrU, W ; Copy upper pointer
  movwf   TBLPTRU
  andlw   0xF0  ; Filter
  movwf   WREG2
  movf  _bootAddrH, W ; Copy the high pointer
  movwf   TBLPTRH
  movwf   EEADRH
  movf  _bootAddrL, W ; Copy the low pointer
  movwf   TBLPTRL
  movwf  EEADR
  btfss   MODE_AUTO_INC ; Adjust the pointer if auto inc is enabled
  bra _SetPointersJp1
  movf  _bootCount, W ; add the count to the pointer
  addwf  _bootAddrL, F 
  clrf  WREG
  addwfc   _bootAddrH, F 
  addwfc   _bootAddrU, F 

_SetPointersJp1     ;?

_Decode
  movlw   0x30
  cpfslt  WREG2
  bra _DecodeJp1



  bra _PMEraseWrite

_DecodeJp1
  movf  WREG2,W
  xorlw   0x30
  bnz _DecodeJp2



  bra _CFGWrite 
_DecodeJp2
  movf  WREG2,W 
  xorlw 0xF0
  bnz _CANMain
  bra _EEWrite

f 

; Program memory < 0x300000
; Config memory = 0x300000
; EEPROM data = 0xF00000
  
; ************************************************************ ** * 
; ************************************************************** * 
; Function: VOID _PMRead()
; VOID _PMEraseWrite ()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
; the source data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
; return when called. They have been written in a linear form to
; save space.Thus 'call' and 'return' instructions are not
; included, but rather they are implied.
;These are the program memory read/write functions. Erase is available through control flags. An automatic erase option is also available.
; A write lock indicator is in place to ensure intentional write operations.
;Note: write operations must be on 8-byte boundaries and must be 8 bytes long. Also erase operations can only occur on 64-byte boundaries.
; ************************************************************ ** * * * * * * * * * * * * * * *



_PMEraseWrite:
  btfss   MODE_AUTO_ERASE
  bra _PMWrite
_PMErase:
  movf  TBLPTRL, W
  andlw b'00111111'
  bnz _PMWrite
_PMEraseJp1
  movlw b'10010100' 
  rcall   _StartWrite 
_PMWrite:
  btfsc   MODE_ERASE_ONLY


  bra _CANMain 

  movf  TBLPTRL, W
  andlw b'00000111'
  bnz _CANMain 
  movlw   0x08
  movwf WREG1

_PMWriteLp1         ; Load the holding registers
  movf  POSTINC0, W 
  movwf   TABLAT
  rcall  _UpdateChksum  ; Adjust the checksum
  tblwt*+
  decfsz   WREG1, F
  bra _PMWriteLp1

#ifdef MODE_SELF_VERIFY 
  movlw  0x08
  movwf   WREG1 
_PMWriteLp2
  tblrd*-     ; Point back into the block
  movf  POSTDEC0, W 
  decfsz   WREG1, F
  bra _PMWriteLp2
  movlw  b'10000100'  ; Setup writes
  rcall _StartWrite   ; Write the data
  movlw   0x08
  movwf   WREG1
_PMReadBackLp1
  tblrd*+     ; Test the data
  movf  TABLAT, W 
  xorwf   POSTINC0, W
  btfss STATUS, Z
  bsf ERR_VERIFY 
  decfsz  WREG1, F
  bra _PMReadBackLp1  ; Not finished then repeat
#else
  tblrd*-     ; Point back into the block
         ; Setup writes
  movlw   b'10000100'   ; Write the data
  rcall   _StartWrite   ; Return the pointer position
  tblrd*+
#endif

  bra _CANMain


; ************************************************************** * * * * * * * * * * * * * * *
 ; Function: VOID _CFGWrite()
; VOID _CFGRead()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of the source data. 
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
; return when called. They have been written in a linear form to
; save space. Thus 'call' and 'return' instructions are not
; included, but rather they are implied.
;
; These are the Config memory read/write functions. Read is
; actually the same for standard program memory, so any read
; request is passed directly to _PMRead.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CFGWrite

#ifdef MODE_SELF_VERIFY   ; Write to config area
  movf  INDF0, W    ; Load data
#else
  movf  POSTINC0, W
#endif
  movwf   TABLAT
  rcall   _UpdateChksum ; Adjust the checksum
  tblwt*      ; Write the data
  movlw b'11000100' 
  rcall   _StartWrite
  tblrd*+     ; Move the pointers and verify
#ifdef MODE_SELF_VERIFY 
  movf  TABLAT, W 
  xorwf   POSTINC0, W

#endif
  decfsz  WREG1, F
  bra _CFGWrite ; Not finished then repeat

  bra _CANMain 



; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _EERead()
; VOID _EEWrite()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
 ;  the source data.
; Input:  None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
; return when called. They have been written in a linear form to
; save space. Thus 'call' and 'return' instructions are not
; included, but rather they are implied.
;
; This is the EEDATA memory read/write functions.
;
; ************************************************************ ** * * * * * * * * * * * * * * *


_EEWrite:

#ifdef MODE_SELF_VERIFY
  movf  INDF0, W
#else
  movf  POSTINC0, W 
#endif

  movwf   EEDATA
  rcall   _UpdateChksum 
  movlw b'00000100' 
  rcall  _StartWrite

#ifdef MODE_SELF_VERIFY 
  clrf  EECON1
  bsf EECON1, RD
  movf  EEDATA, W 
  xorwf   POSTINC0, W
  btfss STATUS, Z
  bsf ERR_VERIFY
#endif

  infsnz   EEADR, F 
  incf  EEADRH, F 
  decfsz  WREG1, F
  bra _EEWrite


  bra _CANMain 
  

; Read the data

; Adjust EEDATA pointer
; Not finished then repeat
; Load data
; Adjust the checksum 
; Setup for EEData
; and write
; Read back the data ; verify the data ; and adjust pointer
; Adjust EEDATA pointer
; Not finished then repeat

; ************************************************************** * * * * * * * * * * * * * * *
; Function: VOID _CANSendAck()
; VOID _CANSendResponce ()
;
; PreCondition:TXB0 must be preloaded with the data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
; return when called. They have been written in a linear form to
; save space. Thus 'call' and 'return' instructions are not
; included, but rather they are implied. ;
; These routines are used for 'talking back' to the source. The
; _CANSendAck routine sends an empty message to indicate
; acknowledgement of a memory write operation. The
; _CANSendResponce is used to send data back to the source. ;
; ************************************************************ ** * * * * * * * * * * * * * * *



_CANSendMessage
  btfsc   TXB0CON,TXREQ 
  bra $ - 2
  movlw   CAN_TXB0SIDH 
  movwf   TXB0SIDH
  movlw   CAN_TXB0SIDL 
  movwf   TXB0SIDL
  movlw   CAN_TXB0EIDH 
  movwf   TXB0EIDH  

  movlw CAN_TXB0EIDL
  movwf TXB0EIDL
  bsf CANTX_CD_BIT
  btfss CAN_CD_BIT 
  bcf CANTX_CD_BIT
  bsf TXB0CON, TXREQ
      bra  _CANMain ; Setup the command bit

_CANSendOK        ;send OK message 
  movlw 1     ;a 1 is OK
  movwf TXB0D0
  movwf TXB0DLC
  bra   _CANSendMessage
  
_CANSendNOK       ;send not OK message
  clrf  TXB0D0    ;a 0 is not OK
  movlw 1
  movwf TXB0DLC
  bra   _CANSendMessage

_CANSendBoot
  movlw 2     ;2 is confirm boot mode
  movwf TXB0D0
  movlw 1
  movwf TXB0DLC
  bra   _CANSendMessage
    
; Start the transmission

;   End of bootloader 

;****************************************************************
;
;   start of program code

    ORG   0800h
    nop           ;for debug
    goto  setup

    ORG   0808h
    goto  hpint     ;high priority interrupt
    
    ORG   0810h     ;node type parameters
node_ID db    Man_no, Minor_Ver, Module_id, EVT_NUM, EVperEVT, NV_NUM, Major_Ver

    ORG   0818h 
    goto  lpint     ;low priority interrupt


;*******************************************************************

    ORG   0820h     ;start of program
; 
;
;   high priority interrupt. Used for CAN receive and transmit error.

hpint movff CANCON,TempCANCON
    movff CANSTAT,TempCANSTAT
  
    movff FSR0L,Fsr_temp0L    ;save FSR0
    movff FSR0H,Fsr_temp0H
    movff FSR1L,Fsr_temp1L    ;save FSR1
    movff FSR1H,Fsr_temp1H
    
    

    movlw 8
    movwf PCLATH
    movf  TempCANSTAT,W     ;Jump table
    andlw B'00001110'
    addwf PCL,F     ;jump
    bra   back
    bra   errint      ;error interrupt
    bra   back
    bra   back
    bra   back
    bra   rxb1int     ;only receive interrupts used
    bra   rxb0int
    bra   back
    
rxb1int bcf   PIR3,RXB1IF   ;uses RB0 to RB1 rollover so may never use this
    
    lfsr  FSR0,Rx0con   ;
    
    goto  access
    
rxb0int bcf   PIR3,RXB0IF
    btfsc Datmode,1     ;setup mode?
    bra   setmode 
    lfsr  FSR0,Rx0con
    
    goto  access
    
    ;error routine here. Only acts on lost arbitration  
errint  movlb .15         ;change bank      
    btfss TXB1CON,TXLARB
    bra   errbak        ;not lost arb.
    movf  Latcount,F      ;is it already at zero?
    bz    errbak
    decfsz  Latcount,F
    bra   errbak
    bcf   TXB1CON,TXREQ
    movlw B'00111111'
    andwf TXB1SIDH,F      ;change priority
txagain bsf   TXB1CON,TXREQ   ;try again
          
errbak  movlb 0
;   clrf  COMSTAT     ;clear error flags if any
    bcf   RXB0CON,RXFUL ;ready for next
    bcf   RXB1CON,RXFUL
    bcf   COMSTAT,RXB0OVFL  ;clear overflow flags if set
    bcf   COMSTAT,RXB1OVFL    
    bra   back1

access  movf  CANCON,W        ;switch buffers
    andlw B'11110001'
    movwf CANCON
    movf  TempCANSTAT,W
    andlw B'00001110'
    iorwf CANCON
    lfsr  FSR1,RXB0CON  ;this is switched bank
load  movf  POSTINC1,W
    movwf POSTINC0
    movlw 0x6E      ;end of access buffer lo byte
    cpfseq  FSR1L
    bra   load
    bcf   RXB0CON,RXFUL
    
    btfsc Rx0dlc,RXRTR    ;is it RTR?
    bra   isRTR
;   btfsc Datmode,1     ;setup mode?
;   bra   setmode 
    movf  Rx0dlc,F
    bz    back
    bsf   Datmode,0   ;valid message frame  
    
back  bcf   RXB0CON,RXFUL ;ready for next
  
  
back1 clrf  PIR3      ;clear all flags
    movf  CANCON,W
    andlw B'11110001'
    iorwf TempCANCON,W
    
    movwf CANCON
    movff Fsr_temp0L,FSR0L    ;recover FSR0
    movff Fsr_temp0H,FSR0H
    movff Fsr_temp1L,FSR1L    ;recover FSR1
    movff Fsr_temp1H,FSR1H

    
    retfie  1       ;use shadow registers
    
isRTR btfss Modstat,0   ;has got a CAN ID ?
    bra   back      ;no, so do nothing
    movlb .15
    ;clrf TXB2CON
isRTR1  btfsc TXB2CON,TXREQ ;wait till clear
    bra   isRTR1
    bsf   TXB2CON,TXREQ ;send ID frame - preloaded in TXB2

    movlb 0
    bra   back

setmode tstfsz  RXB0DLC
    bnz   back        ;only zero length frames for setup

    swapf RXB0SIDH,W      ;get ID into one byte
    rrcf  WREG
    andlw B'01111000'     ;mask
    movwf Temp
    swapf RXB0SIDL,W
    rrncf WREG
    andlw B'00000111'
    iorwf Temp,W
    movwf IDcount       ;has current incoming CAN_ID

    lfsr  FSR1,Enum0      ;set enum to table
enum_st clrf  Roll        ;start of enum sequence
    bsf   Roll,0
    movlw 8
enum_1  cpfsgt  IDcount
    bra   enum_2
    subwf IDcount,F     ;subtract 8
    incf  FSR1L       ;next table byte
    bra   enum_1
enum_2  dcfsnz  IDcount,F
    bra   enum_3
    rlncf Roll,F
    bra   enum_2
enum_3  movf  Roll,W
    iorwf INDF1,F

    
;   call  shuffin       ;get CAN ID as a single byte in W
;   cpfseq  IDcount
;   bra   back        ;not equal
;   incf  IDcount,F
;   movlw 0x63        ;99 max
;   cpfslt  IDcount       ;too many?
;   decf  IDcount,F     ;stay at 99
    bra   back


;**************************************************************
;
;
;   low priority interrupt. Used for keepalive and title delay
; 

lpint movwf W_tempL       
    movff STATUS,St_tempL
    movff FSR0L,Fsr_temp0Li
    movff FSR0H,Fsr_temp0Hi 
    movff FSR1L,Fsr_temp1Li
    movff FSR1H,Fsr_temp1Hi 
    movff FSR2L,Fsr_temp2Li
    movff FSR2H,Fsr_temp2Hi
    bcf   INTCON,TMR0IF ;clear flag
    btfsc Modstat,4   ;no keepalive
    call  kp_pkt      ;send speed packet
    btfsc Modstat,6   ;Delay for title
    call  clear_title   ;clear title from display
    movff Fsr_temp0Li,FSR0L
    movff Fsr_temp0Hi,FSR0H
    movff Fsr_temp1Li,FSR1L
    movff Fsr_temp1Hi,FSR1H
    movff Fsr_temp2Li,FSR2L
    movff Fsr_temp2Hi,FSR2H
    movf  W_tempL,W
    movff St_tempL,STATUS 
    retfie  
        
        
  
            
        
  
                

;*********************************************************************

main  
    
    

    
  
  
main1 ;clrwdt         ;clear watchdog
    btfss PIR1,TMR1IF
    bra   main1c
    bcf   T2CON,TMR2ON  ;beep off
    bcf   T1CON,TMR1ON
    bcf   PIR1,TMR1IF

main1c  clrwdt          ;clear watchdog
    btfss PIR1,TMR1IF   ;beep end?
    bra   main1b
    bcf   T1CON,TMR1ON    

main1b  btfsc Datmode,0   ;any new CAN frame received?
    bra   packet      ;yes
    btfss PIR2,TMR3IF   ;is it time for an A/D
    bra   main1a
    bcf   PIR2,TMR3IF
    call  a_to_d      ;get speed
main1a  btfss Locstat,4   ;in em. stop mode?
    bra   main2
    movlw 1
    movwf Speed1
    movf  Speed,F     ;is speed zero?
    bnz   main3     ;do nothing
    bcf   Locstat,4   ;clear em. stop
    movff Speed,Speed1
    call  lcd_clr
    call  spd_pkt
    bra   main3
main2 btfss Datmode,2   ;speed change?
    bra   main3     ; no - so back to keypad scan
    movf  Speed,F     ; yes - is it a non zero speed?
    bz    sndspd
    btfss Modstat,5   ; Are we coming out of stop all?
    bra   sndspd      
    call  lcd_clr     ; If so, clear message
    bcf   Modstat,5   ; and clear stopped flag
    btfsc Locstat,0   ;any loco selected?
        bra   sndspd      ;yes, so continue as normal
    call  locprmpt    ; Display loco prompt again
sndspd  call  spd_pkt     

                
    ;kaypad scanning routine

main3 btfsc Keyflag,0
    bra   keyup
    btfsc Key,7     ;key detected?
    bra   deb       ;debounce
    call  scan      ;scan inputs for change
  
    btfsc Key,7     ;any key?
    movff Key,Key_temp
    bra   main
deb   clrwdt
    decfsz  Debcount    ;count from FF to 00
    bra   main
    call  scan
    btfsc Key,7     ;no key now
    bra   chk_key
    
    clrf  Key
  
    goto  main
  
chk_key movf  Key,W     ;get key
    subwf Key_temp,W
    bz    key_OK      ;valid key
    clrf  Key
    goto  main

keyup btfsc Keyflag,1
    bra   debclear    ;release bebounce
    call  scan
    btfsc Key,7     ;released?
    goto  main
    bsf   Keyflag,1   ;set for release debounce
    clrf  Debcount
    bra   main
debclear    decfsz  Debcount
    bra   main      ;loop till out
    call  scan      ;check again
    btfss Key,7     ;not released now
    bra   keyup1
    bcf   Keyflag,1
    bra   main
    
keyup1  clrf  Keyflag     ;ready for next
    btfss Locstat,0
    goto  main
    btfss Locstat,3   ;was a FN?
    bra   keyup2
    call  lcd_clr
    call  loco_lcd
keyup2  bcf   Locstat,3
    movf  Fnmode,F
    bz    main
    btfss Fnmode,0
    bra   fr2lbl
    call  lcd_clr
    call  loco_lcd
    movlw HIGH Fr1lbl
    movwf TBLPTRH           
    movlw LOW Fr1lbl  
    call  lcd_str
    goto  main
fr2lbl  call  lcd_clr
    call  loco_lcd
    movlw HIGH Fr2lbl
    movwf TBLPTRH           
    movlw LOW Fr2lbl
    call  lcd_str
    goto  main  
        
key_OK  movlw LOW Keytbl      ;get key value
    movwf EEADR
    movf  Key_temp,W
    andlw B'01111111'
    addwf EEADR,F
    call  eeread
    movwf Key_temp    ;actual key value
    movlw 0x09
    cpfsgt  Key_temp
    bra   number
    movlw 0x0A      ;DIR?
    subwf Key_temp,W
    bz    dir
    movlw 0x0B      ;EM STOP
    subwf Key_temp,W
    bz    emstop
    movlw 0x0C      ;Consist
    subwf Key_temp,W
    bz    cons
    movlw 0x0D      ;Loco
    subwf Key_temp,W
    bz    loco
    movlw 0x0E      ;enter
    subwf Key_temp,W
    bz    enter
    movlw 0x0F      ;Fr1
    subwf Key_temp,W
    bz    fr1a
    movlw 0x10      ;Fr2
    subwf Key_temp,W
    bz    fr2a
    movlw 0x11      ;Prog
    subwf Key_temp,W
    bz    proga     
keyback bsf   Keyflag,0
    nop
    goto  main

fr1a  goto  fr1
fr2a  goto  fr2
proga goto  prog
;   set direction

dir   call  dir_sub
    bra   keyback


;   emergency stop

emstop  call  em_sub
    bra   keyback

;   set consist

cons  btfsc Locstat,2   ;is it already set
    bra   cons1
    btfss Locstat,0   ;valid loco?
    bra   keyback
    call  conset
    bra   keyback
cons1 bcf   Locstat,2
    bsf   Locstat,5   ;consist clear
    call  conclear
    bra   keyback

; loco key  (does various things)

loco  clrf  Progmode
    clrf  Sermode 
        clrf    Setupmode
    clrf  Fnmode  
    btfsc Locstat,0     ;any loco set?
    bra   locset
    btfsc Locstat,1     ;release mode?
    bra   locset
    btfsc Locstat,2     ;consist
    bra   locset
    btfsc Locstat,5
    bra   locset
    btfsc Locstat,6
    bra   locset
    call  lcd_clr
    call  lcd_home
    movlw " "
    movwf Adr1        ;clear address string
    movwf Adr2
    movwf Adr3
    movwf Adr4
    call  locprmpt      ;prompt for loco again
    lfsr  FSR2,Num1     ;reset pointer
    
    clrf  Numcount
    bra   keyback

locset  clrf  Numcount      ;for abort
    btfsc Locstat,2
    bra   conout        ;out of consist
    btfsc Locstat,5
    bra   conout
    btfsc Locstat,6
    bra   conout
    btfss Locstat,1
    bra   clear
  
    bcf   Locstat,1
    bsf   Locstat,0
    bra   locdisp       ; Redisplay loco info

clear bsf   Locstat,1
    bcf   Locstat,0
    call  lcd_clr
    call  lcd_home
    call  loco_lcd
    call  lcd_cr
    movlw HIGH Relstr
    movwf TBLPTRH           
    movlw LOW Relstr
    call  lcd_str
    bra   keyback
conout  bsf   Locstat,0   ;reenable loco
    bcf   Locstat,2   ;out of consist mode
    bcf   Locstat,5   ;out of consist clear mode
    bcf   Locstat,6   ;out of prog mode
    clrf  Progmode
    clrf  Sermode
locdisp call  lcd_clr     ; clear lcd
    call  loco_lcd    ; displly speed info
    btfss Locstat,4   ; Waiting for zero after stop?
    bra   keyback
    movlw HIGH Stopstr
    movwf TBLPTRH           
    movlw LOW Stopstr   ; If so, reinstate stop message
    call  lcd_str
    bra   keyback

;   enter key (acts on whatever has been set up)
    
enter bcf   Sermode,5
    btfsc Progmode,5
    call  ss_set
    btfss Modstat,0   ;got CAN ID?
    call  setloop     ;get CAN_ID
    movlw B'10010101'
    movwf T3CON     ;set timer 3 now for A/D update rate
    btfss Locstat,0
    call  beep
    bcf   Modstat,3   ;clear reset flag
    btfsc Locstat,1   ;release mode?
    bra   rel_mode
    btfsc Locstat,2   ;consist set?
    bra   con_mode
    btfsc Locstat,5
    bra   con_clr
    btfsc Locstat,6
    bra   prog_mode
    btfsc Locstat,0   ;any loco selected?
    bra   keyback
    movf  Numcount,F
    bz    noadr     ;no address set
    movff Numcount,Numtemp  ;for display later
    call  adrconv     ;put input address into two HEX bytes
    call  get_handle
    bra   keyback     ;wait for handle from CS

;adcloop  call  adc_zero    ;wait till speed is zero
    
noadr bra   keyback

ssmode  call  ss_mode     ;do speed step sequence
    bra   keyback

fr1   btfsc Progmode,4    ;service mode?
    bra   frprog
    btfss Locstat,0   ;any loco?
    bra   ssmode      ;speed step set
    btfss Fnmode,0
    bra   setfr1
    bcf   Fnmode,0
    call  lcd_clr
    call  loco_lcd    ;clear Fn mode
    bra   keyback
setfr1  bsf   Fnmode,0
    bcf   Fnmode,1
    movlw HIGH Fr1lbl
    movwf TBLPTRH           
    movlw LOW Fr1lbl
    call  lcd_str
    bra   keyback
frprog  btfss Progmode,0
    bra   keyback     ;do nothing
    movf  Sermode,W
    incf  WREG
    andlw B'00000011'
    btfsc Sermode,2
    bsf   WREG,2
    movwf Sermode
    movlw LOW Ser_md    ;rewrite mode
    movwf EEADR
    movf  Sermode,W
    call  eewrite
    call  newdisp
    bra   keyback

rel_mode  bcf Modstat,4   ;stop keepalive
    movlw 0x21    ;release handle
    movwf Tx1d0
    movff Handle,Tx1d1
    movlw 2
    movwf Dlc
    call  sendTXa
    movlw LOW E_hndle   ;clear handle in EEPROM
    movwf EEADR
    movlw 0xFF      ;no handle is 0xFF
    call  eewrite
    bcf   Locstat,0
    bcf   Locstat,1
    bcf   T0CON,TMR0ON    ;stop keepalive timer interrupts
    bra   loco

con_mode call conconv
    sublw 0
    bz    do_con      ;OK value
    call  conset      ;do again
    bra   keyback
do_con  movlw 0x45
    movwf Tx1d0     ;command set consist
    movff Handle,Tx1d1
    movff Conadr,Tx1d2  ;consist address
    btfss Locstat,7   ;what is direction
    bsf   Tx1d2,7     ;set reverse in consist
    movlw 3
    movwf Dlc
    call  sendTXa     ;send command
    bcf   Locstat,2   ;clear consist mode
    bra   rel_mode    ;release current loco
con_clr movlw 0x45
    movwf Tx1d0     ;command clear consist
    movff Handle,Tx1d1
    movlw 0
    movwf Tx1d2     ;consist address is zero
    movlw 3
    movwf Dlc
    call  sendTXa     ;send command
    bcf   Locstat,5   ;clear consist clear mode
    bcf   Locstat,2
    bsf   Locstat,0
    call  lcd_clr
    call  loco_lcd
    bra   keyback
;   bra   rel_mode    ;release current loco

fr2   btfsc Progmode,4    ;service mode?
    bra   frprog2
    btfss Locstat,0   ;any loco?
    bra   keyback
    btfss Fnmode,1
    bra   setfr2
    bcf   Fnmode,1
    call  lcd_clr
    call  loco_lcd    ;clear Fn mode
    bra   keyback
setfr2  bsf   Fnmode,1
    bcf   Fnmode,0
    movlw HIGH Fr2lbl
    movwf TBLPTRH           
    movlw LOW Fr2lbl
    call  lcd_str
    bra   keyback

  
frprog2 btfss Progmode,0
    bra   keyback     ;do nothing
    btg   Sermode,2   ;read / write
    movlw LOW Ser_md
    movwf EEADR
    movf  Sermode,W
    call  eewrite     ;write back service mode
    call  newdisp     ;update display
    bra   keyback
    

prog  bcf   Sermode,5
    movlw B'01011001'   ;mask dir bit, release bit and consist set bit
    andwf Locstat,W   ;any loco selected?
    bz    setup_mode    ;no - so into handset setup mode
    bsf   Locstat,6
    call  prog_sub
no_prog   bra   keyback
    

number  btfsc Sermode,5     ;block numbers in service mode
    bra   keyback
    btfsc Locstat,0     ;loco selected so number is function
    bra   funct
    btfsc Locstat,2     ;consist?
    bra   funct
    btfsc Progmode,3      ;prog mode get CV val
    bra   cvval
    btfsc Progmode,0      ;prog mode get CV number
    bra   cvnum
  ; bra   service
adrnum  movlw 4
adrnum1 subwf Numcount,W
    bz    nonum
    movff Key_temp,POSTINC2 ;put number in buffer
    incf  Numcount,F
    movf  Key_temp,W
    addlw 0x30
    movwf Char      ;hold char
    movlw 5
    subwf FSR2L,F
    movff Char,INDF2
    addwf FSR2L
    bsf   LCD_PORT,LCD_RS ;to chars
    movf  Char,W
    call  lcd_wrt
nonum bra   keyback

cvnum movlw 7         ;is it address mode read
    subwf Sermode,W
    bz    nonum       ;do nothing

    movlw 4
cvnum1  subwf Numcount,W
    bz    nonum
    movff Key_temp,POSTINC2 ;put number in buffer
    incf  Numcount,F
    movf  Key_temp,W
    addlw 0x30
    movwf Char      ;hold char
    
    bsf   LCD_PORT,LCD_RS ;to chars
    movf  Char,W
    call  lcd_wrt
    bra   keyback

funct btfsc Locstat,1   ;release mode?
    bra   keyback
    btfsc Locstat,2
    bra   con_num
    call  funsend     ;sort out Fn and send
    bsf   Locstat,3   ;flag for clear Fn
    bra   keyback
con_num movlw 3
    subwf Numcount,W
    bz    nonum
    movff Key_temp,POSTINC2
    incf  Numcount,F
    movf  Key_temp,W
    bsf   LCD_PORT,LCD_RS ;to chars
    addlw 0x30
    call  lcd_wrt
    bra   nonum

cvval ;btfsc  Progmode,4
    ;bra    serv1
    movlw 3
cvval1  subwf Numcount,W
    bz    nonum
    movff Key_temp,POSTINC2
    incf  Numcount,F
    movff Numcount,Numcvv   ;for display
    movf  Key_temp,W
    bsf   LCD_PORT,LCD_RS ;to chars
    addlw 0x30
    call  lcd_wrt
    bra   nonum


; these are because branches were too long

serr1 goto  serr
rd_back1 goto   rd_back
reboot1 goto  reboot    


; Handset setup mode
;
; Two presses of Prog whilst no loco controlled to get into setup mode
;   For now - a test of all message strings

setup_mode
        btfsc   Setupmode,1     ; if already in test mode
        bra   nxtstr      ; straight on with next string
        btfsc   Setupmode,0     ; Prog already pressed once?
        bra     setup_start     ; yes - this is second press so now in setup mode
        bsf     Setupmode,0
        bra     keyback

setup_start
        bsf     Setupmode,1
    call  lcd_clr 
    movlw HIGH Testing
    movwf TBLPTRH           
    movlw LOW Testing
    call  lcd_str 
    call  lcd_cr


frststr movlw HIGH Pmode1   ; point at first string
        movwf TBLPTRH
    movlw LOW Pmode1
        movwf   TBLPTRL
    bra   disptst

nxtstr  tblrd*          ; get next char in table
skpnul  movf  TABLAT,w
    bnz   nxtdis  
    tblrd+*         ; skip over any trailing nulls
    bra   skpnul
    
nxtdis  movlw HIGH TeststEnd    
    cpfslt  TBLPTRH     ; at end of list?
    bra   chkls           ; check lsbytes of string address
disnxt  call    lcd_clr
        call    lcd_home

disptst movf    TBLPTRL,w
        call  lcd_str 
    bsf   Setupmode,0 ; flag in setup mode
    bra   keyback

chkls   movlw   LOW TeststEnd
        cpfslt  TBLPTRL
        bra     frststr         ; End of list, so go back to beginning
        bra     disnxt


;   here if any CAN frames received   

packet  movlw 0x07      ;is it a reset frame
    subwf Rx0d0,W
    bz    re_set      ;system reset
    movlw 0x4C
    subwf Rx0d0,W
    bz    serr1     ;service mode error 
    movlw 0x85      
    subwf Rx0d0,W
    bz    rd_back1    ;read back of CV in service mode

    movlw OPC_RQNPN   ;read a parameter by index
    subwf Rx0d0,W
    bz    rdpara

    movlw 0x5C      ;reboot?
    subwf Rx0d0,W
    bz    reboot1

    movlw OPC_RESTP   ; Emergency stop all request?
    subwf Rx0d0,W     
    bz    est_pkt
    movlw OPC_ESTOP   ; Track stopped? (response from command station)
    subwf Rx0d0,W     
    bz    est_pkt


    btfsc Modstat,1   ;request handle response?
    bra   hand_set    ;do other frames here
    btfsc Modstat,2   ;handle check?
    bra   hand_set
    bcf   Datmode,0
    goto  main


  

est_pkt call  ems_mod     ; Put handset into emergency stop
    call  ems_lcd     ; Display stop all 
    bcf   Datmode,0   ; clear packet received flag
    goto  main

rdpara  call  thisNN      ;read parameter by index (added in rev y)
    sublw 0
    bnz   notNN
    call  para1rd
    bcf   Datmode,0
    goto  main
  

reboot  call  thisNN        ;is it a CAB?
    sublw 0
    bnz   notNN       ;no
    movlw 0xFF
    movwf EEADR
    movlw 0xFF
    call  eewrite     ;set last EEPROM byte to 0xFF
    reset         ;software reset to bootloader

notNN bcf   Datmode,0
    goto  main

re_set  bcf   PORTA,2     ;turn off red LED if on.
    clrf  Modstat     ;for enumeration
    movlw LOW E_hndle   ;clear handle in EEPROM
    movwf EEADR
    movlw 0xFF
    call  eewrite
    setf  Handle
  
re_set3 goto  re_set1a      ;reinitialises handset
    
hand_set 

    movlw 0xE1
    subwf Rx0d0,W
    bz    set1
    movlw 0x63
    subwf Rx0d0,W
    bz    err         ;error
    
    bcf   Datmode,0
    goto  main
    
set1  btfss Modstat,2     ;awaiting handle confirmation?
    bra   set1a       ;no
    movf  Handle,W
    subwf Rx0d1,W       ;handle matches?
    bnz   set1b       ;back
    movff Rx0d2,Adr_hi    ;get old address
    movff Rx0d3,Adr_lo
    call  adr_chr       ;set old address for display
    movff Rx0d5,Fr1     ;reinstate functions
    movff Rx0d6,Fr2
    movff Rx0d7,Fr3
    btfsc Rx0d4,7
    bra   set_fwd
    bcf   Locstat,7     ;clear direction bit
    bcf   PORTA,1       ;set LED
    bsf   PORTA,2
    bra   set2
set_fwd bsf   Locstat,7
    bcf   PORTA,2
    bsf   PORTA,1   
set2  movff Rx0d4,Speed1
    bcf   Speed1,7      ;clear direction bit
;   call  ss_send       ;send speed mode to CS
    movlw LOW Ser_md + 1    ;recover SS mode
    movwf EEADR
    call  eeread
    movwf Smode
    bsf   Locstat,0     ;loco active
  
    call  beep        ;confirm 
    bsf   T0CON,TMR0ON    ;start keepalive timer interrupt
    bsf   Modstat,4   ; keepalive flag
    movlw B'10010101'
    movwf T3CON     ;set timer 3 now for A/D update rate
    call  spd_chr       ;speed to chars for display

; to be finished here
    call  lcd_clr     ;display address and speed
    call  loco_lcd
    bcf   Modstat,2   ;out of confirmation mode
    bcf   Modstat,1   ;has valid handle
    movlw 1
    subwf Speed1,W    ;is it em.stop speed?
    bz    set1c     ;yes
    bra   set1b     ;no
set1c call  em_sub
    bra   set1b   

    
set1a movff Rx0d1,Handle    ;put in handle
    movlw LOW E_hndle
    movwf EEADR
    movf  Rx0d1,W
    call  eewrite
    bcf   Modstat,1
    call  ss_send   
    call  adc_zero
    

set1b bsf   Modstat,4
    bsf   T0CON,TMR0ON        ;start keepalive
    bcf   Datmode,0
    goto  main    
    
err   btfss Modstat,2     ;is it waiting for handle confirmation?
    bra   err_0
    movlw 3
    subwf Rx0d3,W
    bnz   err_4       ;not relevant error
    movf  Handle,W      ;check handle is for this cab.
    subwf Rx0d1,W
    bnz   err_4
    goto  re_set1
err_0 movf  Adr_hi,W      
    subwf Rx0d1,W       ;is it for this handset?
    bnz   err_4       ;not this
    movf  Adr_lo,W
    subwf Rx0d2,W
    bnz   err_4       ;not this

    movlw 1         ;error routine  
    subwf Rx0d3,W
    bz    err_1
    movlw 2
    subwf Rx0d3,W
    bz    err_2
    bra   err_5
err_1 call  loc_adr       ;loco number on top line
    call  beep
    movlw HIGH Str_ful
    movwf TBLPTRH          
    movlw LOW Str_ful     ;"FULL"
    call  lcd_str
    bra   err_4
err_2 call  loc_adr
    movlw HIGH Str_tkn
    movwf TBLPTRH          
    movlw LOW Str_tkn     ;"TAKEN"
    call  lcd_str
    call  beep
err_4 bcf   Modstat,1
    bcf   Modstat,4     
    bcf   Locstat,0
    bcf   Datmode,0
    goto  main
err_5 call  beep
    goto  re_set1a      ;no loco so reset 

serr  movf  Handle,W      ;check handle is for this cab.
    subwf Rx0d1,W
    bnz   serr_4        
    btfss Sermode,4     ;is it expecting an error /ack
    bra   serr_4
    movf  Rx0d2,W
    bz    serr_4        ;no error 0
    call  err_msg
serr_4  bcf   Sermode,4
    bcf   Datmode,0
    goto  main

prog_mode btfsc Progmode,2    ;is it CV value entry now?
    bra   prog2
    btfsc Progmode,1      ;is it long address
    bra   longadr
    btfsc Progmode,3      ;is it send CV
    bra   sendCV
    btfsc Progmode,0
    bra   adr_rd
prg2  bcf   Progmode,0
    bsf   Progmode,2      ;set for CV value entry
    call  cvaconv       ;convert to HEX bytes and check
prog_er1 sublw  0
    bnz   prog_err
    nop
    goto  main
adr_rd  movlw 7
    subwf Sermode,W
    bnz   prg2        ;is it read address?
    
    call  read_adr
    bra   prog_er1

prog_err movlw  B'00010000'     ;clear all except service flag  
    andwf Progmode,F
    call  beep
    call  prog_sub
    goto  keyback
prog2 call  prog_3
    goto  keyback
sendCV  call  cvv_conv
    sublw 0
    bnz   prg_err1
    btfsc Progmode,4
    bra   ser_prog      ;service mode program
    call  cv_send       ;OTM prog
    clrf  Progmode
    bcf   Locstat,6     ;out of prog mode
    call  lcd_clr
    call  loco_lcd
    bsf   Locstat,0     ;re-enable loco
    goto  keyback
prg_err1 call beep
    bcf   Progmode,3
    bra   prog2

ser_prog call cv_wrt
    goto  keyback 

longadr call  lng_conv      ;convert long address to HEX (OTM prog)
    sublw 0
    bnz   l_err       ;error
    movlw 0x82
    movwf Tx1d0       ;set up for CV17
    movff Handle,Tx1d1
    clrf  Tx1d2       ;CV hi byte is 00
    movlw 0x11
    movwf Tx1d3       ;CV lo byte is 0x11
    movff L_adr_hi,Tx1d4
    bsf   Tx1d4,6
    bsf   Tx1d4,7
    movlw 5
    movwf Dlc 
    call  sendTXa
    call  ldely       ;wait till sent by CS
    movlw 0x12
    movwf Tx1d3       ;CV lo byte is 0x12
    movff L_adr_lo,Tx1d4

    call  sendTXa
    call  ldely       ;wait till sent by CS

    movlw 0x83
    movwf Tx1d0       ;program bit in CV29
    movlw 0x1D        ;CV 29
    movwf Tx1d3
    movlw 0xFD
    movwf Tx1d4
    call  sendTXa
    clrf  Progmode
    bcf   Locstat,6     ;out of prog mode
    call  lcd_clr
    call  loco_lcd
    bsf   Locstat,0     ;re-enable loco
    goto  keyback
l_err bcf   Progmode,2
    nop             ;needs changing here?
    goto  keyback

rd_back call  cv_ans        ;cv answer
    bcf   Datmode,0
    goto  keyback       ;?





;***************************************************************************
;   main setup routine
;*************************************************************************

setup clrwdt
    clrf  INTCON      ;no interrupts yet
    movlw B'00000001'   ;A/D enabled
    movwf ADCON0      ;
    movlw B'00001110'   ;A/D on PORTA,0, rest are digital
    movwf ADCON1
    movlw B'00000101'   ;set sampling rate
    movwf ADCON2

    setf  NN_temph    ;provisional NN for all CABs is FFFF
    setf  NN_templ
    setf  Handle
    
    ;port settings will be hardware dependent. RB2 and RB3 are for CAN.
    ;set S_PORT and S_BIT to correspond to port used for setup.
    ;rest are hardware options
    
    clrf  PORTA
    clrf  PORTB
    clrf  PORTC
    movlw B'00000001'   ;Port A0 input for A/D, A1 and A2 for direction LEDs
                
    movwf TRISA     ;
    movlw B'00111011'   ;RB0 RB1 keypad rows 1 and 2
                ;RB2 = CANTX, RB3 = CANRX, 
                ;RB4 RB5 are keypad rows 3 and 4
    movwf TRISB
  
    bsf   PORTB,2     ;CAN recessive
    movlw B'00000000'   ;Port C  column drive and LCD drive. RC2 is sounder output (PWM)
    movwf TRISC
    clrf  CCP1CON
    movlw 0x42      ;set up PWM for beep. Approx 3.7 KHz 
    movwf PR2       ;set period
  
    movlw 0x21
    movwf CCPR1L      ;set duty cycle = square wave
    bcf   PIR1,TMR2IF
    movlw B'00000010'
    movwf T2CON     ;prescale of 16, timer off
    movlw B'00001100'   ;PWM mode
    movwf CCP1CON
    

    
    movlw LOW Ser_md    ;
    movwf EEADR
    movlw 0
    call  eewrite     ;deafult service mode
    clrf  Sermode 
  
  
    
; next segment is essential.
    
    bsf   RCON,IPEN   ;enable interrupt priority levels
    clrf  BSR       ;set to bank 0
    clrf  EECON1      ;no accesses to program memory  
    clrf  Datmode
    clrf  Latcount
    
;   call  ldely

    clrf  ECANCON     ;CAN mode 0 for now. 
    clrf  COMSTAT     ;clear any errors
     
    bsf   CANCON,ABAT   ;abort any waiting frames 
    movlw B'10000000'   ;CAN to config mode
    movwf CANCON
con_wait  movf  CANSTAT,W   ;wait for config confirmation
    xorlw B'10000000'
    tstfsz  WREG
    bra   con_wait

    movlw B'00000011'   ;set CAN bit rate at 125000 for now
    movwf BRGCON1
    movlw B'10011110'   ;set phase 1 etc
    movwf BRGCON2
    movlw B'00000011'   ;set phase 2 etc
    movwf BRGCON3
    movlw B'00100000'
    movwf CIOCON      ;CAN to high when off
    movlw B'00100100'   ;B'00100100'
    movwf RXB0CON     ;enable double buffer of RX0
    movlb .15
    movlw B'00100100'   ;reject extended frames
    movwf RXB1CON
    clrf  RXF0SIDL
    clrf  RXF1SIDL
    movlb 0


    
mskload lfsr  0,RXM0SIDH    ;Clear masks, point to start
mskloop clrf  POSTINC0    
    movlw LOW RXM1EIDL+1    ;end of masks
    cpfseq  FSR0L
    bra   mskloop
    
    clrf  CANCON      ;out of CAN setup mode
  
  
  
    movlw B'00100011'
    movwf IPR3      ;high priority CAN RX and Tx error interrupts(for now)
    clrf  IPR1      ;all peripheral interrupts are low priority
    clrf  IPR2
    clrf  PIE2



;next segment required
    
    
    
    clrf  INTCON2     ;Weak pullups on PORTB
    clrf  INTCON3     ;
    

    movlw B'00100011'   ;B'00100011'  Rx0 and RX1 interrupt and Tx error
                
    movwf PIE3
  
    clrf  PIR1
    clrf  PIR2
    clrf  PIR3      ;clear all flags
    clrf  Modstat
    bcf   RXB0CON,RXFUL ;enable RX0 buffer
    movlb .15
    bcf   TXB1CON,TXREQ ;abort any waiting CAN frame
    bcf   TXB0CON,TXREQ
    bcf   TXB2CON,TXREQ
    movlb 0

;set up LCD

    bcf   LCD_PORT,LCD_RS ;control register
    movlw B'00110011'   ;reset and 4 bit mode
    call  lcd_wrt
    movlw B'00110010'   ;reset and 4 bit mode sequence
    call  lcd_wrt
    movlw B'00101000'   ;2 lines, 5x7 dots
    call  lcd_wrt
    movlw B'00000110'   ;Cursor left to right, don't shift display
    call  lcd_wrt
    movlw B'00001100'   ;Display on, cursor off, blink at cursor off
    call  lcd_wrt
    movlw B'00000001'   ;clear display, start at DD address 0
    call  lcd_wrt


; Download custom characters to LCD CG RAM

    movlw B'01000000'   ; Set CG RAM address 0
    movwf Temp1     ; Save Initial CG RAM address
    movlw HIGH Custchars  ; Set up table pointer for character data to load
    movwf TBLPTRH          
    movlw LOW Custchars
    movwf TBLPTRL

loadCG  bcf   LCD_PORT,LCD_RS ; LCD into command mode
    movf  Temp1,w     ; Get CG RAM address
    call  lcd_wrt     ; Set CG RAM address in LCD

    bsf   LCD_PORT,LCD_RS ; LCD into data mode
    tblrd*+         ; get next row of pixels
    movf  TABLAT,W
    call  lcd_wrt
    incf  Temp1,F     ; next address
    movlw LOW Custend
    cpfseq  TBLPTRL     ; All loaded?
    bra   loadCG
    
    bcf   LCD_PORT,LCD_RS ; LCD into command mode
    movlw B'10000000'   ; Back to Data display RAM mode, address 0
    call  lcd_wrt
    bsf   LCD_PORT,LCD_RS ; LCD ready to accept display characters

;clear variables

re_set1a  clrf  Tx1con    ;make sure Tx1con is clear
    movlw B'00000001'
    movwf IDcount     ;set at lowest value for starters
    clrf  Locstat
    clrf  Progmode
    clrf  Modstat     ;re enumerate on enter
    clrf  Sermode
    clrf  Setupmode
    lfsr  FSR2,Num1     ;reset pointer
    movlw " "
    movwf Adr1
    movwf Adr2
    movwf Adr3
    movwf Adr4
;   call  ldely     ;for now
    clrf  Smode     ;default is 128 SS
    movlw 0x07
    subwf Rx0d0,W     ;is it a reset command
    bz    re_set1b    ;always a hard reset

    bcf   PORTB,7     ;for hard reset test. Is the Prog button in?
    btfsc PORTB,5     ;clear if in
    bra   re_set4
re_set1b  movlw LOW E_hndle   ;clear handle
    movwf EEADR
    movlw 0xFF
    call  eewrite
    setf  Handle
    bcf   Datmode,0
    bra   re_set1     ;hard reset
    

;   test for walkaround
;   is handle already in the CS?

re_set4 movlw LOW E_hndle
    movwf EEADR
    call  eeread      ;is handle already set?
    movwf W_temp
    addlw 1       ;was 0xFF?
    bz    re_set1     ;CAB doesn't have a handle so hard reset

;   here if handle is set in EEPROM
    
    movff W_temp,Handle
    call  newid1      ;reinstate CANid to RAM etc. (current CANid in EEPROM)
    clrf  Modstat
    bsf   Modstat,0   ;has got CAN_ID
    movlw B'11100000'
    clrf  PIR3
    movwf INTCON      ;enable interrupts

    bsf   Modstat,2   ;set flag for handle confirm
    clrf  Locstat     ;no loco selected
    bsf   Locstat,7   ;default to forward   
    movlw 0x22      ;query engine (QLOC)
    movwf Tx1d0
    movff Handle,Tx1d1
    movlw 2
    movwf Dlc     
  
    call  sendTXa

    bra   re_set2     ;continue
    

re_set1 clrf  INTCON
    setf  Handle
    
  
  
  

    
    
    bsf   Locstat,7       ;set to forward
    clrf  Modstat
    call  lcd_clr
    bsf   LCD_PORT,LCD_RS
;   movlw LOW Selstr
    movlw HIGH Titlstr
    movwf TBLPTRH          
    movlw LOW Titlstr
    call  lcd_str
    call  lcd_cr
    bsf   LCD_PORT,LCD_RS
    movlw HIGH Verstr
    movwf TBLPTRH          
    movlw LOW Verstr
    call  lcd_str
        movlw   Major_Ver           ; Show major version number
        addlw   0x30                ; Will need to change this when we get to major version 10
        call    lcd_wrt
    movlw Minor_Ver     ; add minor version letter
    call  lcd_wrt

; This bit is for deveoper test versions only.
; It displays the build number in the lcd display 
; so we can confirm the new version has been loaded or bootloaded

#ifdef test_ver
    movlw build_no
    addlw 0x30
    call  lcd_wrt
#endif

;   movlw "="
;   call  lcd_wrt
;   movlw " "
;   call  lcd_wrt
    bsf Modstat,6   ; Flag for title display delay
    bsf   PORTA,1     ;fwd LED for now as test

re_set2 clrf  Fnmode        ;holds function range
    clrf  Fr1         ;function bits  0 to 4
    clrf  Fr2         ;function bits  5 to 8
    clrf  Fr3         ;function bits  9 to 12
    clrf  Fr4         ;function bits  13 to 20
    clrf  Fr5         ;function bits  21 to 28
    
    clrf  Numcount      ;for numeric input
    clrf  Conadr        ;consist address
    clrf  Speed
    clrf  Keyflag
    movlw B'10000111'   ;set Timer 0 for keepalive, enable now for title delay
    movwf T0CON
    clrf  PIR3
    bcf   INTCON,TMR0IF
    movlw B'10010101'
    movwf T3CON     ;set timer 3 now for A/D update rate (moved here so can detect knob move before a loco selected in case of recover from emergency stop all
    movlw B'11100000'   ;reenable interrupts
    movwf INTCON      ;enable interrupts
    bcf   Datmode,0
    goto  main

    ; Disply loco prompt after title delay

clear_title 
    call  locprmpt  ;prompt for loco
    bcf   Modstat,6   ; Clear flag that title is displayed

    return

locprmpt
    call  lcd_clr
    call  lcd_home
    bsf   LCD_PORT,LCD_RS   
    movlw HIGH Selstr
    movwf TBLPTRH          
    movlw LOW Selstr      ;
    call  lcd_str
    call  lcd_cr
    bsf   LCD_PORT,LCD_RS
    movlw "="
    call  lcd_wrt
    movlw " "
    call  lcd_wrt

    return


;   subrouine used in self enumeration of CANid

setloop movlw B'11100000'
    movwf INTCON      ;enable interrupts
    
    bsf   Datmode,1   ;setup mode
    call  enum      ;sends RTR frame

set3  clrwdt
    btfss PIR2,TMR3IF   ;setup timer out?
    bra   set3      ;fast loop till timer out 
    bcf   T3CON,TMR3ON  ;timer off
    bcf   PIR2,TMR3IF   ;clear flag
    call  new_enum
    movlw LOW CANid   ;put new ID in EEPROM
    movwf EEADR
    movf  IDcount,W
    call  eewrite
    call  newid1      ;put new ID in various buffers
  
    bcf   Datmode,1   ;out of setup
    bsf   Modstat,0   ;has got CAN_ID
  



    return    


    
;****************************************************************************
;   start of subroutines    
;********************************************************************************
;   main routine to send CAN frame

sendTXa clrf  Tx1con      ;prevents false send if TXREQ is set by mistake
    movf  Dlc,W       ;get data length
    movwf Tx1dlc
    movlw B'00001111'   ;clear old priority
    andwf Tx1sidh,F
    movlw B'10110000'
    iorwf Tx1sidh     ;low priority
    movlw .10
    movwf Latcount
    call  sendTX1     ;send frame
    return        


;   Send contents of Tx1 buffer via CAN TXB1

sendTX1 lfsr  FSR0,Tx1con
    lfsr  FSR1,TXB1CON
    clrf  COMSTAT
    movlb .15       ;check for buffer access
tx1test clrwdt
    btfsc TXB1CON,TXREQ
    bra   tx1test
    movlb 0
ldTX1 movf  POSTINC0,W
    movwf POSTINC1  ;load TXB1
    movlw Tx1d7+1
    cpfseq  FSR0L
    bra   ldTX1

    
    movlb .15       ;bank 15
    bcf   TXB1SIDL,EXIDE  ;test for a fault?
    movlw B'00001011'   ;send - high priority
    movwf TXB1CON
tx1done btfsc TXB1CON,TXREQ ;check if sent
    bra   tx1done

    
    movlb 0       ;bank 0
    return          ;successful send

    
;*********************************************************************



;   put new CAN_ID in relevant places

    

newid1  movlw LOW CANid     ;put in stored ID
    movwf EEADR
    bsf   EECON1,RD
    movf  EEDATA,W
    movwf CanID_tmp     
    call  shuffle
    movlw B'11110000'
    andwf Tx1sidh
    movf  IDtemph,W   ;set current ID into CAN buffer
    iorwf Tx1sidh     ;leave priority bits alone
    movf  IDtempl,W
    movwf Tx1sidl     ;only top three bits used
    
    
    movlb .15       ;put ID into TXB2 for enumeration response to RTR
    bcf   TXB2CON,TXREQ
    clrf  TXB2SIDH
    movf  IDtemph,W
    movwf TXB2SIDH
    movf  IDtempl,W
    movwf TXB2SIDL
    movlw 0xB0
    iorwf TXB2SIDH    ;set priority
    clrf  TXB2DLC     ;no data, no RTR
    movlb 0
    bsf   Modstat,0   ;flag got CAN_ID
    return
    

    return



    
;*****************************************************************************
;
;   shuffle for standard ID. Puts 7 bit ID into IDtemph and IDtempl for CAN frame
shuffle movff CanID_tmp,IDtempl   ;get 7 bit ID
    swapf IDtempl,F
    rlncf IDtempl,W
    andlw B'11100000'
    movwf IDtempl         ;has sidl
    movff CanID_tmp,IDtemph
    rrncf IDtemph,F
    rrncf IDtemph,F
    rrncf IDtemph,W
    andlw B'00001111'
    movwf IDtemph         ;has sidh
    return

;*********************************************************************************

;   reverse shuffle for incoming ID. sidh and sidl into one byte.

shuffin movff Rx0sidl,IDtempl
    swapf IDtempl,F
    rrncf IDtempl,W
    andlw B'00000111'
    movwf IDtempl
    movff Rx0sidh,IDtemph
    rlncf IDtemph,F
    rlncf IDtemph,F
    rlncf IDtemph,W
    andlw B'01111000'
    iorwf IDtempl,W     ;returns with ID in W
    return
;************************************************************************************
;   
eeread  bcf   EECON1,EEPGD  ;read a EEPROM byte, EEADR must be set before this sub.
    bcf   EECON1,CFGS
    bsf   EECON1,RD
    movf  EEDATA,W
    return

;**************************************************************************
eewrite movwf EEDATA      ;write to EEPROM, EEADR must be set before this sub.
    bcf   EECON1,EEPGD
    bcf   EECON1,CFGS
    bsf   EECON1,WREN
    movff INTCON,TempINTCON
    clrf  INTCON  ;disable interrupts
    movlw 0x55
    movwf EECON2
    movlw 0xAA
    movwf EECON2
    bsf   EECON1,WR
eetest  btfsc EECON1,WR
    bra   eetest
    bcf   PIR2,EEIF
    bcf   EECON1,WREN
    clrf  PIR3          ;prevent recursive interrupts
  
    movff TempINTCON,INTCON   ;reenable interrupts
    
    return  
    
;***************************************************************

scan  clrf  Key
    movlw B'11110001'
    movwf PORTC     ;all columns hi, LCD off
    bcf   PORTC,0     ;column 1 lo
    call  row
    bsf   PORTC,0     ;column 1 hi
    btfsc Key,7     ;no key
    return
    movlw 4
    addwf Key,F
    bcf   PORTC,4     ;column 2 lo
    call  row
    bsf   PORTC,4     ;column 2 hi
    btfsc Key,7     ;no key
    return
    movlw 4
    addwf Key,F
    bcf   PORTC,5     ;column 3 lo
    call  row
    bsf   PORTC,5     ;column 3 hi
    btfsc Key,7     ;no key
    return
    movlw 4
    addwf Key,F
    bcf   PORTC,6     ;column 4 lo
    call  row
    bsf   PORTC,6     ;column 4 hi
    btfsc Key,7     ;no key
    return
    movlw 4
    addwf Key,F
    bcf   PORTC,7     ;column 5 lo
    call  row
    bsf   PORTC,7     ;column 5 hi
    return

;********************************************************
;   read rows
;
row   btfsc PORTB,0
    bra   row1
    movlw 0
    addwf Key,F
    bra   gotkey
row1  btfsc PORTB,1
    bra   row2
    movlw 1
    addwf Key,F
    bra   gotkey
row2  btfsc PORTB,4 
    bra   row3
    movlw 2
    addwf Key,F
    bra   gotkey
row3  btfsc PORTB,5     
    return
    movlw 3
    addwf Key,F
gotkey  bsf   Key,7
    clrf  Debcount  ;debounce counter
    return
;*********************************************************
;   Write a char to the LCD
;   The register must be set by calling routine
;   0 is control reg, 1 is data reg
;   Char to be sent is in W
    
lcd_wrt movwf Temp    ;store char
    
    movlw B'00001111' ;clear data lines
    andwf LCD_PORT,F
    
    movlw B'11110000' ;upper nibble
    andwf Temp,W
    iorwf LCD_PORT,F  ;data to LCD

    bsf   LCD_PORT,LCD_EN   ;strobe
    nop
    nop
    bcf   LCD_PORT,LCD_EN

    movlw B'00001111' ;clear data lines
    andwf LCD_PORT,F

    swapf Temp,F    ;lower nibble
    movlw B'11110000' 
    andwf Temp,W
    iorwf LCD_PORT,F  ;data to LCD

    bsf   LCD_PORT,LCD_EN   ;strobe
    nop
    nop
    bcf   LCD_PORT,LCD_EN

    call  dely

    return
    
;**************************************************************************

;   LCD next line (CR,LF)
;
;
lcd_cr  bcf   LCD_PORT,LCD_RS   ;control register
    movlw 0xC0        ;CR, LF
    call  lcd_wrt
    bsf   LCD_PORT,LCD_RS   ;data register
    return

;***************************************************************************
;
;   LCD home
lcd_home  bcf   LCD_PORT,LCD_RS   ;control register
    movlw 0x02        ;home
    call  lcd_wrt
    bsf   LCD_PORT,LCD_RS   ;data register
    return

;*****************************************************************************
;
;   LCD clear
;
lcd_clr bcf   LCD_PORT,LCD_RS   ;control register
    movlw 0x01        ;clear
    call  lcd_wrt
    bsf   LCD_PORT,LCD_RS   ;data register
    return

;******************************************************************************
;
;   LCD write string  load W with start of string in EEPROM
;       end of string indicated by null character 
;      Changed from bit 7 set termination so bit 7 set chars can be embedded in strings
;      TBLPTRH must be set up with msbyte of string address
;      Pass LS Byte of string address in w


;
lcd_str bsf   LCD_PORT,LCD_RS   ;data register
    movwf TBLPTRL
;   movlw 0x30
;   movwf TBLPTRH             ; now set by caller, not assumed to be 0x30 to remove 255 byte table limit
    bsf   EECON1,EEPGD
    
str1  tblrd*+
    movf  TABLAT,W
    bz      lcd_str_ret
    call  lcd_wrt
    bra   str1
  
lcd_str_ret
    bcf   EECON1,EEPGD  
  
    return


;********************************************************************
;   A/D conversion for speed
;
a_to_d  bsf   ADCON0,GO   ;start conversion
a_done  btfsc ADCON0,GO
    bra   a_done
    bcf   Datmode,2   ;clear speed change
    movff ADRESH,Adtemp
    rrncf Adtemp,F
    bcf   Adtemp,7    ;128 steps
;   decf  Adtemp,W    ;is it speed 1 (ignore)
;   bz    nospeed
    movf  Adtemp,W
    subwf Speed,W
    bz    nospeed     ;has not changed
    movff Adtemp,Speed  ;new speed for change detection
    movf  Smode,F     ;is it 128 step?
    bz    s_128
    movlw 1
    subwf Smode,W
    bz    s_14      ;14 SS
    movlw .12       ;here for 28 SS
    addwf Speed,W 
    btfss WREG,7      ;overflow
    bra   s_28a
    movlw .127
s_28a movwf Speed1
    movlw .15
    cpfsgt  Speed1      ;don't send less than 16
    clrf  Speed1
    bra   a_d_2     ;finish

s_14  movlw .8
    addwf Speed,W 
    btfss WREG,7      ;overflow
    bra   s_14a
    movlw .127
s_14a movwf Speed1
    movlw .15
    cpfsgt  Speed1
    clrf  Speed1      ;don't send less than 16
    bra   a_d_2     ;finish
    
s_128 movf  Adtemp,W
    addlw 1
    btfsc WREG,7      ;not 128?
    decf  WREG      ;keep at 127
    movwf Speed1
    decf  Speed1,W
    bnz   a_d_2     ;not a 1
    clrf  Speed1      ;don't send a 1
a_d_2 
    
  
    bsf   Datmode,2   ;flag speed change
nospeed return
    
;**************************************************************************
;
;   convert the 4 address digits to two HEX bytes

adrconv clrf  Adr_hi
    clrf  Adr_lo
    decf  FSR2L
    btfsc Numcount,2      ;4 digits?
    bsf   Adr_hi,7      ;flag long address
    movff POSTDEC2,Adr_lo   ;ones
    decf  Numcount,F
    bz    last_num
    movlw 0x0A        ;tens  (x 0x0A)
    mulwf POSTDEC2
    movf  PRODL,W
    addwf Adr_lo,F
    decf  Numcount,F
    bz    last_num
    movlw 0x64        ;hundreds  (x 0x64)
    mulwf POSTDEC2
    movf  PRODL,W
    addwf Adr_lo,F
    movf  PRODH,W
    addwfc  Adr_hi,F
    decf  Numcount,F
    bz    last_num
    movlw 0xE8        ;thousands  (x 3E8)
    mulwf INDF2
    movf  PRODL,W
    addwf Adr_lo,F
    movf  PRODH,W
    addwfc  Adr_hi,F
    movlw 3
    mulwf INDF2
    movf  PRODL,W
    addwf Adr_hi,F
last_num movf Adr_hi,F    
    bnz   long        ;hi byte not zero so long address
    btfss Adr_lo,7      ;lo byte more than 127 so long address
    return
long  bsf   Adr_hi,7      ;set top two bits for long address
    bsf   Adr_hi,6  
    return

;**************************************************************************
;
;
;   convert the 4 address digits to two HEX bytes for long address program

lng_conv  movf  Numcount,F      ;any number?
    bz    no_lng          ;no
    clrf  L_adr_hi
    clrf  L_adr_lo
    decf  FSR2L
    movff POSTDEC2,L_adr_lo   ;ones
    decf  Numcount,F
    bz    last_lng
    movlw 0x0A          ;tens
    mulwf POSTDEC2
    movf  PRODL,W
    addwf L_adr_lo,F
    decf  Numcount,F
    bz    last_lng
    movlw 0x64          ;hundreds
    mulwf POSTDEC2
    movf  PRODL,W
    addwf L_adr_lo,F
    movf  PRODH,W
    addwfc  L_adr_hi,F
    decf  Numcount,F
    bz    last_lng
    movlw 0xE8          ;thousands  (x 3E8)
    mulwf INDF2
    movf  PRODL,W
    addwf L_adr_lo,F
    movf  PRODH,W
    addwfc  L_adr_hi,F
    movlw 3
    mulwf INDF2
    movf  PRODL,W
    addwf L_adr_hi,F
last_lng 
    retlw 0
no_lng  retlw 1
;*************************************************************************
;
;   convert the 4 CV number digits to two HEX values 

cvaconv clrf  CVval1          ;ready for CV value entry
    clrf  CVval2
    clrf  CVval3
    movf  Numcount,F
    bz    no_CVnum        ;no number entered
    movff Numcount,Numcv      ;for use in displays of CV number
    movff Numcount,Numtemp1
    clrf  CVnum_lo
    clrf  CVnum_hi
    decf  FSR2L
    
    movff POSTDEC2,CVnum_lo   ;ones
    decf  Numcount,F
    bz    last_CV
    movlw 0x0A        ;tens
    mulwf POSTDEC2
    movf  PRODL,W
    addwf CVnum_lo,F
    decf  Numcount,F
    bz    last_CV
    movlw 0x64        ;hundreds
    mulwf POSTDEC2
    movf  PRODL,W
    addwf CVnum_lo,F
    movf  PRODH,W
    addwfc  CVnum_hi,F
    decf  Numcount,F
    bz    last_CV
    movlw 0xE8        ;thousands  (x 3E8)
    mulwf INDF2
    movf  PRODL,W
    addwf CVnum_lo,F
    movf  PRODH,W
    addwfc  CVnum_hi,F
    movlw 3
    mulwf INDF2
    movf  PRODL,W
    addwf CVnum_hi,F
  

last_CV movf  CVnum_hi,F
    bnz   last_1

    movf  CVnum_lo,F
    bz    no_CVnum
    ;movlw  1         ;reduce entered number by 1 (CV 0 to 1023)
    ;subwf  CVnum_lo,F      ;mod for Andrew's CS
    ;movlw  0
    ;subwfb CVnum_hi,F
last_1  movlw 0x04        ;check not more than 0x3FF
    cpfslt  CVnum_hi
    bra   no_CVnum
    btfss Sermode,1     ;is it register mode
    retlw 0
    btfsc Sermode,0
    bra   add_tst       ;address mode
    movf  CVnum_hi,F
    bnz   no_CVnum      ;no hi byte allowed
    movlw 8         ;max reg number
    cpfsgt  CVnum_lo
    retlw 0
  
no_CVnum
    clrf  CVnum1
    clrf  CVnum2
    clrf  CVnum3
    clrf  CVnum4  
    retlw 1 
  
add_tst movf  CVnum_hi,F
    bnz   no_CVnum      ;no hi byte
    movlw .99         ;max reg number
    cpfsgt  CVnum_lo
    retlw 0
    retlw 1   

;********************************************************************

;
;   get handle for loco from CS
;   returns with 0 in W if allocated, not 0 if error
;
get_handle movlw  0x40    ;request loco handle
    movwf Tx1d0
    movff Adr_hi,Tx1d1
    movff Adr_lo,Tx1d2
    movlw 3
    movwf Dlc
    bsf   Modstat,1   ;set mode for answer
    call  sendTXa     ;send request
    return

;********************************************************************
;
;   display loco number and speed on top line

loco_lcd; call  lcd_clr       ;clear screen
      call  lcd_home
      call  spd_chr
      bsf   LCD_PORT,LCD_RS
      movf  Adr1,W        ;4 address chars
      call  lcd_wrt
      movf  Adr2,W
      call  lcd_wrt
      movf  Adr3,W
      call  lcd_wrt
      movf  Adr4,W
      call  lcd_wrt
      movlw " "         ;space
      call  lcd_wrt
      movf  Spd1,W        ;three speed chars
      call  lcd_wrt
      movf  Spd2,W
      call  lcd_wrt
      movf  Spd3,W
      call  lcd_wrt
      call  lcd_cr      ;next line

    return

;********************************************************************

;     error message after service mode action

err_msg ; call  beep
      movwf Err_tmp
      call  read_disp
      movlw 1
      subwf Err_tmp,W
      bz    no_ack
      movlw 2
      subwf Err_tmp,W
      bz    over_ld
      movlw 3
      subwf Err_tmp,W
      bz    ack_ok
      movlw 4
      subwf Err_tmp,W
      bz    busy
      movlw 5
      subwf Err_tmp,W
      bz    over_rng
      return

no_ack    movlw HIGH No_ack
      movwf TBLPTRH          
      movlw LOW No_ack
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return

over_ld   movlw HIGH Over_ld
      movwf TBLPTRH
          movlw LOW Over_ld
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return

ack_ok    call  lcd_clr
      movlw B'00000011'
      andwf Sermode,W
      btfss WREG,1
      bra   ack_ok1       ;page or direct
      btfsc WREG,0
      bra   ack_ok3       ;address mode
      movlw "R"
      call  lcd_wrt
      movlw "e"   
      call  lcd_wrt
      movlw "g"   
      call  lcd_wrt
      bra   ack_ok2
ack_ok3   movlw HIGH Address
      movwf TBLPTRH          
      movlw LOW Address
      call  lcd_str
      call  lcd_cr
      movlw "="
      call  lcd_wrt
      movlw " "
      call  lcd_wrt
      movff Numcv,Numtemp1
      call  cv_disp
      movlw " "
      call  lcd_wrt
      movlw " "
      call  lcd_wrt
      movlw HIGH Ack_OK
      movwf TBLPTRH          
      movlw LOW Ack_OK
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return

    
ack_ok1   movlw "C"
      call  lcd_wrt
      movlw "V"   
      call  lcd_wrt
ack_ok2   movlw " "
      call  lcd_wrt
      movff Numcv,Numtemp1
      call  cv_disp
      call  lcd_cr
      movlw "="
      call  lcd_wrt
      movlw " "
      call  lcd_wrt
      movff Numcvv,Numtemp1
      call  cvv_disp
      movlw " "
      call  lcd_wrt
      movlw HIGH Ack_OK
      movwf TBLPTRH          
      movlw LOW Ack_OK
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return
busy    movlw HIGH Busy
      movwf TBLPTRH          
      movlw LOW Busy
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return
over_rng  movlw HIGH Err
      movwf TBLPTRH          
      movlw LOW Err
      call  lcd_str
      call  beep
      bsf   Sermode,5
      return

;**********************************************************************
;
;     displays loco address on top line
;     used in error display

loc_adr   call  lcd_clr
      call  lcd_home
      bsf   LCD_PORT,LCD_RS
      movlw "L"
      call  lcd_wrt
      movlw "o"
      call  lcd_wrt
      movlw "c"
      call  lcd_wrt
      movlw "."
      call  lcd_wrt
      
      movf  Adr1,W        ;4 address chars
      call  lcd_wrt
      movf  Adr2,W
      call  lcd_wrt
      movf  Adr3,W
      call  lcd_wrt
      movf  Adr4,W
      call  lcd_wrt
      call  lcd_cr        ;next line
      return
 

;**********************************************************************

;     Update display when in service mode

newdisp   clrf  CVnum1
      clrf  CVnum2
      clrf  CVnum3
      clrf  CVnum4
      call  lcd_clr
      movlw LOW Ser_md
      movwf EEADR
      call  eeread
      mullw .10
      movlw HIGH Pmode1
      movwf TBLPTRH          
      movf  PRODL,W
      addlw LOW Pmode1    ;prompt for CV value
      call  lcd_str
      call  lcd_cr
      btfsc Sermode,1
      bra   regdisp

      movlw HIGH CV_equ
      movwf TBLPTRH          
      movlw LOW CV_equ
      call  lcd_str
      return
regdisp   btfsc Sermode,0
      bra   adrdisp

      movlw HIGH REG_equ
      movwf TBLPTRH          
      movlw LOW REG_equ
      call  lcd_str
      return

adrdisp   movlw HIGH ADR_equ
      movwf TBLPTRH          
      movlw LOW ADR_equ
      call  lcd_str
      return      

;***************************************************************************
;     convert speed byte to three ASCII chars
;     Uses Speed

spd_chr   movff Speed,Speed2
      movlw 1
      subwf Smode,W
      bz    spd_14
      movlw 2
      subwf Smode,W
      bz    spd_28
spd_conv  movlw "0"
      movwf Spd1
      movwf Spd2
      movwf Spd3
      
      movlw .100
      subwf Speed2,W
      bnc   tens
      movwf Speed2
      movlw "1"
      movwf Spd1
      
tens    movlw "0"
      subwf Spd1,W
      bnz   tens1
      movlw " "
      movwf Spd1
tens1   movlw .10
      subwf Speed2,W
      bnc   ones
      movwf Speed2
      incf  Spd2
      bra   tens1
ones    movlw "1"
      subwf Spd1,W
      bz    ones1
      movlw "0"
      subwf Spd2,W
      bnz   ones1
      movlw " "
      movwf Spd2
ones1   movf  Speed2,W
      iorwf Spd3
      return

spd_14    rrncf Speed2,F
      bcf   Speed2,7
      rrncf Speed2,F
      bcf   Speed2,7
      rrncf Speed2,F
      bcf   Speed2,7
      movlw .14
      cpfsgt  Speed2
      bra   spd_conv
      decf  Speed2,F
      bra   spd_conv

spd_28    rrncf Speed2,F
      bcf   Speed2,7
      rrncf Speed2,F
      bcf   Speed2,7
      movlw .28
      cpfsgt  Speed2
      bra   spd_conv
      movwf Speed2
      bra   spd_conv


    
;************************************************************************
;     convert two address bytes to four ASCII chars
;     Adress in Adr_hi and Adr_lo. Answer in  Adr1 to Adr4

adr_chr   movlw B'00111111'   ;mask long address bits
      andwf Adr_hi,W
      movwf Hi_temp     ;temp for address calculations
      movff Adr_lo,Lo_temp
      clrf  Numcount    ;number of chars
      movlw "0"       ;clear chars
      movwf Adr1
      movwf Adr2
      movwf Adr3
      movwf Adr4

thous   movlw 0xE8      ;lo byte of 1000
      subwf Lo_temp,F
      movlw 0x03      ;hi byte of 1000
      subwfb  Hi_temp,F
      bn    huns      ;overflow
      incf  Adr1      ;add to 1000s
      bra   thous     ;again

huns    movlw 0xE8      ;add back 1000
      addwf Lo_temp,F
      movlw 0x03
      addwfc  Hi_temp,F
huns_1    movlw 0x64      ;100
      subwf Lo_temp,F
      movlw 0
      subwfb  Hi_temp,F
      bn    tens_0      ;overflow
      incf  Adr2      ;add to 100s
      bra   huns_1

tens_0    movlw 0x64      ;add back 100
      addwf Lo_temp,F
;     movlw 0
;     addwfc  Hi_temp,F
tens_1    movlw 0x0A      ;10
      subwf Lo_temp,F
      bn    ones_0      ;overflow
      incf  Adr3      ;add to tens
      bra   tens_1

ones_0    movlw 0x0A      ;add back 10
      addwf Lo_temp,W
      addwf Adr4,F

      btfsc Adr_hi,7    ;short adress?
      return

      movff Adr2,Adr1   ;adjust address array for short address
      movff Adr3,Adr2
      movff Adr4,Adr3
      movlw " "
      movwf Adr4
      movlw "0"
      subwf Adr1,W
      bnz   adr4
      movff Adr2,Adr1
      movff Adr3,Adr2
      movlw " "
      movwf Adr3
      movlw "0"
      subwf Adr1,W
      bnz   adr4
      movff Adr2,Adr1
      movlw " "
      movwf Adr2
      

adr4    return          ;must be a digit in ones
      
      

      

    
        



;************************************************************************
;
;     send a speed change packet
;
spd_pkt bcf   Datmode,2   ;clear speed change flag
    btfss Locstat,0   ;any loco selected?

    return
    btfsc Locstat,1
    return
    movlw 0x47      ;speed /dir command
    movwf Tx1d0
    movff Handle,Tx1d1
  
    movff Speed1,Tx1d2
    btfsc Locstat,7
    bsf   Tx1d2,7     ;direction bit
    movlw 3
    movwf Dlc
    call  sendTXa     ;send command
;   btfsc Locstat,4
;   bra   spd1      ;if em.stop, leave display alone
;   call  lcd_clr
    decf  Speed1,W    ;is it em stop?
    bz    spd1      ;if yes, leave old speed up
    call  loco_lcd    ;update display
;   bcf   Locstat,4
    
spd1  return

;***************************************************************************
;
;   send keepalive packet

kp_pkt  movlw 0x47      ;speed /dir command
    movwf Tx1d0
    movff Handle,Tx1d1
  
    movff Speed1,Tx1d2
    btfsc Locstat,7
    bsf   Tx1d2,7     ;direction bit
    movlw 3
    movwf Dlc
    call  sendTXa     ;send command

    
    return

;***************************************************************************
;
;   send request emergency stop all (REST) packet

rest_pkt  movlw OPC_RESTP   ; CBUS opcode for emergency stop all
    movwf Tx1d0     ; Build packet in Tx buffer
    movlw 1
    movwf Dlc     ; Length of packet is 1 byte
    call  sendTXa     ;send command
    
    return

;******************************************************************************






;
;   function send routine
;
funsend movf  Fnmode,F      ;is it range 0?
    bnz   fr3         ;no
    movlw LOW Fnbits1
    addwf Key_temp,W
    movwf EEADR
    call  eeread
    movwf Funtemp
    btfss Funtemp,6
    bra   not_fr2
    movlw 2
    movwf Tx1d2
    movlw B'00001111'
    andwf Funtemp,W
    xorwf Fr2,F
    movff Fr2,Tx1d3
    bra   fnframe     ;send frame
not_fr2 btfss Funtemp,7
    bra   not_fr3
    movlw 3
    movwf Tx1d2
    movlw B'00001111'
    andwf Funtemp,W
    xorwf Fr3,F
    movff Fr3,Tx1d3
    bra   fnframe     ;send frame
not_fr3 movlw 1
    movwf Tx1d2
    movlw B'00011111'
    andwf Funtemp,W
    xorwf Fr1,F
    movff Fr1,Tx1d3
    bra   fnframe     ;send frame
fr3   btfsc Fnmode,1
    bra   fr5       ;F20 to F28
    movlw 3
    subwf Key_temp,W
    bnn   fr4
    movlw LOW Fnbits2   ;F10 to 12
    addwf Key_temp,W
    movwf EEADR
    call  eeread
    movwf Funtemp
    
    movlw 3
    movwf Tx1d2
    movlw B'00001111'
    andwf Funtemp,W
    xorwf Fr3,F
    movff Fr3,Tx1d3
    bra   fnframe     ;send frame
fr4   movlw LOW Fnbits3   ;F13 to F19
    addwf Key_temp,W
    movwf EEADR
    movlw 3
    subwf EEADR     ;start at 0 if 3 (F13 is first of Fr4)
    call  eeread
    xorwf Fr4,F
    movff Fr4,Tx1d3
    movlw 4
    movwf Tx1d2
    bra   fnframe

fr5   movlw 9         ;check for 29 - invalid
    subwf Key_temp,W
    bnz   fr5_ok
    return
fr5_ok    movlw LOW Fnbits4   ;F20 to F28
    addwf Key_temp,W
    movwf EEADR
    
    call  eeread
    xorwf Fr5,F
    movff Fr5,Tx1d3
    movlw 5
    movwf Tx1d2

fnframe movlw 0x60      ;function frame
    movwf Tx1d0
    movff Handle,Tx1d1
    movlw 4
    movwf Dlc
    call  sendTXa
    call  lcd_clr
    call  loco_lcd
    movf  Fnmode,F
    bz    fn_lo
    bra   fn_hi1
fn_lo movlw HIGH Fnumstr
    movwf TBLPTRH          
    movlw LOW Fnumstr
    call  lcd_str
    movf  Key_temp,W
    addlw 0x30
    call  lcd_wrt
    return
fn_hi1  btfsc Fnmode,1
    bra   fn_hi2
    movlw HIGH Fr1lbl
    movwf TBLPTRH          
    movlw LOW Fr1lbl
    call  lcd_str
    movlw "F"
    call  lcd_wrt
    movlw "1"
    call  lcd_wrt
    movf  Key_temp,W
    addlw 0x30
    call  lcd_wrt
    return

fn_hi2  movlw HIGH Fr2lbl
    movwf TBLPTRH          
    movlw LOW Fr2lbl
    call  lcd_str
    movlw "F"
    call  lcd_wrt
    movlw "2"
    call  lcd_wrt
    movf  Key_temp,W
    addlw 0x30
    call  lcd_wrt
    return

;****************************************************************************
;   set loco into consist
;

conset  bcf   Locstat,5     ;clear if in con clear
    bra   con1
con2  call  lcd_clr       ;set a consist
    call  lcd_home
    movlw HIGH Constr
    movwf TBLPTRH          
    movlw LOW Constr
    call  lcd_str       ;consist string
    call  lcd_cr
    movlw "="         ;prompt for consist address
    call  lcd_wrt
    movlw " "
    call  lcd_wrt
    bsf   Locstat,2     ;consist mode
    bcf   Locstat,0
    lfsr  FSR2,Con1
    clrf  Numcount
    return
con1  clrf  Con1        ;clear old consist (may not be needed)
    clrf  Con2
    clrf  Con3
    bra   con2
;******************************************************************************
;
;   clear a loco from consist. (just sets screen message and disables loco) 
;
conclear call lcd_clr       ;set a consist
    call  lcd_home
    movlw HIGH Constr
    movwf TBLPTRH          
    movlw LOW Constr
    call  lcd_str       ;consist string
    call  lcd_cr
    movlw HIGH Conclr
    movwf TBLPTRH          
    movlw LOW Conclr
    call  lcd_str
    bcf   Locstat,0
    return

;*******************************************************************************
;
;   convert consist address keys to single HEX number
;   returns with W = 0 if OK
;   returns with W = 1 if more than 127
;   FSR2 points one past last input number
;   Numcount has number of values  (1 to 3)

conconv decf  FSR2L
    movf  Numcount,F
    bz    toobig        ;if no number then flag error
    movff POSTDEC2,Conadr   ;ones
    decf  Numcount,F
    bz    last_con
    movlw 0x0A        ;tens
    mulwf POSTDEC2
    movf  PRODL,W
    addwf Conadr,F
    decf  Numcount,F
    bz    last_con
    movlw 0x64        ;hundreds
    mulwf POSTDEC2
    movf  PRODL,W
    addwf Conadr,F
    movf  PRODH,W
    addwfc  Conadr,F
    bc    toobig
    movlw 0x80
    cpfslt  Conadr
    bra   toobig
last_con  retlw 0
toobig    retlw 1

;*******************************************************************************
;   convert and check CV value digits to single HEX byte
;
cvv_conv  decf  FSR2L
    movf  Numcount,F
    bz    noCVval       ;if no number then flag error
    movff POSTDEC2,CVval    ;ones
    decf  Numcount,F
    bz    last_cvv
    movlw 0x0A        ;tens
    mulwf POSTDEC2
    movf  PRODL,W
    addwf CVval,F
    decf  Numcount,F
    bz    last_cvv
    movlw 0x64        ;hundreds
    mulwf POSTDEC2
    movf  PRODL,W
    addwf CVval,F
    movf  PRODH,W
    addwfc  CVval,F
    bc    noCVval
    
last_cvv  retlw 0
noCVval   retlw 1
;******************************************************************************
;   program subroutine
;
;   First gets CV number. Press 'enter'
;   Then prompts for CV value
;   Press enter
;   Sends OTM programming command to CS.
;   Now includes service mode program and read
;
prog_sub  clrf  Numcount
      movlw B'11101111'
      andwf Progmode,W    ;is it set at all 
      bnz   prog_1
      bcf   Locstat,0   ;disable loco
      clrf  CVnum1
      clrf  CVnum2
      clrf  CVnum3
      clrf  CVnum4
prog_4    btfsc Progmode,4    ;service mode?
      bra   prog_4a
      call  lcd_clr
      movlw HIGH Progstr1
      movwf TBLPTRH          
      movlw LOW Progstr1
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str_equ
      movwf TBLPTRH          
      movlw LOW Str_equ
      call  lcd_str
      lfsr  FSR2,CVnum1   ;get CV number
      bsf   Progmode,0
      return
prog_1    btfsc Progmode,4    ;service?
      bra   prog_4a
      btfss Progmode,0
      bra   prog_2
      bcf   Progmode,0
      bsf   Progmode,1
      call  lcd_clr
      movlw HIGH Progstr2
      movwf TBLPTRH          
      movlw LOW Progstr2
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str_equ
      movwf TBLPTRH          
      movlw LOW Str_equ
      call  lcd_str
      lfsr  FSR2,L_adr1
      return
prog_2    btfss Progmode,1
      bra   prog_3
      btfss Progmode,4
      bra   prog_5        ;service mode
      bcf   Progmode,1
;     bcf   Progmode,4
      bra   prog_sub      ;do again
prog_3    btfsc Progmode,4    ;service?
      bra   prog_3a
      call  lcd_clr
      movlw HIGH Progstr3
      movwf TBLPTRH          
      movlw LOW Progstr3  ;prompt for CV value
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str_equ
      movwf TBLPTRH          
      movlw LOW Str_equ
      call  lcd_str
      lfsr  FSR2,CVval1
      bcf   Progmode,2
      bsf   Progmode,3
      return

prog_3a   ;call newdisp
      btfsc Sermode,2     ;is it read
      bra   read_CV
      call  lcd_clr
      btfss Sermode,1
      bra   prog_3b
      btfss Sermode,0
      bra   prog_3c
      call  send_adr      
      return
prog_3b   movlw HIGH Prog_CV
      movwf TBLPTRH          
      movlw LOW Prog_CV
      call  lcd_str
prog_3d   call  lcd_cr
      call  cv_disp
      movlw "="
      call  lcd_wrt
      lfsr  FSR2,CVval1
      bcf   Progmode,2
      bsf   Progmode,3
      return
prog_3c   movlw HIGH Pmode3
      movwf TBLPTRH
      movlw LOW Pmode3
      call  lcd_str
      bra   prog_3d

prog_4a call  newdisp
;   movlw B'00000011'
;   andwf Sermode,W
;   sublw 3
;   bz    prog_4b     ;address mode
    lfsr  FSR2,CVnum1   ;get CV number
    bsf   Progmode,0
    bcf   Progmode,3
    return
prog_4b lfsr  FSR2,CVval1
    movlw 1
    movwf CVnum1
    movwf Numtemp1
    bcf   Progmode,3
    bsf   Progmode,1
    return
  
    
nxtnum  movf  POSTINC2,W
    addlw 0x30
    call  lcd_wrt
    decfsz  Numtemp1
    bra   nxtnum
    movlw "="
    call  lcd_wrt
    lfsr  FSR2,CVval1
    bcf   Progmode,2
    bsf   Progmode,3
    return

prog_5    bsf   Progmode,4    ;service mode
      bsf   Progmode,0    ;stay in CVnumber
      bcf   Progmode,1
      bsf   Sermode,2   ; start in service mode read

      movlw LOW Ser_md    ;write service mode deafult
      movwf EEADR
      movf  Sermode,W
      call  eewrite

      call  lcd_clr
      movlw HIGH Rmode1
      movwf TBLPTRH          
      movlw LOW Rmode1    ;prompt for CV value
      call  lcd_str
      call  lcd_cr
      movlw HIGH CV_equ
      movwf TBLPTRH          
      movlw LOW CV_equ
      call  lcd_str
      lfsr  FSR2,CVnum1   ;get CV number

;     bsf   Progmode,5
      return

read_CV   call  read_disp
      call  cv_read       ;read the CV
      movlw B'00010000'
      andwf Progmode,F
      return

read_disp call  lcd_clr     ;ser display for read
      btfss Sermode,1   ;test for register or adr mode
      bra   rd_disp1
      btfsc Sermode,0   ;address?
      bra   rd_disp2
      movlw "R"
      call  lcd_wrt
      movlw "e"
      call  lcd_wrt
      movlw "g"
      call  lcd_wrt
      movlw 0x20
      call  lcd_wrt
      bra   rd_disp3
rd_disp2  movlw "A"
      call  lcd_wrt
      movlw "d"
      call  lcd_wrt
      movlw "d"
      call  lcd_wrt
      movlw "r"
      call  lcd_wrt
      movlw "e"
      call  lcd_wrt
      movlw "s"
      call  lcd_wrt
      movlw "s"
      call  lcd_wrt
      bra   rd_disp4
      
rd_disp1  movlw "C"
      call  lcd_wrt
      movlw "V"
      call  lcd_wrt
      movlw 0x20
      call  lcd_wrt
    
rd_disp3  movff Numcv,Numtemp1
      call  cv_disp       ;display CV without leading zeroes
rd_disp4  call  lcd_cr
      movlw "="
      call  lcd_wrt
      movlw 0x20
      call  lcd_wrt
      return
      
;********************************************************************************

;     display CV without leading zeroes
;     needs Numtemp1 set with number of digits

cv_disp   movf  CVnum1,W
    
      addlw 0x30
      call  lcd_wrt
      dcfsnz  Numtemp1
      return
      movf  CVnum2,W
      addlw 0x30
      call  lcd_wrt
      dcfsnz  Numtemp1
      return
      movf  CVnum3,W
      addlw 0x30
      call  lcd_wrt
      dcfsnz  Numtemp1
      return
      movf  CVnum4,W
      addlw 0x30
      call  lcd_wrt
      return

;****************************************************************************

;   displays the CV value without leading zeroes
;   needs Numtemp1 set with number of digits

cvv_disp  movf  CVval1,W
    
      addlw 0x30
      call  lcd_wrt
      dcfsnz  Numtemp1
      return
      movf  CVval2,W
      addlw 0x30
      call  lcd_wrt
      dcfsnz  Numtemp1
      return
      movf  CVval3,W
      addlw 0x30
      call  lcd_wrt
      
      return

;*******************************************************************************
;
;   Here if a direction change
;
dir_sub   btfss Locstat,0   ;no loco
    bra   dir_back
;   movff Speed,Speed1
    btfss Locstat,7
    bra   fwd
    bcf   Locstat,7
    bcf   PORTA,1     ;change LEDs
    bsf   PORTA,2
    call  spd_pkt
    bra   dir_back
fwd   bsf   Locstat,7
    bcf   PORTA,2
    bsf   PORTA,1
    call  spd_pkt
dir_back    return

;*****************************************************************************
;   Emergency stop
;
; The main entry point responds to the red key press, if it is a second press
; then a request emergency stop all packet is sent to the command station.
;
; The ems_mod entry point is in reponse to seeing a request emergency stop all
; packet on CBUS, so it puts this handset into emergency stop mode. Although the 
; command station stops all locos, if we didn't do this then our next keep alive
; speed packet would set the loco moving again. By putting us into emergency stop
; mode, the user has to put the control back to zero first to restart the loco
; Yes, we do send the speed 1 (stop) packet again, but that protects against us having
; just sent a keep alive packet after the command station responded to the emergency stop

em_sub  btfsc Locstat,4 ; Already in emergency stop mode?
    bra   em_all    ; Emergency stop pressed again 
    btfsc Modstat,5 ; Stop button flag (catches case when stop pressed twice with speed 0)
    bra   em_all

ems_mod btfss Locstat,0 ; valid loco?
    bra   em_back     ; 
        
    movlw 1     
    movwf Speed1
    call  spd_pkt
    movlw HIGH Stopstr
    movwf TBLPTRH          
    movlw LOW Stopstr
    call  lcd_str
;   call  adc_zero    ;wait for speed to be zero
    bsf   Locstat,4   ;for clear 
em_back bsf   Modstat,5   ; stop button flag
    return

;****************************************************************************
;   Emergency stop all - when emergency stop pressed twice

em_all  call  rest_pkt    ; Send emergency stop all to command station
ems_lcd call  lcd_clr     ; Enter here just to display stop all message
    btfsc Locstat,0   ; If we have a valid loco
    bra   emsloco     ;   redisplay loco info
    call  lcd_cr      ; else just move to bottom line
    bra   emsdisp
emsloco call  loco_lcd  
emsdisp movlw HIGH EmStopstr
    movwf TBLPTRH          
    movlw LOW EmStopstr ; Display STOP ALL message
        call  lcd_str
    return

;****************************************************************************
;   loco not enabled till speed is zero. (safety feature)
;
adc_zero  clrwdt  
    call  a_to_d
    movlw 2   ;is speed 0 or 1
    cpfslt  Adtemp
    bra adc_zero
    bsf Locstat,0
    movff Adtemp,Speed1
    call  lcd_clr
    call  loco_lcd
    return

;*******************************************************************************
;   send a beep
;
beep  movlw B'10110000'
    movwf T1CON     ;set timer 1 for beep duration
    bcf   PIR1,TMR1IF
    clrf  TMR1H     ;about 0.13 secs
    clrf  TMR1L
    bsf   T1CON,TMR1ON  ;start timers
    bsf   T2CON,TMR2ON

    return


;****************************************************************************
;
;   sends message to program CV OTM
;
cv_send movlw 0x82      ;OPS mode write
    movwf Tx1d0
    movff Handle,Tx1d1
    movff CVnum_hi,Tx1d2
    movff CVnum_lo,Tx1d3
    movff CVval,Tx1d4
    movlw 5
    movwf Dlc
    call  sendTXa     ;send message
    return

;******************************************************************************
;
;   write CV in service mode

cv_wrt  movlw 0xA2
    movwf Tx1d0     ;write in service mode
    movff Handle,Tx1d1
    movff CVnum_hi,Tx1d2
    movff CVnum_lo,Tx1d3
    clrf  Tx1d4     ;clear mode byte
    movlw B'11111010'
    andwf Sermode,W
    bz    wrt_dir
    movlw B'00000011'
    andwf Sermode,W
    addlw 1
    movwf Tx1d4
wrt_dir movff CVval,Tx1d5   ;get value
    movlw 6
    movwf Dlc
    call  sendTXa
    movlw B'00010000'
    movwf Progmode    ;for reply
    bsf   Sermode,4   ;for error / ack
    return

;   read a CV in service mode

cv_read movlw 0x84    ;read CV
    movwf Tx1d0
    movff Handle,Tx1d1
    
    movff CVnum_hi,Tx1d2
    movff CVnum_lo,Tx1d3
    bcf   Sermode,2
    movf  Sermode,W
    addlw 1     ;direct read is always bit read
    
    movwf Tx1d4
  
    movlw 5
    movwf Dlc
    call  sendTXa
    movlw B'00010000'
    movwf Progmode    ;for reply
    bsf   Sermode,2   ;keep in read
    bsf   Sermode,4   ;for error / ack
    return  

;***************************************************************************

;   answer to valid service mode read 

cv_ans  ;btfss  Locstat,0 ;valid CAB?
    ;return
    movf  Handle,W
    subwf Rx0d1   ;is it this CAB?
    bz    cv_ans1 
    return
cv_ans1 btfss Progmode,4  ;is it service mode?
    return

cv_chr    movff Rx0d4,CVchr2
      movlw "0"
      movwf CV1
      movwf CV2
      movwf CV3
      
CV_huns   movlw .100
      subwf CVchr2,W
      bnc   CV_tens
      movwf CVchr2
      incf  CV1
      bra   CV_huns
      
CV_tens   movlw .10
      subwf CVchr2,W
      bnc   CV_ones
      movwf CVchr2
      incf  CV2
      bra   CV_tens
CV_ones   movf  CVchr2,W
      iorwf CV3,F
      bsf   LCD_PORT,LCD_RS
      movf  CV1,W
      call  lcd_wrt
      movf  CV2,W
      call  lcd_wrt
      movf  CV3,W
      call  lcd_wrt
      call  beep
      bcf   Sermode,4
      bsf   Sermode,5

      

      return

;*******************************************************************************
enum  clrf  Tx1con      ;CAN ID enumeration. Send RTR frame, start timer

    clrf  Enum0
    clrf  Enum1
    clrf  Enum2
    clrf  Enum3
    clrf  Enum4
    clrf  Enum5
    clrf  Enum6
    clrf  Enum7
    clrf  Enum8
    clrf  Enum9
    clrf  Enum10
    clrf  Enum11
    clrf  Enum12
    clrf  Enum13
    
;   call  dely      ;wait a bit (didn't work without this!)
    
    movlw B'10111111'   ;fixed node, default ID  
    movwf Tx1sidh
    movlw B'11100000'
    movwf Tx1sidl
    movlw B'01000000'   ;RTR frame
    movwf Dlc
    
    movlw 0x3C      ;set T3 to 100 mSec (may need more?)
    movwf TMR3H
    movlw 0xAF
    movwf TMR3L
    movlw B'10110001'
    movwf T3CON     ;enable timer 3
    bsf   Datmode,1   ;used to flag setup state
    movlw .10
    movwf Latcount
    
    call  sendTXa     ;send RTR frame
    clrf  Tx1dlc      ;prevent more RTR frames
    return
    
;************************************************************
;
;   send speed packet for keepalive
;
keep  bcf   INTCON,TMR0IF ;clear timer flag
    call  spd_pkt
    return

;**************************************************************

;   send address only program frame

send_adr  movlw 0xA2
      movwf Tx1d0
      movff Handle,Tx1d1
      clrf  Tx1d2     ;CV hi
      movlw 1
      movwf Tx1d3     ;Reg 1
      movlw 3       ;address mode (same as register mode)
      movwf Tx1d4
      movff CVnum_lo,Tx1d5  ;address value
      movlw 6
      movwf Dlc
      call  sendTXa
      clrf  Progmode
      bsf   Progmode,4    ;stay in service mode
      bsf   Sermode,4   ;wait for acknowledge
      return

;***************************************************************

;     read in address only mode

read_adr  movlw 0x84
      movwf Tx1d0
      movff Handle,Tx1d1
      clrf  Tx1d2     ;CV hi
      movlw 1
      movwf Tx1d3     ;Reg 1
      movlw 3       ;address mode (same as register mode)
      movwf Tx1d4
      movlw 5
      movwf Dlc
      call  sendTXa
      clrf  Progmode
      bsf   Progmode,4    ;stay in service mode
      bsf   Sermode,4   ;wait for acknowledge
      return  

;*************************************************************

;   speed step mode sequence

ss_mode   btfsc Progmode,5
      bra   sm_inc
      bsf   Progmode,5
ss_mode1  movlw 0
      subwf Smode,W
      bz    sm128
      movlw 1
      subwf Smode,W
      bz    sm14
      movlw 2
      subwf Smode,W
      bz    sm28
      return        ;invalid value

sm128   call  lcd_clr
      movlw HIGH Selstep
      movwf TBLPTRH          
      movlw LOW Selstep
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str128
      movwf TBLPTRH          
      movlw LOW Str128
      call  lcd_str
      
      return

sm14    call  lcd_clr
      movlw HIGH Selstep
      movwf TBLPTRH          
      movlw LOW Selstep
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str14
      movwf TBLPTRH          
      movlw LOW Str14
      call  lcd_str
    
      return

sm28    call  lcd_clr
      movlw HIGH Selstep
      movwf TBLPTRH          
      movlw LOW Selstep
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str28
      movwf TBLPTRH          
      movlw LOW Str28
      call  lcd_str
      
      return

sm_inc    incf  Smode
      movlw 3
      subwf Smode,W     ;cycle through
      btfss STATUS,Z
      bra   ss_mode1
      clrf  Smode
      bra   ss_mode1

;*****************************************************************

;     set new SS on enter

ss_set    movlw LOW Ser_md +1
      movwf EEADR
      movf  Smode,W
      call  eewrite       ;save curent ss mode
      bcf   Progmode,5
      call  locprmpt      ; prompt for loco

      return

;***************************************************************

;     send speed step mode to CS for current handle

ss_send   movlw 0x44    ;STMOD
      movwf Tx1d0
      movff Handle,Tx1d1
      movff Smode,Tx1d2
      btfsc Smode,1     ;only 28 step, non interleaved
      bsf   Tx1d2,0
      movlw 3
      movwf Dlc
      call  sendTXa
      return

;**************************************************************
;   send node parameter bytes (7 maximum)
;   not implemented yet

parasend  
    movlw 0xEF
    movwf Tx1d0
    movlw LOW node_ID
    movwf TBLPTRL
    movlw 8
    movwf TBLPTRH
    lfsr  FSR0,Tx1d1
    movlw 7
    movwf Count
    bsf   EECON1,EEPGD
    
para1 tblrd*+
    movff TABLAT,POSTINC0
    decfsz  Count
    bra   para1
    bcf   EECON1,EEPGD  
    movlw 8
    movwf Dlc
    call  sendTXa
    return

;**************************************************************************

;   check if command is for this node

thisNN  movf  NN_temph,W
    subwf Rx0d1,W
    bnz   not_NN
    movf  NN_templ,W
    subwf Rx0d2,W
    bnz   not_NN
    retlw   0     ;returns 0 if match
not_NN  retlw 1

;**********************************************************************

;   new enumeration scheme
;   here with enum array set
;
new_enum  movff FSR1L,Fsr_tmp1Le  ;save FSR1 just in case
      movff FSR1H,Fsr_tmp1He 
      clrf  IDcount
      incf  IDcount,F     ;ID starts at 1
      clrf  Roll
      bsf   Roll,0
      lfsr  FSR1,Enum0      ;set FSR to start
here1   incf  INDF1,W       ;find a space
      bnz   here
      movlw 8
      addwf IDcount,F
      incf  FSR1L
      bra   here1
here    movf  Roll,W
      andwf INDF1,W
      bz    here2
      rlcf  Roll,F
      incf  IDcount,F
      bra   here
here2   movlw .99         ;limit to ID
      cpfslt  IDcount
      ;movwf  IDcount
      call  segful        ;CAN segment full
      movff Fsr_tmp1Le,FSR1L  ;
      movff Fsr_tmp1He,FSR1H 
      return
    
;*******************************************************

;     segment full so don't allocate an ID (not tested)

segful    movlw 0xFF      ;default ID unallocated
      movwf IDcount
      call  lcd_clr
      movlw HIGH Segful
      movwf TBLPTRH          
      movlw LOW Segful
      movwf TBLPTRL
      call  lcd_str
      call  lcd_cr
      movlw HIGH Str_ful
      movwf TBLPTRH          
      movlw   LOW Str_ful
      movwf TBLPTRL
      call  lcd_str
      clrf  Modstat     ;no ID
      return

;**********************************************************

;   send individual parameter

para1rd movlw OPC_PARAN
    movwf Tx1d0
    movlw LOW node_ID
    movwf TBLPTRL
    movlw 8
    movwf TBLPTRH   ;relocated code
    decf  Rx0d3,W
    addwf TBLPTRL
    bsf   EECON1,EEPGD
    tblrd*
    movff TABLAT,Tx1d4
    bcf   EECON1,EEPGD
    movff Rx0d3,Tx1d3
    movlw 5
    movwf Dlc
    movff NN_temph,Tx1d1
    movff NN_templ,Tx1d2
    call  sendTXa
    return  


;*********************************************************
;   a delay routine
      
dely  movlw .10
    movwf Count1
dely2 clrf  Count
dely1 clrwdt
    decfsz  Count,F
    goto  dely1
    decfsz  Count1
    bra   dely2
    return    
    
;****************************************************************

;   longer delay

ldely movlw .100
    movwf Count2
ldely1  call  dely
    decfsz  Count2
    bra   ldely1
    
    return

;************************************************************************

; LCD Text strings were declared here, now moved to include file

;************************************************************************   
  ORG 0xF00000      ;EEPROM data. Defaults
  
CANid de  B'01111111',0 ;CAN id default 
NodeID  de  0xFF,0xFF   ;Node ID. CAB default is 0xFFFF
E_hndle de  0xFF,0      ;saved handle. default is 0xFF
Ser_md  de  0,0       ;program / read mode and service mode

;key number conversion

Keytbl  de  0x0A,1    ;DIR, 1
    de  2,3     ;2,3
    de  0x0B,4    ;EM.STOP,4
    de  5,6     ;5,6
    de  0x0C,7    ;CONS,7
    de  8,9     ;8,9
    de  0xFF,0x0D ;null,LOCO
    de  0,0x0E    ;0,ENTER
    de  0xFF,0x0F ;null,Fr1
    de  0x10,0x11 ;Fr2,PROG





; Function bits lookup

Fnbits1 de  B'00010000',B'00000001'
    de  B'00000010',B'00000100'
    de  B'00001000',B'01000001'
    de  B'01000010',B'01000100'
    de  B'01001000',B'10000001'

Fnbits2 de  B'10000010',B'10000100'
    de  B'10001000',0xFF

Fnbits3 de  B'00000001',B'00000010'
    de  B'00000100',B'00001000'
    de  B'00010000',B'00100000'
    de  B'01000000',B'10000000'

Fnbits4 de  B'00000001',B'00000010'
    de  B'00000100',B'00001000'
    de  B'00010000',B'00100000'
    de  B'01000000',B'10000000'


  ORG 0xF000FE

    de  0x00,0x00       ;for boot
  
    end
