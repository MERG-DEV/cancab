;   	TITLE		"Source for DCC CAB for CBUS"
; 		; filename cancab4cBeta2.asm	11/01/20
; 
;      All source code is copyright (C) the author(s) concerned
;       	(c) Mike Bolton 2009-2019
;			With some modifications (c) Pete Brownlow and (c) Roger Healey
;			as detailed in the revision history below
;
;   This program is free software: you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 3 of the License, as set out
;   at <http:;www.gnu.org/licenses/>.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;   See the GNU General Public License for more details.
;
;   As set out in the GNU General Public License, you must retain and acknowledge
;   the statements above relating to copyright and licensing. You must also
;   state clearly any modifications made.  Please therefore retain this header
;   and add documentation of any changes you make. If you distribute a changed
;   version, you must make those changes publicly available.
;
;   The GNU license requires that if you distribute this software, changed or
;   unchanged, or software which includes code from this software, including
;   the supply of hardware that incorporates this software, you MUST either
;   include the source code or a link to a location where you make the source
;   publicly available. The best way to make your changes publicly available is
;   via the MERG online resources.  See <www.merg.co.uk>
;
;   Note that this software uses a Boot Loader that is derived from that supplied
;   by Microchip. That part of the software is distributed under the Microchip
;   license which requires that it is only used on Microchip processors.
;   See page 15 of <http:;ww1.microchip.com/downloads/en/AppNotes/00247a.pdf>
;   for details of the Microchip licensing.  The bootloader is distributed with
;   this software as a "system library" as defined in section 1 of the GNU Public
;   license and is not licensed under GNU.
;   You must conform to Microchip license terms in respect of the bootloader.
;


; Uses 16 MHz resonator and PLL for 64 MHz clock
; CAB with OTM and service mode programming, one speed knob or encoder and self enum for CAN_ID

; Emergency Stop and Emergency Stop all facility
; Includes Consist setting and clearing.
; Ability to set long address into loco in one instruction.
; Walkaround facility
; Firmware updatable over CBUS (using FCU)
; Has no node number facility yet. 

; Drives an 8 char by 2 line display (Everbouquet MC0802A used in prototype but protocol is standard for most displays)
; Use command station firmware cancmd_n or later for full functionality of emergency stop all
; Use command station firmware cancmd3b or later for correct service mode programming of all decoders

; Series 4 (CAB2) has backlit display and option for encoder or pot for speed.
; Construction is now all through hole.
; Encoder or pot selected with J3 (PORTA,ENC). If hi = pot, if lo = enc.


; The setup timer is TMR3. 
; CAN bit rate of 125 Kbits/sec
; Standard frame only 


; this code is for 18F25K80
; 

; use with PCB CAB2 

; 

; This is re-write of CAB2tBeta1 for the CAB2 wih through hole assembly and optional encoder
; Beta 2.  23/08/18  Added rate dependent increments for the encoder. (MB)
; Beta 3.  30/08/18  As Beta 2 but uses ECAN (MB). Self_en now as other nodes.
;					 With ECAN, it uses the ECAN buffer (8 frames deep)
;					 Reads RXB0 directly. With this buffer, any overflow is lost.
;					 Could add busy mechanism to prevent this is needed.
; Beta 4.  07/02/19  Added code for TO toggle test. (MB)
; Beta 5.  26/02/19  Fix for return from AC mode (MB)
; v4b Beta 1	09/03/19 As 4aBeta5 but with the pot option selected by RA5 (MB)
; v4c Beta 1	21/09/19 As 4b Beta 1 but is revised dual code for encoder or pot.
; v4c Beta 2	11/01/20 As 4c Beta 1 but with encoder mods by SW. 



; Assembly options
	LIST	P=18F25K80,r=hex,N=75,C=120,T=ON

	include		"p18f25k80.inc"
	
	;definitions  Change these to suit hardware.

  include "cbuslib/cbusdefs.inc"
	include "cabmessages.inc"	; Version of messages file only changes if messages are added or message lengths changed


; Define the node parameters to be stored at nodeprm

MAN_NO      equ	MANU_MERG	;manufacturer number
MAJOR_VER   equ 4
MINOR_VER   equ	"c"
BETA_VER    equ 2         	 ; Beta build number: Set to zero for a release build
MODULE_ID   equ MTYP_CANCAB ; id to identify this type of module
EVT_NUM     equ 0           ; Number of events
EVperEVT    equ 0           ; Event variables per event
NV_NUM	    equ	0           ; Number of node variables	
NODEFLGS	equ B'00001010'  ; Node flags  Consumer=No, Producer=Yes, FliM=No, Boot=YES
CPU_TYPE	equ	P18F25K80





;set config registers. 



	CONFIG	FCMEN = OFF, FOSC = HS2, IESO = OFF, PLLCFG = ON
	CONFIG	PWRTEN = ON, BOREN = SBORDIS, BORV=0, SOSCSEL = DIG
	CONFIG	WDTEN=OFF
	CONFIG	MCLRE = ON, CANMX = PORTB
	CONFIG	BBSIZ = BB1K 
	
	CONFIG	XINST = OFF,STVREN = ON,CP0 = OFF
	CONFIG	CP1 = OFF, CPB = OFF, CPD = OFF,WRT0 = OFF,WRT1 = OFF, WRTB = OFF
	CONFIG 	WRTC = OFF,WRTD = OFF, EBTR0 = OFF, EBTR1 = OFF, EBTRB = OFF
	


;	processor uses  16 MHz. Resonator with HSPLL to give a clock of 64MHz





;********************************************************************************

;		definitions used by CAB

LCD_PORT equ	LATC
LCD_EN	 equ	1
LCD_RS	 equ	3
MAX_FUN  equ    27

;S_PORT 	equ	PORTA	;setup switch  Change as needed
;S_BIT	equ	2


LED_PORT equ	LATB  ;change as needed
KEY_PORT equ	LATC



LED1	equ		6	;RB6 is the red LED on the PCB
LED2	equ		7	;RB7 is the green LED on the PCB

ENC_PORT equ 	PORTA		;encoder port. PORTA, PA1 and PA2
ENC_SW		equ	3	;swtch on encoder. PORTA, PA3
ENC		equ 5		;enc / pot select bit
ENC_RATSENS	equ 0x3F ;SW Rate sensitivity, 7F is original, reducing will make less sensitive
					 ;SW don't reduce ENC_RATESENS<1 and less than 10h will do single steps


; definitions used by bootloader

#define	MODE_SELF_VERIFY	;Enable self verification of written data (undefine if not wanted)

#define	HIGH_INT_VECT	0x0808	;HP interrupt vector redirect. Change if target is different
#define	LOW_INT_VECT	0x0818	;LP interrupt vector redirect. Change if target is different.
#define	RESET_VECT	0x0800	;start of target
#define	CAN_CD_BIT	RXB0EIDL,0	;Received control / data select bit
#define	CAN_PG_BIT	RXB0EIDL,1	;Received PUT / GET bit
#define	CANTX_CD_BIT	TXB0EIDL,0	;Transmit control/data select bit
#define	CAN_TXB0SIDH	B'10000000'	;Transmitted ID for target node
#define	CAN_TXB0SIDL	B'00001000'
#define	CAN_TXB0EIDH	B'00000000'	;
#define	CAN_TXB0EIDL	B'00000100'
#define	CAN_RXF0SIDH	B'00000000'	;Receive filter for target node
#define	CAN_RXF0SIDL	B'00001000'
#define	CAN_RXF0EIDH	B'00000000'
#define	CAN_RXF0EIDL	B'00000111'
#define	CAN_RXM0SIDH	B'11111111'	;Receive masks for target node
#define	CAN_RXM0SIDL	B'11101011'
#define	CAN_RXM0EIDH	B'11111111'
#define	CAN_RXM0EIDL	B'11111000'
#define	CAN_BRGCON1		B'00001111'	;CAN bit rate controls. As for other CBUS modules
#define	CAN_BRGCON2		B'10011110'
#define	CAN_BRGCON3		B'00000011'
#define	CAN_CIOCON		B'00100000'	;CAN I/O control	
;	************************************************************ ** * * * * * * * * * * * * * * *
;	************************************************************ ** * * * * * * * * * * * * * * *
#ifndef	EEADRH		
#define	EEADRH	EEADR+ 1	
#endif			
#define	TRUE	1	
#define	FALSE	0	
#define	WREG1	PRODH	; Alternate working register
#define	WREG2	PRODL	
#define	MODE_WRT_UNLCK	_bootCtlBits, 0	; Unlock write and erase
#define	MODE_ERASE_ONLY	_bootCtlBits, 1	; Erase without write
#define	MODE_AUTO_ERASE	_bootCtlBits, 2	; Enable auto erase before write
#define	MODE_AUTO_INC	_bootCtlBits, 3	; Enable auto inc the address
#define	MODE_ACK		_bootCtlBits, 4	; Acknowledge mode
#define	ERR_VERIFY		_bootErrStat, 0	; Failed to verify if set
#define	CMD_NOP			0x00	
#define	CMD_RESET		0x01	
#define	CMD_RST_CHKSM	0x02	
#define	CMD_CHK_RUN		0x03
#define CMD_BOOT_TEST 	0x04
#define	FN_OUT1							;standard Fn outputs
#define	CANTX			0x02			;port B RB2
;#define	FN_OUT2						;uses DFNON / DFNOFF



;****************************************************************
;	define RAM storage

;	RAM addresses used by boot. can also be used by application.

	CBLOCK 0
	_bootCtlMem
	_bootAddrL		; Address info
	_bootAddrH		
	_bootAddrU		
	_unused0		;(Reserved)
	_bootCtlBits	; Boot Mode Control bits
	_bootSpcCmd		; Special boot commands
	_bootChkL		; Chksum low byte fromPC
	_bootChkH		; Chksum hi byte from PC		
	_bootCount		
	_bootChksmL		; 16 bit checksum
	_bootChksmH		
	_bootErrStat	;Error Status flags
	ENDC
	
	; end of bootloader RAM


	CBLOCK	0		;file registers - access bank
					;interrupt stack for low priority
					;hpint uses fast stack
					;save on interrupt only used if needed.
	W_tempL
	St_tempL
	BSR_tempL
	PCH_tempH		;save PCH in hpint
	PCH_tempL		;save PCH in lpint (if used)
	Fsr_temp0L		;temps for FSRs
	Fsr_temp0H 
	Fsr_temp1L
	Fsr_temp1H 
	Fsr_temp2L
	Fsr_temp2H
	Fsr_temp0Li		;temps for FSRs in LPINT
	Fsr_temp0Hi 
	Fsr_temp1Li
	Fsr_temp1Hi 
	Fsr_temp2Li
	Fsr_temp2Hi
	Fsr_temp2Lf
	Fsr_temp2Hf

	
	TempCANCON
	TempCANSTAT
	TempECAN		;for ECAN
	TempINTCON
	CanID_tmp	;temp for CAN Node ID
	IDtemph		;used in ID shuffle
	IDtempl
	W_temp		;temp store for W reg
	NN_temph	;node number in RAM
	NN_templ
	
	IDcount		;used in self allocation of CAN ID.
	
				
	Count		;counter for loading
	Count1
	Count2
	Count4		;time between encoder steps
	T0count		;needed for 64MHz clock. 
	T3count
	Beep
	
	Keepcnt		;keep alive counter
	Lat0count	;latency counter - transmit buffer 0
    Lat1count   ;latency counter - transmit buffer 1

	Temp		;temps
	Temp1
	Tempd
	LCDtemp		;temp for LCD write
	Err_tmp
	Intemp
	Intemp1
	Inbit
	Incount
	Input
	Atemp		;port a temp value

	Enc_sw		;flag for encoder switch
	Enc_stat	;encoder state
	Dlc			;data length

	Key			;key number
	Key_temp	;for debounce
	Debcount	;debounce counter
	Deb4		;Four times for 16 MHz
	Keyflag		;keyboard mode

	Adtemp		;temp for speed
	Speed		;current speed value from A/D or encoder
	Speed1		;speed to send to loco
	Speed2		;used in speed to ASCII conversion
	Emspeed		;holds Em stop speed - not used!
	Smode		;speed step mode
	
	Handle		;handle given by CS


	Modstat 	;node status. Used when finding a CAN_ID and handle.
				;bit 0 set if it has CANid
				;bit 1 set if waiting for handle
				;bit 2 set if checking handle on reset.
				;bit 3 set if reset by CBUS command
				;bit 4 set if needing keepalive
				;bit 5 set when stop button pressed (flag for emergency stop all)
				;bit 6 set during startup banner/version display
                ;bit 7 Emergency stop all displayed

	Locstat		;status of loco and cab
				;bit 0	loco selected
				;bit 1  loco release
				;bit 2	consist set
				;bit 3	a numeric key
				;bit 4	em. stop
				;bit 5	consist clear
				;bit 6	program mode
				;bit 7  is direction, 1 is foward

	Setupmode	; Status of setup mode
				;bit 0	Prog pressed once for setup mode
                ;bit 1  Prog pressed again - now in setup mode
				;bit 2	Showing command station version number

	Chr_cnt		;character count. Used in LCD display

	
	Char		;store char for LCD
	Adr1		;ASCII address
	Adr2
	Adr3
	Adr4

	

	Num1		;numeric input values
	Num2
	Num3
	Num4
	Numcount	;numbers entered
	Numtemp		;save number for display
	Numtemp1	;additional save for service mode display
	Numtemp2	;for number of chars in device mode
	Numcv		;number of digits in CV number
	Numcvv		;number of digits in CV value
	Adr_hi		;address hi byte
	Adr_lo		;address lo byte

	Datmode		;node status. 
				;bit 0 set if it has waiting CAN frame received
				;bit 1 set if in setup mode
				;bit 2 set is a speed change
				;bit 3 set if in 'device' mode. (to send accessory event)
				;bit 4 set if device info ready to send
				;bit 5 set if device action is an OFF (clear for an ON - as default)
				;bit 6 busy flag
				;bit 7 used for turnout toggle mode
	Dev_hi		;hi byte of device number
	Dev_lo		;lo byte of device number
	Ddr1		;Device ASCII address
	Ddr2
	Ddr3
	Ddr4
	Devcnt		;number of device digits 

	

	Dnum1		;numeric input values
	Dnum2
	Dnum3
	Dnum4
	Dncount		;device numbers entered (index)
	
	
	Hi_temp		;address hi byte in hex to ascii conversion
	Lo_temp		;address lo byte in hex to ascii conversion
	Spd1		;ASCII speed
	Spd2
	Spd3

	Fr1			;function bits  0 to 4
	Fr2			;function bits  5 to 8
	Fr3			;function bits  9 to 12
	Fr4			;function bits  13 to 20
	Fr5			;function bits  21 to 28
	
	Fnum		;holds hex value of Fn
	Fn_temp		;temp for Fn status
	Fn_tog		;on, off or toggle
	Tog_flg		;used in setting mom for Fn keys

	; End of access RAM - following variables must have BSR set to 0 or use FSR access

	Funtemp
	Fnmode		;flags for function and accessory mode
                ; bit 0 - Function range 1  (functions 10-19)
                ; bit 1 - Function range 2  (functions 20-27)
                ; bit 2 - Accessory mode, range held in accrange

 
    Accrange    ; Acessory range - 0 to 12 
    Accnum      ; Accessory number

	Conadr		;consist address (hex)
	
	Con1		;consist numbers
	Con2
	Con3

	Progmode		;program mode flags
					;bit 0		ready to enter CV number
					;bit 1		consist mode
					;bit 2		ready for CV value
					;bit 3		ready to send
					;bit 4		set for service mode
					;bit 5		set for speed step mode	
					;bit 6
					;bit 7

	Sermode			;mode when in service
					; 0 is direct
					; 1 is page
					; 2 is register
					; 3 is address if needed
					; bit 2 is 1 for read and 0 for write
					; bit 3	 Long address in service mode
					; bit 4  Expecting an ACK
					; bit 5  Block numbers in service mode
					; bit 6  Set for long address hi byte read/write
					; bit 7  Set for long address lo byte read/write

	Dispmode		; Display mode, when certain keys have special function
					; 0 is prompting for steal  \_ These 2 bits are same as in GLOC flag byte so,
					; 1 is prompting for share  /  after anding out other bits, can be put straight into packet
					; 2 is loco taken mode (set when showing taken, steal or share)
					; 3 is entering number for shuttle in release mode
					; 4 is error message displayed after session loss or cancellation

	CVnum_hi		;hex value of CV number
	CVnum_lo
	CV_1		;ASCII values of CV number
	CV_2
	CV_3
	CV_4
	CVnum1		;entered CV number (4 digits max)
	CVnum2
	CVnum3
	CVnum4
	
	CVval		;CV value  Hex

	CVval1		;entered CV value (3 digits)or 4 if long address.
	CVval2
	CVval3
	CVval4
	CVchr2		;for CV read
	CVtemp
	CVtemp1
	CV1
	CV2
	CV3
	CV4

	L_adr_hi
	L_adr_lo
	La_1		;ASCII values of long address number (prog)
	La_2
	La_3
	La_4
	L_adr1		;long address for programming
	L_adr2
	L_adr3
	L_adr4

	TststrL		; Address of current test string
    TststrH		;
	
					;the above variables must be in access space (00 to 5F)
				
	
	Cmdtmp		;command temp for number of bytes in frame jump table
	
	
	
	
	Eadr		;temp eeprom address
    Eval
    Ecount
	
	Tx0con			;start of transmit frame  0
	Tx0sidh
	Tx0sidl
	Tx0eidh
	Tx0eidl
	Tx0dlc
	Tx0d0
	Tx0d1
	Tx0d2
	Tx0d3
	Tx0d4
	Tx0d5
	Tx0d6
	Tx0d7

	Tx1con			;start of transmit frame  1
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

	Roll		;rolling bit for enum
	
	Fsr_tmp1Le	;temp store for FSR1
	Fsr_tmp1He 
	Enum0		;bits for new enum scheme.
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


    
    

	Cmdmajv		; Major version of command station, saved for info in setup mode
	Cmdminv		; Minor version of command station
	Cmdbld		; Buid no. of command station

	Lastloco	; Last loco used
	
	;add variables to suit

		
	ENDC
	
		

; This is the bootloader section

;*	Filename Boot2.asm  30/10/09

;*************************************************************** * * * * * * * * * * * * * * ;*
;*	CBUS bootloader

;*	Based on the Microchip botloader 'canio.asm' tho which full acknowledgement is made.
;*	Relevant information is contained in the Microchip Application note AN247

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
;*	boundary.
;* MODE_AUTO_ERASE-Set this to automatically erase Program Memory while writing data.
;* MODE_AUTO_INC-Set this to automatically increment the pointer after writing.
;* MODE_ACK-Set this to generate an acknowledge after a 'put' (PG Mode only)
;*
;* Special Commands:
;* CMD_NOP			0x00	Do nothing
;* CMD_RESET		0x01	Issue a soft reset after setting last EEPROM data to 0x00
;* CMD_RST_CHKSM 	0x02	Reset the checksum counter and verify
;* CMD_CHK_RUN		0x03	Add checksum to special data, if verify and zero checksum
;* CMD_BOOT_TEST 	0x04	Just sends a message frame back to verify boot mode.

;*	Modified version of the Microchip code by M Bolton  30/10/09
;
;	The user program must have the folowing vectors

;	User code reset vector  0x0800
;	User code HPINT vector	0x0808
;	user code LPINT vector	0x0818

;	Checksum is 16 bit addition of all programmable bytes.
;	User sends 2s complement of addition at end of program in command 0x03 (16 bits only)

;**********************************************************************************
	
;	This is the bootloader
; ***************************************************************************** 
;_STARTUPCODE	0x00
	ORG 0x0000
; *****************************************************************************
	bra	_CANInit
	bra	_StartWrite
; ***************************************************************************** 
;_INTV_H CODE	0x08
	ORG 0x0008
; *****************************************************************************

	goto	HIGH_INT_VECT

; ***************************************************************************** 
;_INTV_L CODE	0x18
	ORG 0x0018
; *****************************************************************************

	goto	LOW_INT_VECT 

; ************************************************************** 
;	Code start
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
;	memory. Function will wait until write is finished.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_StartWrite
	movwf 	EECON1
	btfss 	MODE_WRT_UNLCK	; Stop if write locked
	return
	movlw 	0x55	; Unlock
	movwf 	 EECON2 
	movlw	 0xAA 
	movwf 	 EECON2
	bsf	 EECON1, WR	; Start the write
	nop
	btfsc 	EECON1, WR	; Wait (depends on mem type)
	bra	$ - 2
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
;	count. WREG should contain the byte before being called.
;
;	The _bootChksm value is considered a part of the special
;	register set for bootloading. Thus it is not visible. ;
;*************************************************************** * * * * * * * * * * * *
_UpdateChksum:
	addwf	_bootChksmL,	F ; Keep a checksum
	btfsc	STATUS,	C
	incf	_bootChksmH,	F
	return
;************************************************************ ** * * * * * * * * * * * * * * *
;
;	Function:	VOID _CANInit(CAN,	BOOT)
;
;	PreCondition: Enter only after a reset has occurred.
; Input: CAN control information, bootloader control information ; Output: None.
; Side Effects: N/A. Only run immediately after reset.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
;	return when called. It has been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied. ;
;	This routine tests the boot flags to determine if boot mode is
;	desired or normal operation is desired. If boot mode then the
;	routine initializes the CAN module defined by user input. It
;	also resets some registers associated to bootloading.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CANInit:
	clrf	EECON1
	setf	EEADR	; Point to last location of EEDATA
	setf	EEADRH
	bsf	EECON1, RD	; Read the control code
	incfsz EEDATA, W

	goto	RESET_VECT


	clrf	_bootSpcCmd 	; Reset the special command register
	movlw 	0x1C		; Reset the boot control bits
	movwf 	_bootCtlBits 
	movlb	d'14'		; Set Bank 14	for K series
	bcf 	TRISB, CANTX 	; Set the TX pin to output 
	movlw 	CAN_RXF0SIDH 	; Set filter 0
	movwf 	RXF0SIDH
	movlw 	CAN_RXF0SIDL 
	movwf 	RXF0SIDL
	comf	WREG		; Prevent filter 1 from causing a receive event





	movwf	RXF1SIDL	;		
	movlw	CAN_RXF0EIDH	
	movwf	RXF0EIDH	
	movlw	CAN_RXF0EIDL	
	movwf	RXF0EIDL	
	movlw	CAN_RXM0SIDH	;	Set mask
	movwf	RXM0SIDH	
	movlw	CAN_RXM0SIDL	
	movwf	RXM0SIDL	
	movlw	CAN_RXM0EIDH	
	movwf	RXM0EIDH	
	movlw	CAN_RXM0EIDL	
	movwf	RXM0EIDL	
	movlw	CAN_BRGCON1	;	Set bit rate
	movwf	BRGCON1	
	movlw	CAN_BRGCON2	
	movwf	BRGCON2	
	movlw	CAN_BRGCON3	
	movwf	BRGCON3	

	movlb	.15
	clrf	ANCON0
	clrf	ANCON1
	movlw	CAN_CIOCON	;	Set IO
	movwf	CIOCON	

	
	
	clrf	CANCON	; Enter Normal mode
	bcf		TRISB,LED2			;set LED port to outputs
	bcf		TRISB,LED1
	bsf		LED_PORT,LED2		;FWD LED on  Both LEDs on to indicate boot mode
	bsf		LED_PORT,LED1		;REV LED


; ************************************************************ ** * * * * * * * * * * * * * * * 
; This routine is essentially a polling loop that waits for a
; receive event from RXB0 of the CAN module. When data is
; received, FSR0 is set to point to the TX or RX buffer depending
; upon whether the request was a 'put' or a 'get'.
; ************************************************************ ** * * * * * * * * * * * * * * * 
_CANMain
	bcf	RXB0CON, RXFUL	; Clear the receive flag
_wait	clrwdt			; Clear WDT while waiting
	btfss 	RXB0CON, RXFUL	; Wait for a message	
	bra	_wait



_CANMainJp1
	lfsr	0, RXB0D0
	movf	RXB0DLC, W 
	andlw 	0x0F
	movwf 	_bootCount 
	movwf 	WREG1
	bz	_CANMain 
_CANMainJp2				;?
	


; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _ReadWriteMemory()
;
; PreCondition:Enter only after _CANMain().
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
;	return when called. It has been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;This is the memory I/O engine. A total of eight data bytes are received and decoded. In addition two control bits are received, put/get and control/data.
;A pointer to the buffer is passed via FSR0 for reading or writing. 
;The control register set contains a pointer, some control bits and special command registers.
;Control
;<PG><CD><ADDRL><ADDRH><ADDRU><_RES_><CTLBT>< SPCMD><CPDTL><CPDTH>
;Data
;<PG>< CD>< DATA0>< DATA1>< DATA2>< DATA3>< DATA4>< DATA5>< DATA6>< DATA7>
;PG bit:	Put = 0, Get = 1
;CD bit:	Control = 0, Data = 1

; ************************************************************ ** * * * * * * * * * * * * * * *
_ReadWriteMemory:
	btfsc	CAN_CD_BIT	; Write/read data or control registers
	bra	_DataReg
; ************************************************************ ** * * * * * * * * * * * * * * * ; This routine reads or writes the bootloader control registers,
; then executes any immediate command received.
_ControlReg
	lfsr	1, _bootAddrL		;_bootCtlMem
_ControlRegLp1

	movff 	POSTINC0, POSTINC1 
	decfsz 	WREG1, F
	bra	_ControlRegLp1

; ********************************************************* 
; This is a no operation command.
	movf	_bootSpcCmd, W		; NOP Command
	bz	_CANMain
;	bz	_SpecialCmdJp2		; or send an acknowledge

; ********************************************************* 
; This is the reset command.
	xorlw 	CMD_RESET		; RESET Command 
	btfss 	STATUS, Z
	bra		_SpecialCmdJp4
	setf	EEADR		; Point to last location of EEDATA
	setf	EEADRH
	clrf	EEDATA		; and clear the data (FF for now)
	movlw 	b'00000100'	; Setup for EEData
	rcall 	_StartWrite
	bcf		LED_PORT,LED1		;red LED off
	reset
; *********************************************************
; This is the Selfcheck reset command. This routine 
; resets the internal check registers, i.e. checksum and 
; self verify.
_SpecialCmdJp4
	movf	_bootSpcCmd, W 
	xorlw 	CMD_RST_CHKSM
	bnz		_SpecialCmdJp1
	clrf	_bootChksmH
	clrf	_bootChksmL
	bcf		ERR_VERIFY		
	clrf	_bootErrStat
	bra		_CANMain
; RESET_CHKSM Command
; Reset chksum
; Clear the error verify flag

;This is the Test and Run command. The checksum is
; verified, and the self-write verification bit is checked. 
; If both pass, then the boot flag is cleared.
_SpecialCmdJp1
	movf	_bootSpcCmd, W		; RUN_CHKSM Command
	xorlw 	CMD_CHK_RUN 
	bnz	_SpecialCmdJp3
	movf	_bootChkL, W	; Add the control byte
	addwf	 _bootChksmL, F
	bnz	_SpecialCmdJp2
	movf	_bootChkH, W 
	addwfc	_bootChksmH, F
	bnz	_SpecialCmdJp2
	btfsc 	ERR_VERIFY		; Look for verify errors
	bra	_SpecialCmdJp2

	bra		_CANSendOK	;send OK message


_SpecialCmdJp2

	bra	_CANSendNOK	; or send an error acknowledge


_SpecialCmdJp3
	movf	_bootSpcCmd, W		; RUN_CHKSM Command
	xorlw 	CMD_BOOT_TEST 
	bnz	_CANMain
	bra	_CANSendBoot

; ************************************************************** * * * * * * * * * * * * * * * 
; This is a jump routine to branch to the appropriate memory access function.
; The high byte of the 24-bit pointer is used to determine which memory to access. 
; All program memories (including Config and User IDs) are directly mapped. 
; EEDATA is remapped.
_DataReg
; *********************************************************
_SetPointers
	movf	_bootAddrU, W	; Copy upper pointer
	movwf 	TBLPTRU
	andlw 	0xF0	; Filter
	movwf 	WREG2
	movf	_bootAddrH, W	; Copy the high pointer
	movwf 	TBLPTRH
	movwf 	EEADRH
	movf	_bootAddrL, W	; Copy the low pointer
	movwf 	TBLPTRL
	movwf	 EEADR
	btfss 	MODE_AUTO_INC	; Adjust the pointer if auto inc is enabled
	bra	_SetPointersJp1
	movf	_bootCount, W	; add the count to the pointer
	addwf	 _bootAddrL, F 
	clrf	WREG
	addwfc	 _bootAddrH, F 
	addwfc	 _bootAddrU, F 

_SetPointersJp1			;?

_Decode
	movlw 	0x30
	cpfslt 	WREG2
	bra	_DecodeJp1



	bra	_PMEraseWrite

_DecodeJp1
	movf	WREG2,W
	xorlw 	0x30
	bnz	_DecodeJp2



	bra	_CFGWrite 
_DecodeJp2
	movf	WREG2,W 
	xorlw 0xF0
	bnz	_CANMain
	bra	_EEWrite

f	

; Program memory < 0x300000
; Config memory = 0x300000
; EEPROM data = 0xF00000
	
; ************************************************************ ** * 
; ************************************************************** * 
; Function: VOID _PMRead()
;	VOID _PMEraseWrite ()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
; the source data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;These are the program memory read/write functions. Erase is available through control flags. An automatic erase option is also available.
; A write lock indicator is in place to ensure intentional write operations.
;Note: write operations must be on 8-byte boundaries and must be 8 bytes long. Also erase operations can only occur on 64-byte boundaries.
; ************************************************************ ** * * * * * * * * * * * * * * *



_PMEraseWrite:
	btfss 	MODE_AUTO_ERASE
	bra	_PMWrite
_PMErase:
	movf	TBLPTRL, W
	andlw	b'00111111'
	bnz	_PMWrite
_PMEraseJp1
	movlw	b'10010100' 
	rcall 	_StartWrite 
_PMWrite:
	btfsc 	MODE_ERASE_ONLY


	bra	_CANMain 

	movf	TBLPTRL, W
	andlw	b'00000111'
	bnz	_CANMain 
	movlw 	0x08
	movwf WREG1

_PMWriteLp1					; Load the holding registers
	movf	POSTINC0, W 
	movwf 	TABLAT
	rcall	 _UpdateChksum 	; Adjust the checksum
	tblwt*+
	decfsz	 WREG1, F
	bra	_PMWriteLp1

#ifdef MODE_SELF_VERIFY 
	movlw	 0x08
	movwf 	WREG1 
_PMWriteLp2
	tblrd*-			; Point back into the block
	movf	POSTDEC0, W 
	decfsz	 WREG1, F
	bra	_PMWriteLp2
	movlw	 b'10000100' 	; Setup writes
	rcall	_StartWrite 	; Write the data
	movlw 	0x08
	movwf 	WREG1
_PMReadBackLp1
	tblrd*+			; Test the data
	movf	TABLAT, W 
	xorwf 	POSTINC0, W
	btfss	STATUS, Z
	bsf	ERR_VERIFY 
	decfsz 	WREG1, F
	bra	_PMReadBackLp1	; Not finished then repeat
#else
	tblrd*-			; Point back into the block
				 ; Setup writes
	movlw 	b'10000100' 	; Write the data
	rcall 	_StartWrite 	; Return the pointer position
	tblrd*+
#endif

	bra	_CANMain


; ************************************************************** * * * * * * * * * * * * * * *
 ; Function: VOID _CFGWrite()
;	VOID _CFGRead()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of the source data. 
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;
;	These are the Config memory read/write functions. Read is
;	actually the same for standard program memory, so any read
;	request is passed directly to _PMRead.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CFGWrite

#ifdef MODE_SELF_VERIFY		; Write to config area
	movf	INDF0, W		; Load data
#else
	movf	POSTINC0, W
#endif
	movwf 	TABLAT
	rcall 	_UpdateChksum	; Adjust the checksum
	tblwt*			; Write the data
	movlw	b'11000100' 
	rcall 	_StartWrite
	tblrd*+			; Move the pointers and verify
#ifdef MODE_SELF_VERIFY 
	movf	TABLAT, W 
	xorwf 	POSTINC0, W

#endif
	decfsz 	WREG1, F
	bra	_CFGWrite	; Not finished then repeat

	bra	_CANMain 



; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _EERead()
;	VOID _EEWrite()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
 ;	the source data.
; Input:	None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;
;	This is the EEDATA memory read/write functions.
;
; ************************************************************ ** * * * * * * * * * * * * * * *


_EEWrite:

#ifdef MODE_SELF_VERIFY
	movf	INDF0, W
#else
	movf	POSTINC0, W 
#endif

	movwf 	EEDATA
	rcall 	_UpdateChksum 
	movlw	b'00000100' 
	rcall	 _StartWrite

#ifdef MODE_SELF_VERIFY 
	clrf	EECON1
	bsf	EECON1, RD
	movf	EEDATA, W 
	xorwf 	POSTINC0, W
	btfss	STATUS, Z
	bsf	ERR_VERIFY
#endif

	infsnz	 EEADR, F 
	incf 	EEADRH, F 
	decfsz 	WREG1, F
	bra	_EEWrite


	bra	_CANMain 
	

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
;	VOID _CANSendResponce ()
;
; PreCondition:TXB0 must be preloaded with the data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied. ;
;	These routines are used for 'talking back' to the source. The
;	_CANSendAck routine sends an empty message to indicate
;	acknowledgement of a memory write operation. The
;	_CANSendResponce is used to send data back to the source. ;
; ************************************************************ ** * * * * * * * * * * * * * * *



_CANSendMessage
	btfsc 	TXB0CON,TXREQ 
	bra	$ - 2
	movlw 	CAN_TXB0SIDH 
	movwf 	TXB0SIDH
	movlw 	CAN_TXB0SIDL 
	movwf 	TXB0SIDL
	movlw 	CAN_TXB0EIDH 
	movwf 	TXB0EIDH	

	movlw	CAN_TXB0EIDL
	movwf	TXB0EIDL
	bsf	CANTX_CD_BIT
	btfss	CAN_CD_BIT 
	bcf	CANTX_CD_BIT
	bsf	TXB0CON, TXREQ
    	bra	 _CANMain	; Setup the command bit

_CANSendOK				;send OK message 
	movlw	1			;a 1 is OK
	movwf	TXB0D0
	movwf	TXB0DLC
	bra		_CANSendMessage
	
_CANSendNOK				;send not OK message
	clrf	TXB0D0		;a 0 is not OK
	movlw	1
	movwf	TXB0DLC
	bra		_CANSendMessage

_CANSendBoot
	movlw	2			;2 is confirm boot mode
	movwf	TXB0D0
	movlw	1
	movwf	TXB0DLC
	bra		_CANSendMessage
    
; Start the transmission

; 	End of bootloader	

;****************************************************************
;
;		start of cancab program code



		ORG		0800h

loadadr	nop						;for debug
		goto	setup

		ORG		0808h
		goto	hpint			;high priority interrupt
		
		ORG		0818h	
		goto	lpint			;low priority interrupt


;	NODE PARAMETER BLOCK

		ORG		0820h			
nodeprm	db		MAN_NO, MINOR_VER, MODULE_ID, EVT_NUM, EVperEVT, NV_NUM, MAJOR_VER,NODEFLGS,CPU_TYPE,PB_CAN	; Main parameters
 		dw		loadadr			; Load address for module code above bootloader
		dw		0				; Top 2 bytes of 32 bit address not used
	dw          0				;15-16 CPU Manufacturers ID low
		dw      0				;17-18 CPU Manufacturers ID high
		db  	CPUM_MICROCHIP,BETA_VER			;19-20 CPU Manufacturers code, Beta revision
sparprm	fill	0, prmcnt-$		; Unused parameter space set to zero

PRMCOUNT equ	sparprm-nodeprm ; Number of parameter bytes implemented

		ORG		0838h

prmcnt	dw		PRMCOUNT		
nodenam	dw		Cabstr	
		dw		0

PRCKSUM	equ	MAN_NO+MINOR_VER+MODULE_ID+EVT_NUM+EVperEVT+NV_NUM+MAJOR_VER+NODEFLGS+CPU_TYPE+PB_CAN+HIGH Cabstr+LOW Cabstr+HIGH loadadr+LOW loadadr+PRMCOUNT+CPUM_MICROCHIP+BETA_VER

cksum	dw		PRCKSUM			; Checksum of parameters


;*******************************************************************

		ORG		0840h			;start of program
;	
;
;		high priority interrupt. Used for CAN transmit error.

hpint           movff	CANCON,TempCANCON
		movff	CANSTAT,TempCANSTAT
	
		movff	FSR0L,Fsr_temp0L		;save FSR0
		movff	FSR0H,Fsr_temp0H
		movff	FSR1L,Fsr_temp1L		;save FSR1
		movff	FSR1H,Fsr_temp1H
		
		

		movlw	8
		movwf	PCLATH
		movf	TempCANSTAT,W			;Jump table
		andlw	B'00001110'
		addwf	PCL,F			;jump
		bra		back
		bra		errint			;error interrupt
		bra		back
		bra		back
		bra		back
		bra		back		;only TX error interrupts used with ECAN
		bra		back
		bra		back
		

	
		;error routine here. Only acts on lost arbitration	
errint	movlb	.15					;change bank
		btfss	TXB1CON,TXLARB
		bra		chktx0				;check other buffer
        lfsr    FSR0,TXB1CON
        lfsr    FSR1,Lat1count
        bra     retrytx

chktx0  btfss   TXB0CON,TXLARB
        bra     errbak              ; no lost arbitration
        lfsr    FSR0,TXB0CON
        lfsr    FSR1,Lat0count

retrytx	movf	INDF1,F			    ; Lat?count - is it already at zero?
		bz		errbak
		decfsz	INDF1,F             ; count down retry latency delay
		bra		errbak
		bcf		INDF0,TXREQ         ; TXB?CON - abort current transmission
		movlw	B'00111111'
		andwf	PREINC0,F			; TXB?SIDH - change priority
        decf    FSR0L
txagain bsf		INDF0,TXREQ		    ; TXB?CON - try again
        
					
errbak	

		bcf		RXB0CON,RXFUL	;ready for next
		movlb	0
		bcf		COMSTAT,RXB0OVFL	;clear overflow flags if set
		bcf		COMSTAT,RXB1OVFL
        movlb	0		
		bra		back1


		
back	bcf		RXB0CON,RXFUL	;ready for next
	
	
back1	clrf	PIR5			;clear all flags
		movf	CANCON,W
		andlw	B'11110001'
		iorwf	TempCANCON,W
		
		movwf	CANCON
		movff	Fsr_temp0L,FSR0L		;recover FSR0
		movff	Fsr_temp0H,FSR0H
		movff	Fsr_temp1L,FSR1L		;recover FSR1
		movff	Fsr_temp1H,FSR1H

		
		retfie	1				;use shadow registers

;***************************************************
;now handled as a subroutine			
		
isRTR	btfss	Modstat,0		;got CAN ID ?
		return					;back
		
		movlb	.15
isRTR1	btfsc	TXB2CON,TXREQ	
		bra		isRTR1		
		bsf		TXB2CON,TXREQ	;send ID frame - preloaded in TXB2

		movlb	0
		return





		



;**************************************************************
;
;
;		low priority interrupt. Used for keepalive and title delay
;	

lpint	movwf	W_tempL				
		movff	STATUS,St_tempL
		movff	FSR0L,Fsr_temp0Li
		movff	FSR0H,Fsr_temp0Hi 
		movff	FSR1L,Fsr_temp1Li
		movff	FSR1H,Fsr_temp1Hi 
		movff	FSR2L,Fsr_temp2Li
		movff	FSR2H,Fsr_temp2Hi
		movff	BSR,BSR_tempL 
		bcf		INTCON,TMR0IF	;clear flag
		decfsz	T0count
		bra		not_yet
		movlw	4
		movwf	T0count
		btfsc	Modstat,4		;no keepalive
		call	kp_pkt			;send speed packet
		btfsc	Modstat,6		;Delay for title
		call	clear_title		;clear title from display
not_yet		movff	BSR_tempL,BSR
		movff	Fsr_temp0Li,FSR0L
		movff	Fsr_temp0Hi,FSR0H
		movff	Fsr_temp1Li,FSR1L
		movff	Fsr_temp1Hi,FSR1H
		movff	Fsr_temp2Li,FSR2L
		movff	Fsr_temp2Hi,FSR2H
		movf	W_tempL,W
		movff	St_tempL,STATUS	
		retfie	
				
				
	
						
				
	
								

;*********************************************************************

main	
		

	
main1	;clrwdt					;clear watchdog
		btfsc	ENC_PORT,ENC		;is it an encoder
		bra		pot				;no
		btfss	PIR4,TMR4IF		;timer 4 rollover? Used for encoder rate dependency, 4mSec time.
		bra		enc_sw			;no
		bcf		PIR4,TMR4IF
		movf	Count4,F		;is it at 0?
		bz		enc_sw			;yes so do nothing
		decf	Count4,F		;decrement by 1 every 4 mSec

;	This code is for an encoder 
			
enc_sw	btfsc	ENC_PORT,3			;is encoder button in? (no debounce used here)
		bra		enc_up
		btfsc	Enc_sw,0		;first time?
		bra		enc_up
		clrf	Speed
		clrf	Speed1
		bsf		Datmode,2		;yes so send new speed
		bsf		Enc_sw,0		;flag done
enc_up	btfss	PORTA,3			;encoder button out?
		bra		main1d			;still in
		bcf		Enc_sw,0		;button up so clear flag
		bra		main1d

;	This code for a pot only.

pot		btfss	PIR2,TMR3IF		;is it time for an A/D
		bra		main1d
		bcf		PIR2,TMR3IF
		call	a_to_d			;get speed
		

main1d	btfss	PIR1,TMR1IF		;for beep duration or response timer
		bra		main1c
		bcf		PIR1,TMR1IF
		btfss	Datmode,7		;is it waiting for a response?
		bra		main1e
		bcf		T1CON,TMR1ON	;stop timer
		bcf		T2CON,TMR2ON	;beep off
		bcf		Datmode,7
		goto	devtg_1			;has got a response
main1e		decfsz	Beep			;needs x4 with 16 MHz
		
		bra		main1c
		bcf		T2CON,TMR2ON	;beep off
		bcf		T1CON,TMR1ON


main1c	btfss	PIR1,TMR2IF		;is it T2 rollover
		bra		main1b
		movlw	0x9F
		movwf	PR2				;reset T2
		bcf		PIR1,TMR2IF
		btg		LATC,2			;output square wave
		clrwdt					;clear watchdog
	

main1b	btfsc	Datmode,0		;any new CAN frame received?
		goto	packet			;yes
		btfsc	COMSTAT,7		;look for CAN input. 
		bra		getcan
		bra		main1a

getcan	movf	CANCON,W
		andlw	B'00001111'
		movwf	TempCANCON
		movf	ECANCON,W
		andlw	B'11110000'
		iorwf	TempCANCON,W
		movwf	ECANCON
		btfsc	RXB0SIDL,EXID		;ignore extended frames here
		bra		no_can
		btfss	RXB0DLC,RXRTR		;is it RTR input?
		bra		get_1
		call	isRTR				;send ID frame
		bra		no_can
		
get_1						
		
get_3	movf	RXB0DLC,F
		bnz		get_2			;ignore zero length frames
		
		bra		no_can 
		
		
get_2	
		bsf		Datmode,0		;valid message frame received	
		bra		main1a

no_can	bcf		RXB0CON,RXFUL	;for next in ECAN

main1a	btfss	Locstat,4		;in em. stop mode?
		bra		main2			; no - carry on
		

stop1	movlw	1               ; in emergency stop, need speed to be zero before allow to continue
		movwf	Speed1
		movf	Speed,F			;is speed zero?
		bnz		main3			;if not -- do nothing
		bcf		Locstat,4		;clear em. stop
		bcf		Modstat,7       ; Emergency stop all flag

		btfsc	Datmode,6		;busy?
		bra		main4
		call	locdisp
		call	spd_pkt

main4	btfsc	Datmode,6		;busy?
		bra		main3
		btfss	Datmode,3		;device mode
		bra		main3
		call	devdisp
		btfss	Datmode,4
		bra		main3
		call	dev_nr
		call	devdisp1
		bra		main3
		
main2	clrwdt
		btfss	Datmode,2		; speed change?
		bra		main3		    ; no - so back to keypad scan
        bcf     Modstat,5       ; Clear stop pressed once flag on any knob movement
		movf	Speed1,F		; Is it a non zero speed?
		bnz		sndspd

		btfss	Modstat,7		; Are we coming out of stop all?
		bra		main2a			
        movlw   1
        movwf   Speed1          ; For speed zero coming out of emerg stop, still send speed 1
        bcf     Modstat,7
		btfsc	Datmode,6		;busy?
		bra		main3			;yes so no message
		call	lcd_clr			; If so, clear message
main2a	btfsc	Locstat,0		;any loco selected?
        bra		main2b			;yes, so continue as normal
		call	locprmpt		; Display loco prompt again
main2b	btfss	Datmode,3		; in dev. mode?
		bra		sndspd
		call	devdisp			; display prompt
		btfsc	Datmode,4		; device already set?
		call	devdisp1		; display complete device info. 
		



sndspd	call	spd_pkt	        ; Send new changed speed
		
        
								
		;kaypad scanning routine and encoder scan

main3	
		btfsc	ENC_PORT,ENC		;is at an encoder?
		bra		main3a			;no
		
		movlw	B'00000110'		;mask except input A,B
		andwf	PORTA,W
		rrncf	WREG			;shift
		movwf	Atemp			;store it		
		

		movf	Enc_stat,F		;get state. Is it 0?
		bz		enc0			;state 0
		movlw	1
		subwf	Enc_stat,W		;is it state 1?
		bz		enc1
		movlw	2
		subwf	Enc_stat,W		;is it state 2?
		bz		enc2
		movlw	3
		subwf	Enc_stat,W		;is it state 3?
		bz		enc3
		movlw	4
		subwf	Enc_stat,W		;is it state 4?
		bz		enc4
		movlw	5
		subwf	Enc_stat,W		;is it state 5?
		bz		enc5
		movlw	6
		subwf	Enc_stat,W		;is it state 6?
		bz		enc6
		movlw	7				;SW Extra state added by SW for debounce
		subwf	Enc_stat,W		;SW is it state 7 for debounce
		bz		enc7			;SW
		bra		main3a			;shouldn't ever be here

enc0	movlw	1
		subwf	Atemp,W			;is it a 01
		bz		enc0a
		movlw	2
		subwf	Atemp,W				;is it 10
		bnz		main3a			;exit
		movlw	1
		movwf	Enc_stat
		bra		main3a			;continue
enc0a	movlw	4
		movwf	Enc_stat
		bra		main3a

enc1	movf	Atemp,F			;state 1. Is it 00
		bz		enc1a
		bra		main3a			;do nothing
enc1a	movlw	2				;to state 2
		movwf	Enc_stat
		bra		main3a

enc2	movlw	1				;state 2. Is it 01
		subwf	Atemp,W
		bz		enc2a
		bra		main3a			;do nothing
enc2a	movlw	3
		movwf	Enc_stat
		bra		main3a

enc3	movlw	3				;state 3. Is it 11?
		subwf	Atemp,W
		bz		enc3a
		bra		main3a
enc3a	
		movf	Count4,W		;get time from last step
		rrncf	WREG			;divide by 16
		rrncf	WREG
		rrncf	WREG
		rrncf	WREG
		incf	WREG			;must be at least 1
		andlw	B'00001111'		;mask
		addwf	Speed,W			;speed steps
		bnn		enc3b			;less than 127 
		movlw	0x7F			;127 max
enc3b	movwf	Speed			;new speed
		movlw	ENC_RATSENS		;for counter
		movwf	Count4			;for next step
		
		movff	Speed,Speed1	;for send
		movlw	0x7F
		subwf	Speed1,W
		bz		no_spd1
		incf	Speed1			;miss out speed 1
no_spd1	bsf		Datmode,2		;flag speed change
no_spd	movlw	7				;SW move to state 7 for debounce
		movwf	Enc_stat		;SW
	
		bra		main3a



enc4	movf	Atemp,F			;state 4. Is it 00
		bz		enc4a
		bra		main3a			;do nothing
enc4a	movlw	5				;to state 2
		movwf	Enc_stat
		bra		main3a

enc5	movlw	2				;state 5. Is it 10
		subwf	Atemp,W
		bz		enc5a
		bra		main3a			;do nothing
enc5a	movlw	6
		movwf	Enc_stat
		bra		main3a

enc6	movlw	3				;state 3. Is it 11?
		subwf	Atemp,W
		bz		enc6a
		bra		main3a
enc6a	
		movf	Count4,W		;get time from last step
		rrncf	WREG			;divide by 16
		rrncf	WREG
		rrncf	WREG
		rrncf	WREG
		incf	WREG			;must be at least 1
		andlw	B'00001111'		;mask
		subwf	Speed,W			;subtract speed steps
		bnn		enc6c			;not less than 0?
		clrf	WREG			;set to 0
enc6c	movwf	Speed
		movlw	0x7F			;for counter
		movwf	Count4			;for next step
		movff	Speed,Speed1
		movf	Speed,F
		bz		enc6b			;don't increment if zero
		incf	Speed1			;miss out 1
enc6b	bsf		Datmode,2		;flag speed change
		bra		no_spd

enc7	movlw	ENC_RATSENS		;SW state 7. Has 4ms passed yet
		subwf	Count4,W		;SW
		bnz		enc7a			;SW 4ms now passed
		bra		main3a			;SW 4ms not passed yet
enc7a	clrf	Enc_stat		;SW onto state 0 now 4ms has passed


main3a	btfsc	Keyflag,0		;continue
		bra		keyup
		btfsc	Key,7			;key detected?
		bra		deb				;debounce
		call	scan			;scan inputs for change
	
		btfsc	Key,7			;any key?
		movff	Key,Key_temp
main3b	bra		main
deb		
		call	deb_sub			;debounce subroutine
		movf	WREG			;out if not zero
		bz		main3b			;otherwise scan again
		
		
		
		call	scan
		btfsc	Key,7			;no key now
		bra		chk_key
		
		clrf	Key
	
		goto 	main
	
chk_key	movf	Key,W			;get key
		subwf	Key_temp,W
		bz		key_OK			;valid key
		clrf	Key
		goto	main

keyup	btfss	Tog_flg,7
		bra		keyup3
		call	mom_set
		movf	WREG
		bz		keyup3
		
keyup5	goto	main			;con key not released
keyup3	btfsc	Keyflag,1
		bra		debclear		;release debounce
		call	scan
		btfsc	Key,7			;released?
		goto	main
		bsf		Keyflag,1		;set for release debounce
;		clrf	Debcount
		bra		main
keyup4	btfss	Tog_flg,7
		bra		keyup5
		movlw	0				;force off if mom
		btfsc	Fn_temp,1
		call	funsend			;for mom
		clrf	Tog_flg
		clrf	Fn_temp
		bra		keyup5			;done	


		
		
debclear;		decfsz	Debcount
		call	deb_sub
		movf	WREG
		bnz		debcl_1
		bra		main			;loop till out
debcl_1	call	scan			;check again
		btfss	Key,7			;not released now
		bra		keyup1
		bcf		Keyflag,1
		bra		main
		
keyup1	clrf	Keyflag			;ready for next
		btfss	Locstat,0
		goto	main
		btfsc	Datmode,3		;is it dev mode
		goto	main
		btfss	Locstat,3		;was a FN?
		bra		keyup4
		bcf		Tog_flg,7
		bcf		Locstat,3
		bra		keyup4




				
key_OK	movlw	LOW Keytbl			;get key value
		movwf	EEADR
		movf	Key_temp,W
		andlw	B'01111111'
		addwf	EEADR,F
		call	eeread
		movwf	Key_temp		;actual key value
		movlw	0x09
		cpfsgt	Key_temp
		bra		number
		movlw	0x0A			;DIR?
		subwf	Key_temp,W
		bz		dir
		movlw	0x0B			;EM STOP
		subwf	Key_temp,W
		bz		emstop
		movlw	0x0C			;Consist
		subwf	Key_temp,W
		bz		cons
		movlw	0x0D			;Loco
		subwf	Key_temp,W
		bz		loco
		movlw	0x0E			;enter
		subwf	Key_temp,W
		bz		enter1
		movlw	0x0F			;Fr1
		subwf	Key_temp,W
		bz		fr1a
		movlw	0x10			;Fr2
		subwf	Key_temp,W
		bz		fr2a
		movlw	0x11			;Prog
		subwf	Key_temp,W
		bz		proga			
keyback	bsf		Keyflag,0
		nop
		goto	main

enter1	goto	enter
fr1a	goto	fr1
fr2a	goto	fr2
proga	goto	prog

;		set direction

dir		call	dir_sub
		bra		keyback


;		emergency stop

emstop	call	em_sub
		bra		keyback

;		consist key pressed

cons	btfsc	Datmode,3		;is it dev mode?
		bra		dev_tog			;toggle device N or R
		btfsc	Modstat,7		;in stop mode?   
		bra		keyback			;do nothing
		btfsc	Dispmode,2		;Is loco taken message displayed?
		bra		tknopt			;Do steal/share options
		btfsc	Locstat,2		;is it already set
		bra		cons1
		btfss	Locstat,0		;valid loco?
		bra		keyback
		bsf		Datmode,6		;busy
		call	conset
		bra		keyback
cons1	bsf		Datmode,6		;busy
		bcf		Locstat,2
		bsf		Locstat,5		;consist clear
	
		call	conclear
		bra		keyback

dev_tog	movf	Devcnt,F
		bz		keyback			;no number entered
		btfss	Datmode,4
		call	devconv			;first time so convert number
		bsf		Datmode,4
		call	stat_req		;get state of TO
		bra		keyback			;wait for answer
devtg_1	
		call	devout			;send short event
		btg		Datmode,5
		call	dev_nr
		btfsc	Datmode,7
		bra		tog_out
		call	beep
		bra		keyback

tog_out movlw	B'00110010'
		movwf	T1CON			;reset TMR1
		bcf		T2CON,TMR2ON
		bcf		Datmode,7		;done
		call	beep
		bra		keyback

; When loco taken, consist key toggles between steal or share prompt

tknopt	btfsc	Dispmode,0		; Prompting for steal?  
		bra		prmtsh			; Yes - go and prompt for share
		bcf		Dispmode,1		; No, either still on taken message or prompting for share, set flag now prompting for Steal
		bsf		Dispmode,0		; Clear share flag
		call	loc_adr
		movlw	HIGH Stlstr
		movwf	TBLPTRH
		movlw	LOW Stlstr		; Steal prompt
		bra		tkprmt

prmtsh	bsf		Dispmode,1		; Set share flag
		bcf		Dispmode,0		; clear steal flag
		call	loc_adr
		movlw	HIGH Sharestr
		movwf	TBLPTRH
		movlw	LOW Sharestr	; Share prompt
		
tkprmt	call	lcd_str
		bra 	keyback	

;	loco key  (does various things)

loco	
		call	lcd_clr
		bcf		Datmode,6			;clear busy flag always
		clrf	Progmode
		clrf	Sermode
		clrf	Dispmode	
		clrf	Setupmode
		btfsc	Locstat,6			;in prog mode?
		bra		prog_ret			;returning from prog mode
		btfss	Modstat,7			;clear from stop all
		bra		loco1a

	
		bcf		Modstat,7
		bcf		Modstat,5
		btfss	Locstat,0			;any loco
		bra		no_loco

loco1b	call	loco_lcd
		movlw	0x40
		call	cur_pos
		movlw	HIGH Stopstr
		movwf	TBLPTRH
		movlw	LOW Stopstr
		call	lcd_str
		bra		loco1d

loco1c	call	locprmpt			;prompt for loco again
		bra		keyback
		
loco1a	btfsc	Locstat,4			;normal stop mode?
		bra		loco1b
loco1d	btfsc	Datmode,3
		bra		devback				;clear from device mode

		
loco1	
		btfsc	Locstat,0			;any loco set?
		bra		locset
		btfsc	Locstat,1			;release mode?
		bra		locset
		btfsc	Locstat,2			;consist
		bra		locset
		btfsc	Locstat,5
		bra		locset
		btfsc	Locstat,6
		bra		locset
		
no_loco	call	lcd_clr
		lfsr	FSR2,Num1			;reset pointer
		movlw	" "
		movwf	Adr1				;clear address string
		movwf	Adr2
		movwf	Adr3
		movwf	Adr4
		call	locprmpt			;prompt for loco again
		
		bcf		Datmode,6
		clrf	Numcount
		bra		keyback

locset	clrf	Numcount			;for abort
		btfsc	Locstat,2
		bra		conout				;out of consist
		btfsc	Locstat,5
		bra		conout
		btfsc	Locstat,6
		bra		conout
		btfss	Locstat,1
		bra		clear

		bcf		Locstat,1
		bsf		Locstat,0
		bcf		Progmode,6
		bcf		Datmode,6
		call 	locdisp				; Redisplay loco info
		bra		keyback

clear	
		bsf		Locstat,1
		bcf		Locstat,0
		call	lcd_clr
		call	loco_lcd
		call	lcd_cr

 		movf    Speed,w             ; If speed is none zero, this is a dispatch
        bnz     dspatch	
        bra     disprel

devback	btfss	Locstat,0			;no loco
		bra		db2
		bsf		Locstat,0			;don't prompt for release if coming back from a device set
		bcf		Locstat,1
	
		call	locdisp
		
	
db1		bcf		Datmode,3			;out of dev mode
		movlw	LOW	Dat_save
		movwf	EEADR
		movf	Datmode,W
		call	eewrite
		bra		keyback

db2		bcf		Datmode,3			;out of dev mode
		movlw	LOW	Dat_save
		movwf	EEADR
		movf	Datmode,W
		call	eewrite
		goto	no_loco
        
dspatch movlw   HIGH DispStr
        movwf   TBLPTRH
        movlw   LOW DispStr

dsp1	call	lcd_str
		bsf		Datmode,6		;busy
		bra		keyback


disprel	movlw	HIGH Relstr
		movwf	TBLPTRH
		movlw	LOW	Relstr
		bra		dsp1

prog_ret bcf	Locstat,6		;clear prog mode
		call	locdisp
		bra		keyback

conout	bsf		Locstat,0		;reenable loco
		bcf		Locstat,2		;out of consist mode
		bcf		Locstat,5		;out of consist clear mode
		bcf		Locstat,6		;out of prog mode
		clrf	Progmode
		clrf	Sermode
		bcf		Datmode,6		;not busy
		call	locdisp
		bra		keyback

	
;		enter key (acts on whatever has been set up)
		
enter	btfss	Datmode,6		;busy?
		goto	devmode			;OK so set device command
		btfss	Dispmode,2		; Loco taken mode?
		bra		entcnt			; no - continue
		
		movlw	B'00000011'		; Check for either share or steal mode
		andwf	Dispmode,w
		bnz		rqhndl  		; No, so do nothing
		bra		keyback			; Yes - re-request loco

entcnt	btfsc	Dispmode,4		; Error message displayed?
		bra		loco			; Enter acts same as loco to clear error message

		bcf		Sermode,5
		btfsc	Progmode,7
		call	ss_set
		btfss	Modstat,0		;got CAN ID?

		call	self_en
		movlw	B'00110011'
		movwf	T3CON			;set timer 3 now for A/D update rate
		btfss	Locstat,0
		call	beep
		bcf		Modstat,3		;clear reset flag
		btfsc	Locstat,1		;release mode?
		bra		rel_mode
		btfsc	Locstat,2		;consist set?
		bra		con_mode
		btfsc	Locstat,5
		bra		con_clr
		btfsc	Locstat,6
		bra		prog_mode
		btfsc	Locstat,0		;any loco selected?
		bra		keyback1
		movf	Numcount,F
		bz		noadr			;no address set
		btfsc	Datmode,3
		bra		devcon
		movff	Numcount,Numtemp	;for display later
		call	adrconv			;put input address into two HEX bytes
		movlw	0				; Flag for normal request (not steal/share)
rqhndl	call	get_handle
		bcf		Datmode,6		;not busy
		bra		keyback			;wait for handle from CS
devcon	btfsc	Datmode,4		;nothing to send
		call	devout
		bra		rqhndl


		; Loco taken, so if user has toggled to steal or share using consist key, 
		; and now presses enter, redo loco request in steal or share mode


		
noadr	bra		keyback

ssmode	btfsc	Progmode,6		;in test mode?
		bra		keyback
		bsf		Progmode,7
		call	ss_mode			;do speed step sequence
		bra		keyback

fr1		btfsc	Datmode,3		;device mode?
		bra		keyback
		btfsc	Modstat,7
		bra		keyback

		btfsc	Progmode,4		;service mode?
		bra		frprog
		btfss	Locstat,0		;any loco?
		bra		ssmode			;speed step set
		btfsc	Locstat,6		;in any prog mode?
		goto	keyback			;do nothing
		btfss	Fnmode,0
		bra		setfr1
		bcf		Fnmode,0
		call	lcd_clr
		call	loco_lcd		;clear Fn mode
		bra		keyback

setfr1	bsf		Fnmode,0
		bcf		Fnmode,1
		btfsc	Locstat,4		;stop mode?
		bra		keyback
		movlw	0x40			;cursor address
		call	cur_pos
		movlw	HIGH Fr1lbl
		movwf	TBLPTRH    
		movlw	LOW Fr1lbl
		call	lcd_str
        movlw   0x20
        call    lcd_wrt
		bra		keyback

frprog	btfss	Progmode,0
		bra		keyback			;do nothing

		movf	Sermode,W
		incf	WREG
		andlw	B'00000011'
		btfsc	Sermode,2
		bsf		WREG,2
		movwf	Sermode
		movlw	LOW	Ser_md		;rewrite mode
		movwf	EEADR
		movf	Sermode,W
		call	eewrite
		call	newdisp
		bra		keyback

rel_mode 	bcf	Modstat,4		;stop keepalive
		movlw	0x21		;release handle
		movwf	Tx1d0
		movff	Handle,Tx1d1
		movlw	2
		movwf	Dlc
		call	sendTXa
		
relloco 
        movlw	LOW E_hndle		;clear handle in EEPROM
		movwf	Eadr
        movlw   4                      ; fill 4 bytes
        movwf   Ecount
		movlw	0xFF			;no handle and invalid address is 0xFF
		call	eefill
 
		bcf		Locstat,0
		bcf		Locstat,1
		bcf		T0CON,TMR0ON		;stop keepalive	timer interrupts
		call	clr_fun			;clear function table

		bcf		Datmode,0		;packet dealt with
		bcf		RXB0CON,RXFUL

	    btfsc	Dispmode,4		;message displayed?
		bra		main			;yes, so leave displayed and wait for loco key or enter
	
finrel	bcf		Datmode,6		;not busy
		bra		loco

con_mode call	conconv
		sublw	0
		bz		do_con			;OK value
		call	conset			;do again
		bra		keyback



do_con	movlw	0x45
		movwf	Tx1d0			;command set consist
		movff	Handle,Tx1d1
		movff	Conadr,Tx1d2	;consist address
		btfss	Locstat,7		;what is direction
		bsf		Tx1d2,7			;set reverse in consist
		movlw	3
		movwf	Dlc
		call	sendTXa			;send command
		bcf		Locstat,2		;clear consist mode
		bra		rel_mode		;release current loco
con_clr	movlw	0x45
		movwf	Tx1d0			;command clear consist
		movff	Handle,Tx1d1
		movlw	0
		movwf	Tx1d2			;consist address is zero
		movlw	3
		movwf	Dlc
		call	sendTXa			;send command
		bcf		Locstat,5		;clear consist clear mode
		bcf		Locstat,2
		bsf		Locstat,0
		call	lcd_clr
		call	loco_lcd
		bcf		Datmode,6		;not busy
		bra		keyback

fr2		btfsc	Datmode,3		;in device mode?
		bra		keyback
		btfsc	Modstat,7
		goto	keyback
		btfsc	Progmode,4		;service mode?
		bra		frprog2
		btfss	Locstat,0		;any loco?
		bra		keyback
		btfsc	Locstat,6
		bra		keyback
		btfss	Fnmode,1
		bra		setfr2
		bcf		Fnmode,1
		call	lcd_clr
		call	loco_lcd		;clear Fn mode
		bra		keyback

setfr2	bsf		Fnmode,1
		bcf		Fnmode,0
		btfsc	Locstat,4		;stop mode?
		goto	keyback
		movlw	0x40
		call	cur_pos
		movlw	HIGH Fr2lbl
		movwf	TBLPTRH      
		movlw	LOW Fr2lbl
		call	lcd_str
        movlw   0x20
        call    lcd_wrt
		bra		keyback

	
frprog2	btfss	Progmode,0
		bra		keyback			;do nothing

		btg		Sermode,2		;read / write
		movlw	LOW Ser_md
		movwf	EEADR
		movf	Sermode,W
		call	eewrite			;write back service mode
		call	newdisp			;update display
		bra		keyback
		
prog	btfsc	Modstat,7		;in stop mode
		bra		no_prog
		bcf		Sermode,5
		movlw	B'01011001'		;mask dir bit, release bit and consist set bit
		andwf	Locstat,W		;any loco selected?
		bz		setup_mode1		;no
		bsf		Locstat,6
		bsf		Datmode,6		;busy
		call	prog_sub
no_prog		bra		keyback

		
setup_mode1	
		bsf		Progmode,6		;block other activity
		goto setup_mode

number	btfsc	Datmode,6			;busy?
		bra		num1
		btfsc	Datmode,3
		bra		devnum
num1	bsf		Datmode,6			;busy
		btfsc	Sermode,5			;block numbers in service mode
		bra		keyback
		btfss	Locstat,0
		bra		adrnum				;no loco selectd
		btfss	Locstat,6			;program mode
		bra		funct
		btfsc	Locstat,2			;consist?
		bra		funct
		btfsc	Progmode,3			;prog mode get CV val
		bra		cvval
		btfsc	Progmode,0			;prog mode get CV number
		bra		cvnum
	
adrnum	movlw	4
adrnum1	subwf	Numcount,W
		bz		nonum
		movff	Key_temp,POSTINC2	;put number in buffer
		incf	Numcount,F
		movf	Key_temp,W
		addlw	0x30
		movwf	Char			;hold char
		movlw	5
		subwf	FSR2L,F
		movff	Char,INDF2
		addwf	FSR2L
		bsf		LCD_PORT,LCD_RS	;to chars
		movf	Char,W
		call	lcd_wrt
nonum	bra		keyback

devnum	btfss	Datmode,4		;was dev number set
		bra		devnum_a		;no
		bcf		Datmode,4		;change dev. number
		call	devdisp			;clear old number
		clrf	Numcount
		lfsr	FSR2,Dnum1			;reset buffer pointer		

devnum_a	movlw	4
devnum1	subwf	Numcount,W
		bz		nonum
		
;		
		
devnum3		movff	Key_temp,POSTINC2	;put number in buffer

		incf	Numcount,F
		movf	Key_temp,W
		addlw	0x30
		movwf	Char			;hold char
		movlw	6
		subwf	FSR2L,F
		movff	Char,INDF2
		addwf	FSR2L
		bsf		LCD_PORT,LCD_RS	;to chars
		movlw	0x43
		call	cur_pos			;rewrite whole number
		movff	FSR2L,Dncount	;save FSR2
		lfsr	FSR2,Ddr1
		movff	Numcount,Numtemp2
		movff	Numcount,Devcnt
devnum2	movf	POSTINC2,W
		call	lcd_wrt
		decfsz	Numtemp2,F
		bra		devnum2
		movff	Dncount,FSR2L
		bra		keyback

cvnum	movlw	7					;is it address mode read
		subwf	Sermode,W
		bz		nonum				;do nothing

		movlw	4
cvnum1	subwf	Numcount,W
		bz		nonum
		movff	Key_temp,POSTINC2	;put number in buffer
		incf	Numcount,F
		movf	Key_temp,W
		addlw	0x30
		movwf	Char			;hold char
		
		bsf		LCD_PORT,LCD_RS	;to chars
		movf	Char,W
		call	lcd_wrt
keyback1 bra		keyback
		
funct	btfsc	Locstat,1		;release mode?
		bra		keyback
		btfsc	Locstat,2
		bra		con_num
		bsf		Tog_flg,7		;flag a function number for toggle
		movlw	1				;for now. (toggle only)
		call	funsend			;sort out Fn and send
	
		bcf		Datmode,6		;not busy
		bra		keyback

con_num	movlw	3
		subwf	Numcount,W
		bz		nonum
		movff	Key_temp,POSTINC2
		incf	Numcount,F
		movf	Key_temp,W
		bsf		LCD_PORT,LCD_RS	;to chars
		addlw	0x30
		call	lcd_wrt
		bra		nonum

cvval	btfss	Sermode,3		;is it long addres (CV=17)?
		bra		cvval2
		movlw	4
		bra		cvval1
cvval2	movlw	3
cvval1	subwf	Numcount,W
		bz		nonum
		movff	Key_temp,POSTINC2
		incf	Numcount,F
		movff	Numcount,Numcvv		;for display
		movf	Key_temp,W
		bsf		LCD_PORT,LCD_RS	;to chars
		addlw	0x30
		call	lcd_wrt
		bra		nonum

devmode	btfss	Modstat,0		;got CAN ID?

		call	self_en
		movlw	B'00110011'
		movwf	T3CON			;set timer 3 now for A/D update rate
		btfsc	Modstat,7		;in stop mode?
		goto	keyback

		btfss	Datmode,3		;already in dev mode?
		bra		devset
		btfsc	Datmode,4
		bra		devset1
		call	devdisp			;clear existing dev no.for edit


devset	bsf		Datmode,3		;set to dev mode
		btfsc	Datmode,4		;already used in dev mode?
		bra		devset1
		call	devdisp			;display for number
		clrf	Devcnt
		clrf	Numcount
		lfsr	FSR2,Dnum1		;set index for dev numbers
		goto	keyback
devset1 call	devdisp1
		goto	keyback

;	now a subroutine

devout	btfss	Datmode,4		;ready to send?
		return

		movlw	0x98			;set up frame
		movwf	Tx1d0
		btfss	Datmode,5		;polarity?
		bsf		Tx1d0,0			;set to off
		clrf	Tx1d1
		clrf	Tx1d2			;default of 0x0000 so device numbers can be taught
		movff	Dev_hi,Tx1d3
		movff	Dev_lo,Tx1d4
		movlw	5
		movwf	Dlc
		call	sendTXa
		call	beep
		return

		

;	these are because branches were too long

serr1		goto	serr
rd_back1 	goto 	rd_back
reboot1		goto	reboot	


;	Handset setup mode
;
;	Two presses of Prog whilst no loco controlled to get into setup mode
;	This will be a setup menu one day.
;   For now - displays command stdsation version number and then cycles thorugh a test of all message strings
;	as prog is pressed

setup_mode
		btfsc	Progmode,7		;	in speed step seting mode?
		bra		keyback
		btfsc	Setupmode,2		; Are we showing command station version?
		bra		tstdsp			; Yes - continue with test strings
        btfsc   Setupmode,1     ; if already in test mode
        bra		nxtstr			; straight on with next string
        btfsc   Setupmode,0     ; Prog already pressed once?
        bra     setup_start     ; yes - this is second press so now in setup mode
        bsf     Setupmode,0
        bra     keyback

;		Start by showing command station version number (if set)

setup_start
        bsf     Setupmode,1		; Flag for in setup mode
		bsf		Setupmode,2		; flag for showing command station version
		call	lcd_clr	
		movlw	HIGH Cmdstr
		movwf	TBLPTRH    
		movlw	LOW Cmdstr
		call	lcd_str
		call	lcd_cr
		movlw	HIGH Verstr
		movwf	TBLPTRH    
		movlw	LOW Verstr
		call	lcd_str
		movlw	0
		addwf   Cmdmajv,w 	        ; Show major version number
		bz		tstdsp				; if zero, not set so carry on with display string test
		movwf	W_temp
		movlw	.100
		subwf	W_temp,w			; If more than 100, test version so just report version less 100
		bc		scsver				; If less than 100, continue with original number
		movf	W_temp
		movlw	"T"
		call	lcd_wrt

scsver	movf	W_temp,w		
		addlw   0x30                ; Will need to change this when we get to major version 10
        call    lcd_wrt
		movf	Cmdminv,w			; add minor version letter
		call	lcd_wrt
		movlw	0
		addwf   Cmdbld,w 	        ; Show build no. if non zero
		bz		dspdun	   			; if zero, not set so carry on with display string test
		addlw	0x30				; Works up to build 9
		call	lcd_wrt
dspdun	bra		keyback

tstdsp	bcf		Setupmode,2			; Not showing cmd station ver now
		call	lcd_clr	
		movlw	HIGH Testing
		movwf	TBLPTRH           
		movlw	LOW Testing
		call	lcd_str	
		call	lcd_cr


frststr	movlw	HIGH Pmode1 	; point at first string
        movwf	TBLPTRH
		movlw	LOW Pmode1
        movwf   TBLPTRL
		bra		disptst

nxtstr	tblrd*					; get next char in table
skpnul	movf	TABLAT,w
		bnz		nxtdis	
		tblrd+*					; skip over any trailing nulls
		bra		skpnul
		
nxtdis	movlw	HIGH TeststEnd		
		cpfslt	TBLPTRH 		; at end of list?
		bra		chkls           ; check lsbytes of string address
disnxt  call    lcd_clr
        call    lcd_home

disptst	movf    TBLPTRL,w
        call	lcd_str	
		bsf		Setupmode,1	; flag in setup mode
		bra		keyback

chkls   movlw   LOW TeststEnd
        cpfslt  TBLPTRL
        bra     frststr         ; End of list, so go back to beginning
        bra     disnxt


;		here if any CAN frames received			



packet	movlw	0x07			;is it a reset frame
		subwf	RXB0D0,W
		bz		re_set			;system reset
		movlw	0x4C
		subwf	RXB0D0,W
		bz		serr1			;service mode reply (ack or error)	
		movlw	0x85			
		subwf	RXB0D0,W
		bz		rd_back1		;read back of CV in service mode

		movlw	OPC_RQNPN		;read a parameter by index
		subwf	RXB0D0,W
		bz		rdpara

		movlw	OPC_QNN			; Request node info
		subwf	RXB0D0,W
		bnz		chkstat
		call	sndinf			; Send requested info		
		bra		pktdun

chkstat	movlw	OPC_STAT		; Request node info
		subwf	RXB0D0,W
		bnz		chkrb
		call	storinf			; Store command station info		
		bra		pktdun



chkrb	movlw	0x5C			 ;reboot?
		subwf	RXB0D0,W
		bz		reboot1         

		movlw	OPC_RESTP		; Emergency stop all request?
		subwf	RXB0D0,W			
		bz		est_pkt

		movlw	OPC_ESTOP		; Track stopped? (response from command station)
		subwf	RXB0D0,W			
		bz		est_pkt
		movlw	OPC_ERR			; Error now checked for all the time, not just when expecting a PLOC
		subwf	RXB0D0,W
		bnz		othopc
		goto	err				;error

		; These opcodes only apply if we have a session

othopc  btfss	Locstat,0		; Do we have a loco selected?
		bra		hndopc			; No, no need to check these opcodes

		movlw	OPC_DSPD		; Speed/direction
		subwf	RXB0D0,W
		bz		chkdspd

		movlw	OPC_DFNON
		subwf	RXB0D0,W
		bz		chkfun

		movlw	OPC_DFNOF
		subwf	RXB0D0,W
		bz		chkfun

		movlw	OPC_DFUN		; Set functions
		subwf	RXB0D0,W
		bnz		hndopc
	
; If we get a matching function packet (sharing) set our function status to match

chkfun	movf	Handle,w
		subwf	RXB0D1,W			; Does it match our handle?
		bnz		pktdun			; If not, then this packet is not for us; 
        ;  ??? this code will set the function status to match that of the received packet
		bra		pktdun
		
; If we get a matching speed/direction packet (sharing), set direction leds and if speed is 1 then
; display STOP! for emergency stop.  A version of cancab that uses an encoder instead of pot could also set speed here
		         
chkdspd	movf	Handle,w
		subwf	RXB0D1,W			; Does it match our handle?
		bnz		pktdun			; If not, then this packet is not for us
		lfsr	FSR0,RXB0D2		; Point at speed/direction in dspd packet
		call 	setdir			; Set direction flag and led
		movlw	0x7F
		andwf	INDF0,w			; Get speed
		sublw	1				; Is speed 1 (emergency stop?)		
		bnz		pktdun
		bcf		Locstat,4		; So em_sub doesn't think this is a double press
		call 	em_sub			; Emergency stop
		bra		pktdun

hndopc	btfsc	Modstat,1		;request handle response?
		bra		hand_set		;do other frames here
		btfsc	Modstat,2		;handle check?
		bra		hand_set
		bra		hs2				;other packets?


est_pkt call	ems_mod			; Put handset into emergency stop
		call	beep
		call	ldely
		call	beep			; double beep
		btfss	Datmode,6		; busy?
		call	ems_lcd			; Display stop all
		bsf		Modstat,7		; stop all flag 
		bra		pktdun

rdpara	call	thisNN			;read parameter by index (added in rev y)
		sublw	0
		bnz		pktdun
		call	para1rd
		bra		pktdun
	

reboot  call	thisNN				;is it a CAB?
		sublw	0
		bnz		pktdun			;no
		movlw	0xFF
		movwf	EEADR
		movlw	0x3F
		movwf	EEADRH
		movlw	0xFF
		call	eewrite			;set last EEPROM byte to 0xFF
		call	lcd_clr
		call	lcd_home
		movlw	HIGH Firmstr	; Display firmware update message
		movwf	TBLPTRH
		movlw	LOW	Firmstr
		call	lcd_str
		call	lcd_cr
		movlw	HIGH Updstr
		movwf	TBLPTRH
		movlw	LOW	Updstr
		call	lcd_str
		reset					;software reset to bootloader

pktdun	bcf		Datmode,0			; clear packet waiting flag
		bcf		RXB0CON,RXFUL
		goto	main

re_set  bcf	LED_PORT,LED1			;turn off red LED if on.
		clrf	Modstat			;for enumeration
		movlw	LOW E_hndle		;clear handle in EEPROM
		movwf	Eadr
                movlw   4
                movwf   Ecount
		movlw	0xFF
		call	eefill
		setf	Handle
	
re_set3	goto	re_set1a			;reinitialises handset
re_set1g	goto	re_set1			;Reset after handle doesn't match
opdev1		goto	opdev			;device opcode jump
		
hand_set 

		movlw	OPC_PLOC        
		subwf	RXB0D0,W
		bz	set1
hs2		movlw	OPC_ASON  		;check for device command from elsewhere      
		subwf	RXB0D0,W
		bz		opdev1
		movlw	OPC_ASOF        
		subwf	RXB0D0,W
		bz		opdev1
		movlw	OPC_ARSON  		;check for device response from elsewhere      
		subwf	RXB0D0,W
		bz		opdev1
		movlw	OPC_ARSOF        
		subwf	RXB0D0,W
		bz		opdev1

		
		
		bcf	Datmode,0
		bcf		RXB0CON,RXFUL
		goto	main
		
set1    btfss	Modstat,2		;awaiting handle confirmation on walkabout?
		bra		set1a			;no
		movf	Handle,W		; Yes, get handle
		subwf	RXB0D1,W			;handle matches?
		bnz		re_set1g    	; no - reset handset
						
        movf    Adr_hi,w        ; address retrieved from EEPROM
        subwf   RXB0D2,w         ; HIgh byte of address matches?
        bnz     re_set1g        ; no - reset handset

        movf    Adr_lo,w        ; address retreived from EEPROM
        subwf   RXB0D3,w         ; LOw byte of address matches?
        bnz 	re_set1g        ; no - reset handset

		call	adr_chr			;set old address for display
		lfsr	FSR0,RXB0D4		; Point at speed/direction in ploc packet
		call 	setdir			; Set direction flag and led

set2    movff	RXB0D4,Speed1
		bcf	Speed1,7		;clear direction bit

		movlw	LOW Ss_md		;recover SS mode


		movwf	EEADR
		call	eeread
		movwf	Smode
		bsf		Locstat,0			;loco active
		bcf		Progmode,6
	
		call	beep				;confirm 
		bsf		T0CON,TMR0ON		;start keepalive timer interrupt
		bsf		Modstat,4		; keepalive flag
		movlw	B'00110011'
		movwf	T3CON			;set timer 3 now for A/D update rate
		call	spd_chr				;speed to chars for display

		btfss	Datmode,3		;dev. mode?
		call	clr_bot			;clear bottom row
		call	loco_lcd
		bcf		Modstat,2		;out of confirmation mode
		bcf		Modstat,1		;has valid handle
		movlw	1
		subwf	Speed1,W		;is it em.stop speed?
		bz		set1c			;yes
		bra		set1b			;no
set1c	call	em_sub
		bra		set1b		
		
set1a   movff	RXB0D1,Handle		;put in handle
		movff	RXB0D5,Fr1		;reinstate functions
		movff	RXB0D6,Fr2
		movff	RXB0D7,Fr3
		movff	RXB0D2,Adr_hi
		movff	RXB0D3,Adr_lo

		call	adr_chr				;put new address into ASCII for display
        call    store_funcs             ; Store functions status in EEPROM
		movlw	LOW E_hndle
		movwf	EEADR
		movf	RXB0D1,W
        call    eewrite
        incf    EEADR
		incf	EEADR
        movf    Adr_hi,w
		call	eewrite
        incf    EEADR
        movf    Adr_lo,w
        call    eewrite
		bcf		Modstat,1
		call	ss_send	
		movf	RXB0D4,w				; Get speed
		andlw	0x7F
		btfss	ENC_PORT,ENC
		bra		setspd

		call	adc_zero			; If so, wait for knob to be zero (not with encoder)
        movlw   0                   ; Set current speed to zero

setspd  				; Set speed to current loco speed
		movwf	Speed1
		movf	WREG
		bz		setsp1				;is speed 0?
		decf	WREG				;no so decrement
setsp1	movwf	Speed
		lfsr	FSR0,RXB0D4			; Point at speed/direction in ploc packet
		call	setdir				; Set direction
		call	spd_chr				;speed to chars for display

		call	clr_top				;clear top line
		btfss	Datmode,3
		call	clr_bot				;if dev mode not set
		call	loco_lcd
		bsf	    Locstat,0

set1b   bsf		Modstat,4
		bsf		T0CON,TMR0ON				;start keepalive timer
		bcf		Datmode,0
		bcf		RXB0CON,RXFUL
        call    spd_pkt                     ; Send 1 speed packet at take over
		goto	main		


;  Set direction flag and LED based on dirction from byte pointed to by FSR0

setdir  btfsc   INDF0,7
		bra		set_fwd
		bcf		Locstat,7			;clear direction bit
		bcf		LED_PORT,LED2				;set LED
		bsf		LED_PORT,LED1
		bra		dirret
set_fwd         bsf		Locstat,7
		bcf		LED_PORT,LED1
		bsf		LED_PORT,LED2		
dirret	return
                


; Handle error opcode
		

err 	movlw	ERR_SESSION_NOT_PRESENT
		subwf	RXB0D3,W				; No session error?
		bz		err_3

		movlw	ERR_SESSION_CANCELLED
		subwf	RXB0D3,W				; Session cancelled error?
		bz		err_3		

        ; These errrors are only valid if we are waiting for a handle on loco select

        btfss   Modstat,1
        bra     errdun

        ; First check if loco address matches the one we are waiting for - if not then the error is not for us

        movf	Adr_hi,W			
    	subwf	RXB0D1,W				;is the address we are waiting for?
    	bnz		errdun				;not this
    	movf	Adr_lo,W
    	subwf	RXB0D2,W
    	bnz		errdun				;not this

        ; It is the address we are waiting for, so deal with the error code

		movlw	ERR_LOCO_STACK_FULL  
		subwf	RXB0D3,W
		bz		err_1
		movlw	ERR_LOCO_ADDR_TAKEN
		subwf	RXB0D3,W
		bz		err_2
		bra		errother               ; some other error on this address

        ; STACK FULL ERROR

err_1	call	loc_adr				;loco number on top line
		movlw	LOW Str_ful			;"FULL"
		bra		errnosel

        ; LOCO TAKEN ERROR

err_2	bsf		Dispmode, 2			; Flag for waiting at "Taken" message
		bsf		Datmode, 6			; Set busy flag so does not try to go into accessory mode
		call	loc_adr
		movlw	LOW Str_tkn			;"TAKEN"
        bra     errnosel        

errother call   loc_adr
         movlw  LOW Err

        ; Loco select failed, beep, display error message and resume waiting for entry from keypad
errnosel
		call	lcd_str
		call	beep

    	bcf		Modstat,1
		bcf		Modstat,4			
		bcf		Locstat,0
		bcf		Datmode,0
		bcf		RXB0CON,RXFUL
		goto	main


; Session not present error
    
err_3	movf	Handle,w
		subwf	RXB0D1,W				; Does it match our handle?
		bnz		errdun				; If not, then this error is not for us

        btfsc	Modstat,2			; Are we waiting for handle confirmation on walkabout?
		bra		re_set1             ; If so, then session is not present 
        btfss	Locstat,0			; Do we have a loco selected?
		bra		errdun				; No, not for us then
		
;		Display session lost or cancelled message

		call	lcd_clr
		movlw	HIGH Sessionstr		; Session message on top line
		movwf	TBLPTRH
		movlw	LOW Sessionstr	
		call	lcd_str
		call 	lcd_cr

		movlw	ERR_SESSION_CANCELLED
		subwf	RXB0D3,W				; Session cancelled error?
		bz		cnmsg

		movlw	HIGH Loststr		; Lost message on bottom line
		movwf	TBLPTRH
		movlw	LOW Loststr			
		bra		errmsg



cnmsg	movlw	HIGH Cancelstr		; Cancelled message on bottom line
		movwf	TBLPTRH
		movlw	LOW Cancelstr			

errmsg	call	lcd_str
		bsf		Dispmode,4			; Error message displayed
		bsf		Datmode,6			; Busy flag
		bcf		Modstat,4			; Matches our active session , so stop keepalive
		bra		relloco				; then must release loco

; Service mode error handling

serr	movf	Handle,W			;check handle is for this cab.
		subwf	RXB0D1,W
		bnz		serr_4				
		btfss	Sermode,4			;is it expecting an error /ack
		bra		serr_4
		movf	RXB0D2,W
		movwf	Err_tmp
		bz		serr_4				;no error 0
		sublw	3					;ACK
		bnz		serr_1
		btfss	Sermode,3			;multiple writes
		bra		serr_1				;no
		btfsc	Sermode,7			;last one or CV29
		bra		serr_2
		call	wrtlng1				;send CV18
		bra		errdun1
serr_2	btfsc	Sermode,6
		bra		serr_3
		call	wrtlng2
		bra		errdun1
serr_3	call	subOK				;multiple writes OK	
		bra		serr_4			;
		
serr_1	call	err_msg
		movf	WREG,W
		bz		serr_4				;error or end
		bra		errdun				;leave in multiple writes
serr_4	
		bcf		Sermode,3			;out of long address
		bcf		Sermode,6			;out of multiple writes
		bcf		Sermode,7
errdun	bcf		Sermode,4
errdun1	bcf		Datmode,0
		bcf		RXB0CON,RXFUL
    	goto	main

prog_mode	btfsc	Progmode,2		;is it CV value entry now?
		bra		prog2
		btfsc	Progmode,1			;is it long address
		bra		longadr
		btfsc	Progmode,3			;is it send CV
		bra		sendCV
		btfsc	Progmode,0
		bra		adr_rd
prg2	bcf		Progmode,0
		bsf		Progmode,2			;set for CV value entry
	
		call	cvaconv				;convert CVnumber to HEX bytes and check		
		
prog_er1 sublw	0
		bnz		prog_err
		movlw	.17
		subwf	CVnum_lo,W			;is it long address service mode prog.?
		bz		lng_prg
		bcf		Sermode,3			;not long
		goto	main
lng_prg	movlw	B'00111111'
		andwf	Sermode,F
		bsf		Sermode,3			;flag long address
	
		goto	main
		
adr_rd	movlw	7
		subwf	Sermode,W
		bnz		prg2				;is it read address?
		
		call	read_adr
		bra		prog_er1

prog_err movlw	B'00010000'			;clear all except service flag	
		andwf	Progmode,F
		bcf		Sermode,3			;out of long address mode if set
		call	beep
		call	prog_sub
		goto	keyback
prog2	call	prog_3
		goto	keyback
sendCV	btfss	Sermode,3			;long address?
		bra		sendCV1
		call	adrconv
		bra		sendCV2
sendCV1	call	cvv_conv
sendCV2	sublw	0
		bnz		prog_err
		movf	CVnum_hi,F			;check for CV1
		bnz		sendCV3				;hi byte is not 0
		movlw	1
		subwf	CVnum_lo,W			;is it 1?
		bnz		sendCV3				;no
		btfss	CVval,7				;more than 127?
		bra		sendCV3				;no so do it
		bra		prog_err			;error

sendCV3	btfsc	Progmode,4
		bra		ser_prog			;service mode program
		call	cv_send				;OTM prog
		clrf	Progmode
		bcf		Locstat,6			;out of prog mode
		call	lcd_clr
		call	loco_lcd
		bsf		Locstat,0			;re-enable loco
		bcf		Datmode,6			;not busy
		goto	keyback
prg_err1 call	beep
		bcf		Progmode,3
		bra		prog2

ser_prog call	cv_wrt
		goto	keyback	

longadr	call	lng_conv			;convert long address to HEX (OTM prog)
		sublw	0
		bnz		l_err				;error
		movlw	0x82
		movwf	Tx1d0				;set up for CV17
		movff	Handle,Tx1d1
		clrf	Tx1d2				;CV hi byte is 00
		movlw	0x11
		movwf	Tx1d3				;CV lo byte is 0x11
		movff	L_adr_hi,Tx1d4
		bsf		Tx1d4,6
		bsf		Tx1d4,7
		movlw	5
		movwf	Dlc	
		call	sendTXa
		call	ldely				;wait till sent by CS
		movlw	0x12
		movwf	Tx1d3				;CV lo byte is 0x12
		movff	L_adr_lo,Tx1d4

		call	sendTXa
		call	ldely				;wait till sent by CS

		movlw	0x83
		movwf	Tx1d0				;program bit in CV29
		movlw	0x1D				;CV 29
		movwf	Tx1d3
		movlw	0xFD
		movwf	Tx1d4
		call	sendTXa
		call	ldely				;wait till sent by CS

		movlw	0x21				;release loco on old address
		movwf	Tx1d0
		movf	Handle,W			;get handle
		movwf	Tx1d1
		movlw	2
		movwf	Dlc
		call	sendTXa
		bcf		Locstat,0			;no loco selected

		movlw	OPC_RLOC			;RLOC
		movwf	Tx1d0
		movff	L_adr_hi,Tx1d1
		bsf		Tx1d1,6
		bsf		Tx1d1,7
		movff	L_adr_lo,Tx1d2
		movlw	3
		movwf	Dlc
		bsf		Modstat,1			;for answer
		call	sendTXa				;request new loco
	
		clrf	Progmode
		bcf		Locstat,6			;out of prog mode
		bcf		Datmode,6			;not busy

		goto	keyback
l_err	bcf		Progmode,2
		nop							;needs changing here?
		goto	keyback

rd_back	btfsc	Sermode,3			;long address read sequence?
		bra		rd_long
		call	cv_ans				;cv answer
		bcf		Datmode,0
		bcf		RXB0CON,RXFUL
		goto	keyback				;?
rd_long	movlw	B'11000000'
		andwf	Sermode,W
		bnz		rd_lng2				;check if to test for long bit in CV29
		btfsc	RXB0D4,5				;is it in long address mode?
		bra		rd_lng1				;yes
		bcf		Sermode,3			;out of long
		call	read_disp
		bcf		Sermode,4			;not waiting
		movlw	.17
		movwf	CVnum_lo
		call	cv_read1			;read just CV17
		bcf		Datmode,0			;done frame
		bcf		RXB0CON,RXFUL	
		goto	keyback
rd_lng1 call	lcd_clr				;put up long address message
		movlw	HIGH Progstr2
		movwf	TBLPTRH
		movlw	LOW Progstr2
		call	lcd_str
		call	lcd_cr
		bsf		LCD_PORT,LCD_RS
		movlw	"="
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		bsf		Sermode,6
		movlw	.17
		movwf	CVnum_lo
		bcf		Datmode,0			;done frame
		bcf		RXB0CON,RXFUL
		bcf		Sermode,4			;not waiting
		call	cv_read1			;read just CV17
		goto	keyback

rd_lng2 btfsc	Sermode,7			;which address byte
		bra		rd_lng3				;second address byte
		movff	RXB0D4,CVtemp		;save high byte
		movlw	.18
		movwf	CVnum_lo
		bcf		Datmode,0			;done frame
		bcf		RXB0CON,RXFUL
		bcf		Sermode,4			;not waiting
		bsf		Sermode,7			;for CV18
		call	cv_read1			;read just CV18
		bcf		Datmode,0			;done frame
		bcf		RXB0CON,RXFUL
		goto	keyback

rd_lng3	movff	RXB0D4,CVtemp1
		call	cv_ans_l			;long answer

		bcf		Datmode,0
		bcf		RXB0CON,RXFUL
		goto	keyback
		
;here if a device opcode so check if this CAB also has it.		

opdev	btfss	Datmode,4			;has a DN?
		bra		nopdev
		movf	RXB0D3,W
		subwf	Dev_hi,W
		bnz		nopdev				;no match
		movf	RXB0D4,W
		subwf	Dev_lo,W			
		bnz		nopdev				;no match
		btfss	Datmode,7			;is it waiting for a response?
		bra		op_cont				;no or timed out
		btfsc	RXB0D0,2
		bra		op_on2				;response events
op_cont	btfsc	RXB0D0,0				;is it ON?
		bra		op_off
		bcf		Datmode,5			;set for  on
		bra		opdisp				;update display
op_off	bsf		Datmode,5			;set for  off
		bra		opdisp

op_on2	bcf		T1CON,TMR1ON		;stop timer
		btfsc	RXB0D0,1			;response state  (0x9D, 0x9E)
		bra		op_off2
		bcf		Datmode,5			;on
		bra		opdisp
op_off2	bsf		Datmode,5

opdisp	
		btfss	Datmode,3			;update display?
		bra		nopdev				;not in acc mode on display
		movlw	0x47
		call	cur_pos
		movlw	"+"
		btfsc	Datmode,5
		bra		minus
		call	lcd_wrt
		bra		opdate
minus	movlw	"-"
		call	lcd_wrt
opdate	movlw	LOW	Dat_save		;update EEPROM
		movwf	EEADR
		movf	Datmode,W
		bcf		WREG,0
		call	eewrite
		btfsc	Datmode,7			;toggle button?
		goto	devtg_1				;do toggle

nopdev	bcf		Datmode,0			
		bcf		RXB0CON,RXFUL
		goto	keyback	



;***************************************************************************
;		main setup routine
;*************************************************************************

setup	clrwdt
		clrf	INTCON			;no interrupts yet
		movlb	.15
		clrf	WREG			;ANCON0 = 0
		btfsc	ENC_PORT,ENC
		movlw	B'00000001'		;for pot input
		movwf	ANCON0
		clrf	ANCON1
	
		clrf	CM1CON			;disable comparator
		clrf	CM2CON
		clrf	T3GCON			;disable T3 gate control
		clrf	INTCON2			
		bcf		INTCON2,7		;weak pullups on
		setf	WPUB			;all pullups on
		movlb	0

		movlw	B'00101110'		;Port A for encoder/pot select on PA5.								
		movwf	TRISA			;
		nop
		nop

;	This is for a pot.

		movf	ENC_PORT,W

		btfss	WREG,ENC		;is it an encoder
		bra		pset2			;yes

		movlw	B'00000001'		;A/D enabled. Channel 0
		movwf	ADCON0			;
		movlw	B'00000000'		;A/D on PORTA,0, rest are digital
		movwf	ADCON1
		movlw	B'00111110'		;set sampling rate
		movwf	ADCON2
		bsf		TRISA,0			;A/D input for pot
		bra		pset1

pset2	
		movlw	B'00000110'		
		andwf	ENC_PORT,W		;read PORTA for encoder 
		movwf	Atemp
		clrf	Enc_stat		;encoder state
	
		
		;port settings will be hardware dependent. RB2 and RB3 are for CAN.
		;set S_PORT and S_BIT to correspond to port used for setup.
		;rest are hardware options
		
pset1	
		clrf	KEY_PORT
	
		movlw	B'00111011'		;RB0 RB1 keypad rows 1 and 2
								;RB2 = CANTX, RB3 = CANRX, 
								;RB4 RB5 are keypad rows 3 and 4
		movwf	TRISB
		clrf	PORTB
		bsf		PORTB,2			;CAN recessive
		movlw	B'00000000'		;Port C  column drive and LCD drive. RC2 is sounder output (PWM)
		movwf	TRISC
		clrf	PORTC
		lfsr	FSR0, 0			; clear page 1
		
nextram	clrf	POSTINC0
		tstfsz	FSR0L
		bra		nextram	

		setf	NN_temph		;provisional NN for all CABs is FFFF
		setf	NN_templ
		setf	Handle			;?

		clrf	CCP1CON
		movlw	B'00000011'
		movwf	T2CON			;st T2 for beep
		movlw	0x9F
		movwf	PR2

		
		movlw	4
		movwf	Deb4			;for debounce counter

		
		
		movlw	LOW	Ser_md		;
		movwf	EEADR
		movlw	0
		call	eewrite			;default service mode
		clrf	Sermode	
	
	
		
;	next segment is essential.
		
		bsf		RCON,IPEN		;enable interrupt priority levels
		clrf	BSR				;set to bank 0
		clrf	EECON1			;no accesses to program memory	
		clrf	Lat0count
        clrf    Lat1count

		clrf	COMSTAT			;clear any errors
				 
		bsf		CANCON,ABAT		;abort any waiting frames	
		
		bsf		CANCON,7		;CAN to config mode
		movlw	B'10110000'
		movwf	ECANCON	
		bsf		ECANCON,5		;CAN mode 2 
		movf	ECANCON,W
		movwf	TempECAN 

		movlb	.14
		clrf	BSEL0			;8 frame FIFO. Used in ECAN
		clrf	RXB0CON
		clrf	RXB1CON
		clrf	B0CON			;clear buffer
		clrf	B1CON
		clrf	B2CON
		clrf	B3CON
		clrf	B4CON
		clrf	B5CON
		
			
		movlw	CAN_BRGCON1		;set CAN bit rate at 125000 
		movwf	BRGCON1
		movlw	B'10011110'		;set phase 1 etc
		movwf	BRGCON2
		movlw	B'00000011'		;set phase 2 etc
		movwf	BRGCON3
		movlb	0


		movlw	B'00100000'
		movwf	CIOCON			;CAN to high when off
		movlw	B'00100100'		;B'00100100'
		movwf	RXB0CON			;enable double buffer of RX0

;*******
		movlb	.15
		movlw	B'00100100'		;reject extended frames
		movwf	RXB1CON
		clrf	RXF0SIDL
		clrf	RXF1SIDL
		movlb	0


		
mskload	lfsr	0,RXM0SIDH		;Clear masks, point to start
mskloop	clrf	POSTINC0		
		movlw	LOW RXM1EIDL+1		;end of masks
		cpfseq	FSR0L
		bra		mskloop
		
		clrf	CANCON			;out of CAN setup mode
	
	
	
		movlw	B'00100000'
		movwf	IPR5			;high priority CAN  Tx error interrupts(for now)
		clrf	IPR1			;all peripheral interrupts are low priority
		clrf	IPR2
		clrf	PIE2



;next segment required
		
		
		
		clrf	INTCON2			;Weak pullups on PORTB
		clrf	INTCON3			;
		clrf	T3GCON

		movlw	B'00100000'		;Tx error interrupt only
								
		movwf	PIE5			;
	
		clrf	PIR1
		clrf	PIR2
		clrf	PIR3			;clear all flags
		clrf	PIR4
		clrf	PIR5
		clrf	EEADRH			;upper EEPROM page to 0
		clrf	Modstat
		bcf		RXB0CON,RXFUL	;enable RX0 buffer
		movlb	.15
		bcf		TXB1CON,TXREQ	;abort any waiting CAN frame
		bcf		TXB0CON,TXREQ
		bcf		TXB2CON,TXREQ
		movlb	0

;set up LCD
		clrwdt
		bcf		LCD_PORT,LCD_RS	;control register
		movlw	B'00110011'		;reset and 4 bit mode
		call	lcd_wrt
		movlw	B'00110010'		;reset and 4 bit mode sequence
		call	lcd_wrt
		movlw	B'00101000'		;SW extra reset and 4 bit mode sequence required for winstar display
		call	lcd_wrt
		movlw	B'00101000'		;2 lines, 5x7 dots
		call	lcd_wrt
		movlw	B'00000110'		;Cursor left to right, don't shift display
		call	lcd_wrt
		movlw	B'00001100'		;Display on, cursor off, blink at cursor off
		call	lcd_wrt
		movlw	B'00000001'		;clear display, start at DD address 0
		call	lcd_wrt
		call	ldely			;wait for screen clear


; Download custom characters to LCD CG RAM
		clrwdt
		movlw	B'01000000'		; Set CG RAM address 0
		movwf	Temp1			; Save Initial CG RAM address
		movlw	HIGH Custchars	; Set up table pointer for character data to load
		movwf	TBLPTRH          
		movlw	LOW Custchars
		movwf	TBLPTRL

loadCG	bcf		LCD_PORT,LCD_RS	; LCD into command mode
		movf	Temp1,w			; Get CG RAM address
		call	lcd_wrt			; Set CG RAM address in LCD

		bsf		LCD_PORT,LCD_RS	; LCD into data mode
		tblrd*+					; get next row of pixels
		movf	TABLAT,W
		call	lcd_wrt
		incf	Temp1,F			; next address
		movlw	LOW Custend
		cpfseq	TBLPTRL			; All loaded?
		bra		loadCG
		
		bcf 	LCD_PORT,LCD_RS	; LCD into command mode
		movlw	B'10000000'		; Back to Data display RAM mode, address 0
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS	; LCD ready to accept display characters

		movlw	8				;reload device address and Datmode
		movwf	Count
		lfsr	FSR0,Datmode
		movlw	LOW	Dat_save
		movwf	EEADR
devld	call	eeread
		movwf	POSTINC0
		incf	EEADR
		decfsz	Count
		bra		devld
		movlw	B'00111000'		;clear all except device bits in Datmode
		andwf	Datmode,F
		

;clear variables



re_set1a	clrf	Tx1con		;make sure Tx1con is clear
		movlw	B'00000001'
		movwf	IDcount			;set at lowest value for starters
		clrf	Locstat
		clrf	Progmode
		clrf	Modstat			;re enumerate on enter
		clrf	Sermode
		clrf	Setupmode
		clrf	Dispmode
		lfsr	FSR2,Num1			;reset pointer
		clrf	Numcount
		clrf	Enc_stat		;encoder status
		clrf	Enc_sw
		movlw	" "
		movwf	Adr1
		movwf	Adr2
		movwf	Adr3
		movwf	Adr4

        lfsr    FSR0,Cmdmajv
        movlw   LOW Lastloco+1
clrstat clrf    POSTINC0        ; clear accessory status bytes and cmd stn ver info
        cpfseq  FSR0L
      	bra     clrstat


		clrf	Smode			;default is 128 SS
		movlw	0x07
		subwf	RXB0D0,W			;is it a reset command
		bz		re_set1b		;always a hard reset

		bcf		KEY_PORT,7			;for hard reset test. Is the Prog button in?
		nop
		btfsc	KEY_PORT,5			;clear if in
		bra		re_set4

re_set1b
		call	lcd_clr
		call	lcd_home
		bsf		LCD_PORT,LCD_RS	
		movlw	HIGH Res_str
		movwf	TBLPTRH      	
		movlw	LOW Res_str			;
		call	lcd_str
progup	call	dely		;wait for reset release
		btfss	PORTB,5
		bra		progup
		call	lcd_clr
		call	lcd_home
		bsf		KEY_PORT,7

		movlw	LOW E_hndle		;clear handle
		movwf	Eadr
        movlw   4
        movwf   Ecount
		movlw	0xFF
		call	eefill
		setf	Handle
		bcf		Datmode,0
		bcf		RXB0CON,RXFUL
		bra		re_set1			;hard reset
		

;		test for walkaround
;		is handle already in the CS?

re_set4	bsf		KEY_PORT,7
		bcf		KEY_PORT,5			;is consist in?
		nop
		btfsc	PORTB,0
		bra	re_set4a
		call	res_fun			;reset all mom keys
re_set4a	bsf	KEY_PORT,5
		movlw	LOW E_hndle
		movwf	EEADR
		call	eeread			;is handle already set?
		movwf	W_temp
		addlw	1			;was 0xFF?
		bz	re_set1			;CAB doesn't have a handle so hard reset

;		here if handle is set in EEPROM
		
		movff	W_temp,Handle           ; keep handle to check against PLOC
        movlw   LOW E_addr              ; Get saved address to check against PLOC
        movwf   EEADR
        call    eeread
        movwf   Adr_hi
        incf    EEADR
        call    eeread
        movwf   Adr_lo

		call	newid1			;reinstate CANid to RAM etc. (current CANid in EEPROM)
		clrf	Modstat
		bsf		Modstat,0		;has got CAN_ID
		movlw	B'11100000'
		clrf	PIR5
		movwf	INTCON			;enable interrupts

		bsf		Modstat,2		;set flag for handle confirm
		clrf	Locstat			;no loco selected
		bsf		Locstat,7		;default to forward		
		movlw	0x22			;query engine (QLOC)
		movwf	Tx1d0
		movff	Handle,Tx1d1
		movlw	2
		movwf	Dlc			
	
		call	sendTXa

		
		btfss	Datmode,4		;has dev. no set
		bra		re_set2
		call	devdisp1		;put up old dev. display
		

		bra		re_set2			;continue
		

re_set1	clrf	INTCON
		setf	Handle
		movlw	8					;clear device address and Datmode
		movwf	Count
		movlw	LOW	Dat_save
		movwf	EEADR
		lfsr	FSR0,Datmode
		
re_st1	clrf	WREG
		call	eewrite
		incf	EEADR
		clrf	POSTINC0
		decfsz	Count
		bra		re_st1
		call	clr_fun					;clear function table
		
		
		bsf		Locstat,7				;set to forward
		clrf	Modstat
		call	lcd_clr
		bsf		LCD_PORT,LCD_RS
		movlw	HIGH Titlstr
		movwf	TBLPTRH      
		movlw	LOW Titlstr
		call	lcd_str
		call	lcd_cr
		bsf		LCD_PORT,LCD_RS
		movlw	HIGH Verstr
		movwf	TBLPTRH    
		movlw	LOW Verstr
		call	lcd_str
        movlw   MAJOR_VER           ; Show major version number
        addlw   0x30                ; Will need to change this when we get to major version 10
        call    lcd_wrt
		movlw	MINOR_VER			; add minor version letter
		call	lcd_wrt

; This bit is for developer test versions only.
; It displays the build number in the lcd display 
; so we can confirm the new version has been loaded or bootloaded

#if BETA_VER != 0
		movlw	BETA_VER
		addlw	0x30
		call	lcd_wrt
#endif


		bsf	Modstat,6		; Flag for title display delay
		bsf		LED_PORT,LED2			;fwd LED for now as test

re_set2	clrf	Fnmode				;holds function range
		clrf	Fr1					;function bits  0 to 4
		clrf	Fr2					;function bits  5 to 8
		clrf	Fr3					;function bits  9 to 12
		clrf	Fr4					;function bits  13 to 20
		clrf	Fr5					;function bits  21 to 28
		clrf	Tog_flg				;function toggle or momentary

		
		clrf	Numcount			;for numeric input
		clrf	Conadr				;consist address
		clrf	Speed
		clrf	Keyflag
		clrf	TMR0H
		clrf	TMR0L

		movlw	B'10000111'		;set Timer 0 for keepalive, enable now for title delay
		movwf	T0CON
		clrf	PIR5
		bcf		INTCON,TMR0IF
		movlw	4
		movwf	T0count			;4 cycles needed now
		movlw	B'01111111'
		movwf	T4CON			;set timer 4 for encoder rate. Free running. PIR4,TMR4IF every 4.096 mSec
		movlw	B'00110011'
		movwf	T3CON			;set timer 3 now for A/D update rate (moved here so can detect knob move before a loco selected in case of recover from emergency stop all
		movlw	B'11100000'		;reenable interrupts
		movwf	INTCON			;enable interrupts
;		bcf		Datmode,0
		goto	main

		; Disply loco prompt after title delay

clear_title 
		call	locprmpt	;prompt for loco
		bcf		Modstat,6		; Clear flag that title is displayed

		return

locprmpt
		call	lcd_clr				;clear screen
		call	ldely				;wait for clear
		bsf		LCD_PORT,LCD_RS		;data reg
		movlw	HIGH Selstr			;get string
		movwf	TBLPTRH      	
		movlw	LOW Selstr			;
		call	lcd_str
		call	lcd_cr
		bsf		LCD_PORT,LCD_RS
		movlw	"="
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt

		return





		
;****************************************************************************
;		start of subroutines		
;********************************************************************************
;		main routine to send CAN frame

;	Now semi-reentrant (ie: can be safely be used by main loop and lpint) by using separate transmit buffer
;	in RAM and separate CAN TX buffer


; Send TXa entry point is used when called from the main program

sendTXa         lfsr	FSR0, Tx1con
		lfsr	FSR1, TXB1CON
		movff	Dlc, Tx1dlc
                movlw   .10
                movwf   Lat1count
		bra		sendTX

; Send TXi entry point is used when called from the LP ISR - Tx0dlc loaded by caller

sendTXi lfsr	FSR0, Tx0con
		lfsr	FSR1, TXB0CON
        movlw   .10
        movwf   Lat0count

sendTX  clrf	INDF0			; Tx?con		;prevents false send if TXREQ is set by mistake

		movlw	B'00001111'		;clear old priority
		andwf	PREINC0,F		; Tx?sidh
		movlw	B'10110000'
		iorwf	INDF0			; Tx?sidh			;low priority
		decf	FSR0L
		call	sendTX1			;send frame
		return				


;		Send contents of Tx1 buffer via CAN TXB1

sendTX1	

		clrf	COMSTAT

tx1test	clrwdt
		btfsc	INDF1,TXREQ		; TXB?CON
		bra		tx1test
		movf	FSR0L,w
		addlw	.14				; limit for tx buffer size
ldTX1	movff	POSTINC0,POSTINC1
		cpfseq	FSR0L
		bra		ldTX1

	
			
		movlw	.14				; bank 14
		subwf	FSR1L			; put pointer back
		movlw	2
		bcf		PLUSW1,EXIDE	; TXB?CON  test for a fault?
		movlw	B'00001011'		;send - high priority
		movwf	INDF1			; TXB?CON
tx1done btfsc	INDF1,TXREQ		; TXB?CON check if sent
		bra		tx1done

		return					;successful send

		

;**********************************************************************

;		self enumeration as separate subroutine

self_en	movff	FSR1L,Fsr_tmp1Le	;save FSR1 just in case
		movff	FSR1H,Fsr_tmp1He 
		bsf		Datmode,1			;set to 'setup' mode
		movlw	.14
		movwf	Count
		lfsr	FSR0, Enum0			;clear enum buffer
clr_en
		clrf	POSTINC0
		decfsz	Count
		bra		clr_en
		bcf		PIE2,TMR3IE		;disable interrupts for self-en
		bcf		PIR2,TMR3IF
		movlw	4				;x4 count at 16 MHz
		movwf	T3count
		movlw	B'00110010'		;B'00110000'
		movwf	T3CON
		clrf	TMR3H
		clrf	TMR3L
		bsf		T3CON,TMR3ON	;enable timer 3 for CAN_ID wait.
		
		
		movlb	.15
		movlw	B'10111111'		;fixed node, default ID  
		movwf	TXB1SIDH
		movlw	B'11100000'
		movwf	TXB1SIDL
		movlw	B'01000000'		;Send RTR frame
		movwf	TXB1DLC
rtr_snd	btfsc	TXB1CON,TXREQ
		bra		rtr_snd
		bsf		TXB1CON,TXREQ
rtr_go	btfsc	TXB1CON,TXREQ		;wait till sent
		bra		rtr_go
		clrf	TXB1DLC				;no more RTR frames
		movlb	0
		
	

	
		
	

self_en1	btfsc	PIR2,TMR3IF		;setup timer out?
		bra		en_done
		btfsc	COMSTAT,7		;no so look for CAN input. (zero data frames from other modules)
		bra		getcan1
		bra		self_en1		;no CAN
	

getcan1	movf	CANCON,W			;get zero data frame.
		andlw	B'00001111'
		movwf	TempCANCON
		movf	ECANCON,W
		andlw	B'11110000'
		iorwf	TempCANCON,W
		movwf	ECANCON
		btfsc	RXB0SIDL,EXID		;ignore extended frames here
		bra		no_can1
		
		
en_1	btfss	Datmode,1			;setup mode?
		bra		no_can1
		movf	RXB0DLC,F
		bnz		no_can1				;only zero length frames
		call	setmode				;sort out incoming ID
		bra		no_can1	

no_can1	bcf		RXB0CON,RXFUL
		bra		self_en1			;loop till timer out 

en_done	bcf		PIR2,TMR3IF		;clear flag
		decfsz	T3count			;done if zero
		bra		self_en1
		movlw	4
		movwf	T3count			;for next time (may not be needed)
		bcf		T3CON,TMR3ON	;timer off
			


		clrf	IDcount
		incf	IDcount,F			;ID starts at 1
		clrf	Roll
		bsf		Roll,0
		lfsr	FSR1,Enum0			;set FSR to start
here1	incf	INDF1,W				;find a space
		bnz		here
		movlw	8
		addwf	IDcount,F
		incf	FSR1L
		bra		here1
here	movf	Roll,W
		andwf	INDF1,W
		bz		here2
		rlcf	Roll,F
		incf	IDcount,F
		bra		here
here2	movlw	.100				;limit to ID
		cpfslt	IDcount
		call	segful				;segment full
		
here3	movlw	LOW CANid		;put new ID in EEPROM
		movwf	EEADR
		movf	IDcount,W
		call	eewrite
		movf	IDcount,W
		call	newid1			;put new ID in various buffers

			
		movff	Fsr_tmp1Le,FSR1L	;
		movff	Fsr_tmp1He,FSR1H 
		return	0					



;;****************************************************************
;	Sort out incoming CAN_ID
;
setmode	tstfsz	RXB0DLC
		return				;only zero length frames for setup
		
		swapf	RXB0SIDH,W			;get ID into one byte
		rrcf	WREG
		andlw	B'01111000'			;mask
		movwf	Temp
		swapf	RXB0SIDL,W
		rrncf	WREG
		andlw	B'00000111'
		iorwf	Temp,W
		movwf	IDcount				;has current incoming CAN_ID

		lfsr	FSR1,Enum0			;set enum to table
enum_st	clrf	Roll				;start of enum sequence
		bsf		Roll,0
		movlw	8
enum_1	cpfsgt	IDcount
		bra		enum_2
		subwf	IDcount,F			;subtract 8
		incf	FSR1L				;next table byte
		bra		enum_1
enum_2	dcfsnz	IDcount,F
		bra		enum_3
		rlncf	Roll,F
		bra		enum_2
enum_3	movf	Roll,W
		iorwf	INDF1,F
		bcf		RXB0CON,RXFUL		;clear read
		return

;**********************************************************

;		put new CAN_ID in relevant places

		

newid1	movlw	LOW CANid			;put in stored ID
		movwf	EEADR
		bsf		EECON1,RD
		movf	EEDATA,W
		movwf	CanID_tmp			
		call	shuffle
		movlw	B'11110000'
		andwf	Tx1sidh,F
		andwf	Tx0sidh,F		;for keepalive buffer
		movf	IDtemph,W		;set current ID into CAN buffer
		iorwf	Tx1sidh,F		;leave priority bits alone
		iorwf	Tx0sidh,F
		movf	IDtempl,W
		movwf	Tx1sidl			;only top three bits used
		movwf	Tx0sidl
		
		
		movlb	.15				;put ID into TXB2 for enumeration response to RTR
		bcf		TXB2CON,TXREQ
		clrf	TXB2SIDH
		movf	IDtemph,W
		movwf	TXB2SIDH
		movf	IDtempl,W
		movwf	TXB2SIDL
		movlw	0xB0
		iorwf	TXB2SIDH		;set priority
		clrf	TXB2DLC			;no data, no RTR
		movlb	0
		bsf		Modstat,0		;flag got CAN_ID
		return
		

	



		
;*****************************************************************************
;
;		shuffle for standard ID. Puts 7 bit ID into IDtemph and IDtempl for CAN frame
shuffle	movff	CanID_tmp,IDtempl		;get 7 bit ID
		swapf	IDtempl,F
		rlncf	IDtempl,W
		andlw	B'11100000'
		movwf	IDtempl					;has sidl
		movff	CanID_tmp,IDtemph
		rrncf	IDtemph,F
		rrncf	IDtemph,F
		rrncf	IDtemph,W
		andlw	B'00001111'
		movwf	IDtemph					;has sidh
		return



;************************************************************************************
;		
eeread	bcf		EECON1,EEPGD	;read a EEPROM byte, EEADR must be set before this sub.
		bcf		EECON1,CFGS
		bsf		EECON1,RD
		nop						;needed for K series
		movf	EEDATA,W
		return

;**************************************************************************
;               Pass value to write in w (w is not preserved)
;               Address to write to in EEADR
;
eewrite         movwf	EEDATA              ;write to EEPROM, EEADR must be set before this sub.
		bcf	EECON1,EEPGD
		bcf	EECON1,CFGS
		bsf	EECON1,WREN
		movff	INTCON,TempINTCON
		clrf	INTCON              ;disable interrupts
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf	EECON1,WR
eetest          btfsc	EECON1,WR
		bra	eetest
		bcf	PIR2,EEIF
		bcf	EECON1,WREN
;		clrf	PIR3                ;prevent recursive interrupts
	
		movff	TempINTCON,INTCON   ;reenable interrupts
		
		return	
		
;***************************************************************
;       Fill bytes of EEPROM with a value
;       Pass address in Eadr
;       Pass byte count in EEcount
;       pass value to fill with in w
;
eefill          lfsr    0,Eadr
nxtfill         movff   POSTINC0,EEADR  ; EEPROM address to write to
                movwf   POSTINC0        ; Save fill value
                call    eewrite         ; Write byte
                decf    POSTDEC0        ; dec the count
                bz      filldun         ; finish when zero
                movf    POSTDEC0,w      ; recover fill value
                incf    INDF0           ; next address
                bra     nxtfill
filldun         return




;		key scanning routine

scan	clrf	Key
		movlw	B'11110101'
		andwf	KEY_PORT
		movlw	B'11110001'
		iorwf	KEY_PORT			;all columns hi, LCD off
		bcf		KEY_PORT,0			;column 1 lo
		call	row
		bsf		KEY_PORT,0			;column 1 hi
		btfss	Key,7			;no key?
		bra		scan1
	
		return
scan1	movlw	4
		addwf	Key,F
		bcf		KEY_PORT,4			;column 2 lo
		call	row
		bsf		KEY_PORT,4			;column 2 hi
		btfss	Key,7			;no key?
		bra		scan2
		return
scan2	movlw	4
		addwf	Key,F
		bcf		KEY_PORT,5			;column 3 lo
		call	row
		bsf		KEY_PORT,5			;column 3 hi
		btfss	Key,7			;no key
		bra		scan3
		return
		movlw	4
scan3	addwf	Key,F
		bcf		KEY_PORT,6			;column 4 lo
		call	row
		bsf		KEY_PORT,6			;column 4 hi
		btfss	Key,7			;no key
		bra		scan4
		return
scan4	movlw	4
		addwf	Key,F
		bcf		KEY_PORT,7			;column 5 lo
		call	row
		bsf		KEY_PORT,7			;column 5 hi
		return



;********************************************************
;		read rows
;
row		btfsc	PORTB,0
		bra		row1
		movlw	0
		addwf	Key,F
		bra		gotkey
row1	btfsc	PORTB,1
		bra		row2
		movlw	1
		addwf	Key,F
		bra		gotkey
row2	btfsc	PORTB,4	
		bra		row3
		movlw	2
		addwf	Key,F
		bra		gotkey
row3	btfsc	PORTB,5			
		return
		movlw	3
		addwf	Key,F
gotkey	bsf		Key,7
;		clrf	Debcount	;debounce counter
;		movlw	4
;		movwf	Deb4
		return
;*********************************************************
;		Write a char to the LCD
;		The register must be set by calling routine
;		0 is control reg, 1 is data reg
;		Char to be sent is in W
;		sdely inroduced for 16 MHz clock.
		
lcd_wrt	movwf	Temp		;store char
		
		movlw	B'00001111' ;clear data lines
		andwf	LCD_PORT,F
		
		movlw	B'11110000'	;upper nibble
		andwf	Temp,W

		iorwf	LCD_PORT
		call	sdely		;setup time

		bsf		LCD_PORT,LCD_EN		;strobe
		
		call	sdely				;short delay
		bcf		LCD_PORT,LCD_EN

		movlw	B'00001111' ;clear data lines
		andwf	LCD_PORT,F

		swapf	Temp,F		;lower nibble
		movlw	B'11110000'	
		andwf	Temp,W
	
		iorwf	LCD_PORT	;data to LCD
		call	sdely

		bsf		LCD_PORT,LCD_EN		;strobe
	
		call	sdely				;short delay
		bcf		LCD_PORT,LCD_EN

		call	dely			;delay
		swapf	Temp,F			;restore W
		movf	Temp,W
		return
		
;**************************************************************************

;		LCD next line (CR,LF)
;
;
lcd_cr	bcf		LCD_PORT,LCD_RS		;control register
		movlw	0xC0				;CR, LF
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS		;data register
		return

;***************************************************************************
;
;		LCD home
lcd_home	bcf		LCD_PORT,LCD_RS		;control register
		movlw	0x02				;home
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS		;data register
		return

;*****************************************************************************
;
;		LCD clear
;
lcd_clr	bcf		LCD_PORT,LCD_RS		;control register
		movlw	0x01				;clear
		call	lcd_wrt
		call	dely				;delay for clear screen
		bsf		LCD_PORT,LCD_RS		;data register
		return

;*******************************************************
;
;		clears one line of LCD

clr_top	movlw	0
		call	cur_pos
		call	clr_line
		return
clr_bot	movlw	0x40
		call	cur_pos
		call	clr_line
		return

clr_line	movlw	8
		movwf	Chr_cnt
		movlw	" "
clr_ln1	call	lcd_wrt
		decfsz	Chr_cnt
		bra		clr_ln1
		return



;******************************************************************************
;
;		LCD write string	load W with start of string in EEPROM
;				
;	   End of string indicated by null character 
;      Changed from bit 7 set termination so bit 7 set chars can be embedded in strings
;      TBLPTRH must be set up with msbyte of string address
;      Pass LS Byte of string address in w
;	   Uses Count2 variable
;	   Now limits to 8 chars to aovid lock up if passed a string that is not terminated correctly



;
lcd_str	bsf		LCD_PORT,LCD_RS		;data register
		movwf	TBLPTRL				;TBLPTRH now set by caller, not assumed to be 0x30 to remove 255 byte table limit
		movlw	8					; Set counter to limit to 8 chars
		movwf	Count2
;		           
		bsf		EECON1,EEPGD
		
str1	tblrd*+
		movf	TABLAT,W
		bz      lcd_str_ret
		call	lcd_wrt
		decf	Count2
		bnz		str1
	
lcd_str_ret
		bcf		EECON1,EEPGD	
	
		return





;********************************************************************
;		A/D conversion for speed
;
a_to_d	bsf		ADCON0,GO		;start conversion
a_done	btfsc	ADCON0,GO
		bra		a_done
		bcf		Datmode,2		;clear speed change
		movff	ADRESH,Adtemp
		rrncf	Adtemp,F
		bcf		Adtemp,7		;128 steps
		movf	Adtemp,W
		subwf	Speed,W
		bz		nospeed			;has not changed
		movff	Adtemp,Speed	;new speed for change detection

		
s_128	movf	Adtemp,W
		bz		a_d_3			;is zero

		movff	Adtemp,Speed1
		incf	Speed1			;add 1 to Speed1 to send
		btfsc	Speed1,7		;overflow?
		decf	Speed1			;keep to 127
		bra		a_d_2			;send it
		
		
a_d_3	clrf	Speed1			;send a 0

	
a_d_2	bsf		Datmode,2		;flag speed change
nospeed	return
		
;**************************************************************************
;
;		convert the 4 address digits to two HEX bytes

adrconv	clrf	Adr_hi
		clrf	Adr_lo
		decf	FSR2L
		movf	Numcount,F
		bz		adr_err				;no number
		btfsc	Numcount,2			;4 digits?
		bsf		Adr_hi,7			;flag long address
		movff	POSTDEC2,Adr_lo		;ones
		decf	Numcount,F
		bz		last_num
		movlw	0x0A				;tens  (x 0x0A)
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Adr_lo,F
		decf	Numcount,F
		bz		last_num
		movlw	0x64				;hundreds  (x 0x64)
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Adr_lo,F
		movf	PRODH,W
		addwfc	Adr_hi,F
		decf	Numcount,F
		bz		last_num
		movlw	0xE8				;thousands  (x 3E8)
		mulwf	INDF2
		movf	PRODL,W
		addwf	Adr_lo,F
		movf	PRODH,W
		addwfc	Adr_hi,F
		movlw	3
		mulwf	INDF2
		movf	PRODL,W
		addwf	Adr_hi,F
last_num
        movf    PREINC2,W
        bz      long                ;Leading zero so long address
        movf	Adr_hi,F		
		bnz		long				;hi byte not zero so long address
		btfss	Adr_lo,7			;lo byte more than 127 so long address
		return
long	bsf		Adr_hi,7			;set top two bits for long address
		bsf		Adr_hi,6	
		retlw	0
adr_err retlw	1

;*************************************************************************

		;convert the 4 device digits to two HEX bytes

devconv	call	pol_clr				;clear polarity sign
		clrf	Dev_hi
		clrf	Dev_lo
		decf	FSR2L
		
		movff	POSTDEC2,Dev_lo		;ones
		decf	Numcount,F
		bz		last_dev
		movlw	0x0A				;tens  (x 0x0A)
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Dev_lo,F
		decf	Numcount,F
		bz		last_dev
		movlw	0x64				;hundreds  (x 0x64)
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Dev_lo,F
		movf	PRODH,W
		addwfc	Dev_hi,F
		decf	Numcount,F
		bz		last_dev
		movlw	0xE8				;thousands  (x 3E8)
		mulwf	INDF2
		movf	PRODL,W
		addwf	Dev_lo,F
		movf	PRODH,W
		addwfc	Dev_hi,F
		movlw	3
		mulwf	INDF2
		movf	PRODL,W
		addwf	Dev_hi,F
last_dev movlw	LOW Dat_save+1		;save new dev number in EEPROM
		movwf	EEADR
		movf	Dev_hi,W
		call	eewrite
		incf	EEADR
		movf	Dev_lo,W
		call	eewrite
		incf	EEADR
		movf	Ddr1,W
		call	eewrite
		incf	EEADR
		movf	Ddr2,W
		call	eewrite
		incf	EEADR
		movf	Ddr3,W
		call	eewrite
		incf	EEADR
		movf	Ddr4,W
		call	eewrite
		incf	EEADR
		movf	Devcnt,W
		call	eewrite
		
		return

;**************************************************************************
;
;
;		convert the 4 address digits to two HEX bytes for long address program

lng_conv	movf	Numcount,F			;any number?
		bz		no_lng					;no
		clrf	L_adr_hi
		clrf	L_adr_lo
		decf	FSR2L
		movff	POSTDEC2,L_adr_lo		;ones
		decf	Numcount,F
		bz		last_lng
		movlw	0x0A					;tens
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	L_adr_lo,F
		decf	Numcount,F
		bz		last_lng
		movlw	0x64					;hundreds
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	L_adr_lo,F
		movf	PRODH,W
		addwfc	L_adr_hi,F
		decf	Numcount,F
		bz		last_lng
		movlw	0xE8					;thousands  (x 3E8)
		mulwf	INDF2
		movf	PRODL,W
		addwf	L_adr_lo,F
		movf	PRODH,W
		addwfc	L_adr_hi,F
		movlw	3
		mulwf	INDF2
		movf	PRODL,W
		addwf	L_adr_hi,F
last_lng 
		retlw	0
no_lng	retlw	1
;*************************************************************************
;
;		convert the 4 CV number digits to two HEX values 

cvaconv	clrf	CVval1					;ready for CV value entry
		clrf	CVval2
		clrf	CVval3
		movf	Numcount,F
		bz		no_CVnum				;no number entered
		movff	Numcount,Numcv			;for use in displays of CV number
		movff	Numcount,Numtemp1
		clrf	CVnum_lo
		clrf	CVnum_hi
		decf	FSR2L
		
		movff	POSTDEC2,CVnum_lo		;ones
		decf	Numcount,F
		bz		last_CV
		movlw	0x0A				;tens
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	CVnum_lo,F
		decf	Numcount,F
		bz		last_CV
		movlw	0x64				;hundreds
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	CVnum_lo,F
		movf	PRODH,W
		addwfc	CVnum_hi,F
		decf	Numcount,F
		bz		last_CV
		movlw	0xE8				;thousands  (x 3E8)
		mulwf	INDF2
		movf	PRODL,W
		addwf	CVnum_lo,F
		movf	PRODH,W
		addwfc	CVnum_hi,F
		movlw	3
		mulwf	INDF2
		movf	PRODL,W
		addwf	CVnum_hi,F
	

last_CV movf	CVnum_hi,F
		bnz		last_1

		movf	CVnum_lo,F
		bz		no_CVnum
	
last_1	movlw	0x04				;check not more than 0x3FF
		cpfslt	CVnum_hi
		bra		no_CVnum
		btfss	Sermode,1			;is it register mode
		retlw	0
		btfsc	Sermode,0
		bra		add_tst				;address mode
		movf	CVnum_hi,F
		bnz		no_CVnum			;no hi byte allowed
		movlw	8					;max reg number
		cpfsgt	CVnum_lo
		retlw	0
	
no_CVnum
		clrf	CVnum1
		clrf	CVnum2
		clrf	CVnum3
		clrf	CVnum4	
		retlw 1	
	
add_tst	movf	CVnum_hi,F
		bnz		no_CVnum			;no hi byte
		movlw	.99					;max reg number
		cpfsgt	CVnum_lo
		retlw	0
		retlw	1		

;********************************************************************

;
;		get handle for loco from CS
;		Enter with w=0 for normal request, or w=GLOC flags for steal/share
;		returns with 0 in W if allocated, not 0 if error
;
get_handle 
		iorlw	0				; Flags set for steal/share?
		bz		doRloc			; No - use RLOC for compatibility with older CS
		movwf	Tx1d3			; flags for steal or share
		movlw	OPC_GLOC		; request loco handle, GLOC opcode for steal/share
		movwf	Tx1d0			; set opcode
		movlw	4				; Length of GLOC packet
		bra		rqloc
	
doRloc	movlw	OPC_RLOC		;request loco handle
		movwf	Tx1d0
		movlw	3
rqloc	movwf	Dlc				; Enter here with opcode set and length in w
		movff	Adr_hi,Tx1d1
		movff	Adr_lo,Tx1d2
		bsf		Modstat,1		;set mode for answer
		call	sendTXa			;send request
		return


;********************************************************************
;
;		display loco number and speed on top line

loco_lcd
			call	clr_top
			call	lcd_home
		
			bsf		LCD_PORT,LCD_RS
			movf	Adr1,W				;4 address chars
			call	lcd_wrt
			movf	Adr2,W
			call	lcd_wrt
			movf	Adr3,W
			call	lcd_wrt
			movf	Adr4,W
			call	lcd_wrt
			movlw	" "					;space
			call	lcd_wrt
			call	lcd_speed
			return

lcd_speed	call	spd_chr
			movlw	0x05
			call	cur_pos
			movf	Spd1,W				;three speed chars
			call	lcd_wrt
			movf	Spd2,W
			call	lcd_wrt
			movf	Spd3,W
			call	lcd_wrt
;			call	lcd_cr			;next line

			return

;********************************************************************

;			error message after service mode action

err_msg	;	call	beep
		;	movwf	Err_tmp
			btfss	Sermode,3
			call	read_disp
			movlw	1
			subwf	Err_tmp,W
			bz		no_ack
			movlw	2
			subwf	Err_tmp,W
			bz		over_ld
			movlw	3
			subwf	Err_tmp,W
			bz		ack_ok
			movlw	4
			subwf	Err_tmp,W
			bz		busy
			movlw	5
			subwf	Err_tmp,W
			bz		over_rng
			retlw	0
no_ack		btfss	Sermode,3		;long address no ack?
			bra		no_ack1
			movlw	0x42
			call	cur_pos

no_ack1		movlw	HIGH No_ack
			movwf	TBLPTRH 
			movlw	LOW	No_ack
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0
over_ld		movlw	HIGH Over_ld
			movwf	TBLPTRH
			movlw	LOW Over_ld
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0
ack_ok		btfsc	Sermode,3			;is it multiple writes?
			retlw	1
			call	lcd_clr
			movlw	B'00000011'
			andwf	Sermode,W
			btfss	WREG,1
			bra		ack_ok1				;page or direct
			btfsc	WREG,0
			bra		ack_ok3				;address mode
			movlw	"R"
			call	lcd_wrt
			movlw	"e"		
			call	lcd_wrt
			movlw	"g"		
			call	lcd_wrt
			bra		ack_ok2
ack_ok3		movlw	HIGH Address
			movwf	TBLPTRH  
			movlw	LOW Address
			call	lcd_str
			call	lcd_cr
			movlw	"="
			call	lcd_wrt
			movlw	" "
			call	lcd_wrt
			movff	Numcv,Numtemp1
			call	cv_disp
			movlw	" "
			call	lcd_wrt
			movlw	" "
			call	lcd_wrt
			movlw	HIGH Ack_OK
			movwf	TBLPTRH          
			movlw	LOW Ack_OK
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0

		
ack_ok1		movlw	"C"
			call	lcd_wrt
			movlw	"V"		
			call	lcd_wrt
ack_ok2		movlw	" "
			call	lcd_wrt
			movff	Numcv,Numtemp1
			call	cv_disp
			call	lcd_cr
			movlw	"="
			call	lcd_wrt
			movlw	" "
			call	lcd_wrt
			movff	Numcvv,Numtemp1
			call	cvv_disp
			movlw	" "
			call	lcd_wrt
			movlw	HIGH Ack_OK
			movwf	TBLPTRH  
			movlw	LOW Ack_OK
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0
busy		movlw	HIGH Busy
			movwf	TBLPTRH    
			movlw	LOW	Busy
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0
over_rng	movlw	HIGH Err
			movwf	TBLPTRH  
			movlw	LOW Err
			call	lcd_str
			call	beep
			bsf		Sermode,5
			retlw	0

;**********************************************************************
;
;			displays loco address on top line
;			used in error display

loc_adr		call	lcd_clr
			call	lcd_home
			bsf		LCD_PORT,LCD_RS
			movlw	"L"
			call	lcd_wrt
			movlw	"o"
			call	lcd_wrt
			movlw	"c"
			call	lcd_wrt
			movlw	"."
			call	lcd_wrt
			
			movf	Adr1,W				;4 address chars
			call	lcd_wrt
			movf	Adr2,W
			call	lcd_wrt
			movf	Adr3,W
			call	lcd_wrt
			movf	Adr4,W
			call	lcd_wrt
			call	lcd_cr				;next line
			return
 

;**********************************************************************

;			Update display when in service mode

newdisp		clrf	CVnum1
			clrf	CVnum2
			clrf	CVnum3
			clrf	CVnum4
			call	lcd_clr
			movlw	LOW	Ser_md
			movwf	EEADR
			call	eeread
			mullw	.10				;was 8
			movlw	HIGH Pmode1
			movwf	TBLPTRH   
			movf	PRODL,W
			addlw	LOW Pmode1		;prompt for CV value
			call	lcd_str
			call	lcd_cr
			btfsc	Sermode,1
			bra		regdisp

			movlw	HIGH CV_equ
			movwf	TBLPTRH   
			movlw	LOW CV_equ
			call	lcd_str
			return
regdisp		btfsc	Sermode,0
			bra		adrdisp
			movlw	HIGH REG_equ
			movwf	TBLPTRH   
			movlw	LOW REG_equ
			call	lcd_str
			return
adrdisp		movlw	HIGH ADR_equ
			movwf	TBLPTRH  
			movlw	LOW	ADR_equ
			call	lcd_str
			return			

;***************************************************************************
;			convert speed byte to three ASCII chars
;			Uses Speed

spd_chr		movff	Speed,Speed2
			movlw	1
			subwf	Smode,W
			bz		spd_14
			movlw	2
			subwf	Smode,W
			bz		spd_28
spd_conv	movlw	"0"
			movwf	Spd1
			movwf	Spd2
			movwf	Spd3
			
			movlw	.100
			subwf	Speed2,W
			bnc		tens
			movwf	Speed2
			movlw	"1"
			movwf	Spd1
			
tens		movlw	"0"
			subwf	Spd1,W
			bnz		tens1
			movlw	" "
			movwf	Spd1
tens1		movlw	.10
			subwf	Speed2,W
			bnc		ones
			movwf	Speed2
			incf	Spd2
			bra		tens1
ones		movlw	"1"
			subwf	Spd1,W
			bz		ones1
			movlw	"0"
			subwf	Spd2,W
			bnz		ones1
			movlw	" "
			movwf	Spd2
ones1		movf	Speed2,W
			iorwf	Spd3
			return

spd_14		rrncf	Speed2,F
			bcf		Speed2,7
			rrncf	Speed2,F
			bcf		Speed2,7
			rrncf	Speed2,F
			bcf		Speed2,7
			movlw	.14
			cpfsgt	Speed2
			bra		spd_conv
			decf	Speed2,F
			bra		spd_conv

spd_28		rrncf	Speed2,F
			bcf		Speed2,7
			rrncf	Speed2,F
			bcf		Speed2,7
			movlw	.28
			cpfsgt	Speed2
			bra		spd_conv
			movwf	Speed2
			bra		spd_conv


		
;************************************************************************
;			convert two address bytes to four ASCII chars
;			Adress in Adr_hi and Adr_lo. Answer in 	Adr1 to Adr4

adr_chr		movlw	B'00111111'		;mask long address bits
			andwf	Adr_hi,W
			movwf	Hi_temp			;temp for address calculations
			movff	Adr_lo,Lo_temp
			clrf	Numcount		;number of chars
			movlw	"0"				;clear chars
			movwf	Adr1
			movwf	Adr2
			movwf	Adr3
			movwf	Adr4

thous		movlw	0xE8			;lo byte of 1000
			subwf	Lo_temp,F
			movlw	0x03			;hi byte of 1000
			subwfb	Hi_temp,F
			bn		huns			;overflow
			incf	Adr1			;add to 1000s
			bra		thous			;again

huns		movlw	0xE8			;add back 1000
			addwf	Lo_temp,F
			movlw	0x03
			addwfc	Hi_temp,F
huns_1		movlw	0x64			;100
			subwf	Lo_temp,F
			movlw	0
			subwfb	Hi_temp,F
			bn		tens_0			;overflow
			incf	Adr2			;add to 100s
			bra		huns_1

tens_0		movlw	0x64			;add back 100
			addwf	Lo_temp,F

tens_1		movlw	0x0A			;10
			subwf	Lo_temp,F
			bn		ones_0			;overflow
			incf	Adr3			;add to tens
			bra		tens_1

ones_0		movlw	0x0A			;add back 10
			addwf	Lo_temp,W
			addwf	Adr4,F

			btfsc	Adr_hi,7		;short adress?
			return

			movff	Adr2,Adr1		;adjust address array for short address
			movff	Adr3,Adr2
			movff	Adr4,Adr3
			movlw	" "
			movwf	Adr4
			movlw	"0"
			subwf	Adr1,W
			bnz		adr4
			movff	Adr2,Adr1
			movff	Adr3,Adr2
			movlw	" "
			movwf	Adr3
			movlw	"0"
			subwf	Adr1,W
			bnz		adr4
			movff	Adr2,Adr1
			movlw	" "
			movwf	Adr2
			

adr4		return					;must be a digit in ones
			
			

			

		
				



;************************************************************************
;
;			send a speed change packet
;
spd_pkt         bcf	Datmode,2		;clear speed change flag
		btfss	Locstat,0		;any loco selected?

		return
		btfsc	Locstat,1
		return
		movlw	0x47			;speed /dir command
		movwf	Tx1d0
		movff	Handle,Tx1d1
	
		movff	Speed1,Tx1d2
		btfsc	Locstat,7
		bsf		Tx1d2,7			;direction bit
		movlw	3
		movwf	Dlc
		call	sendTXa			;send command

		decf	Speed1,W		;is it em stop?
		bz		spd1			;if yes, leave old speed up
		btfsc	Datmode,6
		return
		btfsc	Locstat,6		;in prog mode?
		return
		btfsc	Locstat,2		;consist set?
		return
		btfsc	Locstat,5		;consist clear?
		return
		call	lcd_speed

spd1	return

;***************************************************************************
;
;		send keepalive  

kp_pkt	movlw	OPC_DKEEP		;keep alive packet
		movwf	Tx0d0
		movff	Handle,Tx0d1
		movlw	2
		movwf	Tx0dlc
		call	sendTXi			;send command, use TXi entry point as this is called from ISR

		
		return

;***************************************************************************
;
;		send request emergency stop all (REST) packet

rest_pkt	movlw	OPC_RESTP		; CBUS opcode for emergency stop all
		movwf	Tx1d0			; Build packet in Tx buffer
		movlw	1
		movwf	Dlc			; Length of packet is 1 byte
		call	sendTXa			;send command
		
		return

;******************************************************************************






;
;		function send routine
;
funsend	movwf	Fn_tog			;save action

fncalc	movlw   0x03			; work out function number. Answer in Fnum. 
		andwf	Fnmode,W		; Function range?
		bz		frn0
		btfss	Fnmode,0
		bra		frn2
frn1	movlw	.10
		addwf	Key_temp,W
		movwf	Fnum	
		bra		funchk
frn2	movlw	.20
		addwf	Key_temp,W
		movwf	Fnum
		bra		funchk
frn0	movff	Key_temp,Fnum

funchk	call	get_fun
		movwf	Fn_temp
		btfss	Fn_temp,1			;is it mom  mode?
		bra		toggle
		btfsc	Fn_tog,0			;forced off
		bra		fn_on
		bcf		Fn_temp,0
		movf	Fn_temp,W
		call	set_fun				;change stored data
		bra		f_send
fn_on	bsf		Fn_temp,0
		movf	Fn_temp,W
		call	set_fun				;change stored data
		bra		f_send
toggle	movlw	1
		xorwf	Fn_temp,F
		movf	Fn_temp,W
		call	set_fun



#ifdef	FN_OUT1

f_send	movf	Fnmode,F			;is it range 0?
		bnz		fr3					;no
		movlw	LOW Fnbits1
		addwf	Key_temp,W
		movwf	EEADR
		call	eeread
		movwf	Funtemp
		btfss	Funtemp,6
		bra		not_fr2
		movlw	2
		movwf	Tx1d2
		movlw	B'00001111'
		andwf	Funtemp,W
		btfsc	Fn_temp,0		;on or off?
		bra		on1
		comf	WREG
 		andwf	Fr2,F			;off
		bra		on1a
on1		iorwf	Fr2,F			;on
on1a	movff	Fr2,Tx1d3

		bra		fnframe			;send frame



not_fr2 btfss	Funtemp,7
		bra		not_fr3
		movlw	3
		movwf	Tx1d2
		movlw	B'00001111'
		andwf	Funtemp,W

		btfsc	Fn_temp,0		;on or off?
		bra		on2
		comf	WREG
 		andwf	Fr3,F			;off
		bra		on2a
on2		iorwf	Fr3,F	
	
on2a	movff	Fr3,Tx1d3
		bra		fnframe			;send frame

not_fr3	movlw	1
		movwf	Tx1d2
		movlw	B'00011111'
		andwf	Funtemp,W
		btfsc	Fn_temp,0		;on or off?
		bra		on3
		comf	WREG
 		andwf	Fr1,F			;off
		bra		on3a
on3		iorwf	Fr1,F	
on3a	movff	Fr1,Tx1d3
		bra		fnframe			;send frame

fr3		btfsc	Fnmode,1
		bra		fr5				;F20 to F28
		movlw	3
		subwf	Key_temp,W
		bnn		fr4
		movlw	LOW Fnbits2		;F10 to 12
		addwf	Key_temp,W
		movwf	EEADR
		call	eeread
		movwf	Funtemp
		
		movlw	3
		movwf	Tx1d2
		movlw	B'00001111'
		andwf	Funtemp,W
 		btfsc	Fn_temp,0		;on or off?
		bra		on4
		comf	WREG
 		andwf	Fr3,F			;off
		bra		on4a
on4		iorwf	Fr3,F	
on4a	movff	Fr3,Tx1d3
		bra		fnframe			;send frame

fr4		movlw	LOW Fnbits3		;F13 to F20
		addwf	Key_temp,W
		movwf	EEADR
		movlw	3
		subwf	EEADR			;start at 0 if 3 (F13 is first of Fr4)
		call	eeread
		btfsc	Fn_temp,0		;on or off?
		bra		on5
		comf	WREG
 		andwf	Fr4,F			;off
		bra		on5a
on5		iorwf	Fr4,F	
on5a	movff	Fr4,Tx1d3
		movlw	4
		movwf	Tx1d2
		bra		fnframe

fr5		movlw	9					;check for 29 - invalid
		subwf	Key_temp,W
		bnz		fr5_ok
		return
fr5_ok	movf	Key_temp,F			;is it zero (Fn20)?
		bnz		fr5a				;no
		movlw	0x0A				;make Key = 10
		movwf	Key_temp
		bra		fr4					;send as F20
fr5a	movlw	LOW Fnbits4		;F21 to F28
		addwf	Key_temp,W
		decf	WREG
		movwf	EEADR
		
		call	eeread
		btfsc	Fn_temp,0		;on or off?
		bra		on6
		comf	WREG
 		andwf	Fr5,F			;off
		bra		on6a
on6		iorwf	Fr5,F	
on6a	movff	Fr5,Tx1d3
		movlw	5
		movwf	Tx1d2
        lfsr    FSR2,Fr5

fnframe	movlw	0x60			; function frame
		movwf	Tx1d0			; Set up CAN tx buffer to send function frame
		movff	Handle,Tx1d1	; Session handle
		movlw	4
		movwf	Dlc				; Count
		call	sendTXa			; Send frame to command station
#endif

#ifdef	FN_OUT2

f_send	btfss	Fn_temp,0		;on or off
		bra		off1
		movlw	0x49			;DFNON
		movwf	Tx1d0
		bra		out1
off1	movlw	0x4A			;DFNOF
		movwf	Tx1d0
out1	movff	Handle,Tx1d1
		movff	Fnum,Tx1d2
		movlw	3
		movwf	Dlc
		call	sendTXa

#endif

                ; Send CBUS event for function button pressed

                movlw   OPC_ACON
                btfss   Fn_temp,0
                movlw   OPC_ACOF
                movwf   Tx1d0
                movff   NN_temph,Tx1d1
                movff   NN_templ,Tx1d2
                clrf    Tx1d3
                movff   Fnum,Tx1d4
                movlw   5
                movwf   Dlc
                call    sendTXa

               ; Update display for function send


fdisp           movlw	0x40			; Position cursor start of line 2
		call	cur_pos
		movlw	"F"				; Display F for function
		call	lcd_wrt
                movlw   0x03
		andwf	Fnmode,W		; Function range?
		bz	fn_lo			; Skip if range 0

		movlw	"1"				; Display char for Range 1
		btfsc	Fnmode,1		; Range 2?
		movlw	"2"				; Yes - set display char
		call	lcd_wrt			; Display tens digit of function number

fn_lo			; Get numeric key pressed
		movlw	0x0A			; is it 10? (used for F20)
		subwf	Key_temp,W
		bnz		fn_lo2
		bra		fn_lo3			; W is zero
fn_lo2	movf	Key_temp,W		; recover original
fn_lo3	addlw	0x30			; Convert to ASCII
		call	lcd_wrt			; Display function number
        movlw   0x20			; and a space
        call    lcd_wrt
		call	lcd_wrt
	
        
		btfss	Fn_temp,0
        bra     fnshowoff       ; No - display "OFF"
	
		btfss	Fn_temp,1		;is a mom on
		bra		fn_lo1
		movlw	0x44
		call	cur_pos
		movlw	HIGH Mom_onstr
		movwf	TBLPTRH
		movlw	LOW	Mom_onstr
		bra		fnshow
fn_lo1	movlw	0x44
		call	cur_pos
		movlw   HIGH Onstr		; Yes - display "ON"
        movwf   TBLPTRH         ;  
        movlw   LOW Onstr
        bra     fnshow

fnshowoff
		btfss	Fn_temp,1
		bra		fn_off
		movlw	0x44
		call	cur_pos
		movlw	HIGH Mom_ofstr
		movwf	TBLPTRH
		movlw	LOW	Mom_ofstr
		bra		fnshow
		bcf		Locstat,3
		bcf		Locstat,1
		
		return
		
		
fn_off  movlw	0x44
		call	cur_pos
		movlw   HIGH Offstr
        movwf   TBLPTRH         ; Display function off
        movlw   LOW Offstr

fnshow  call    lcd_str         ; Display on, off or mom message
		return



;****************************************************************************
;		set loco into consist
;

conset	bcf		Locstat,5			;clear if in con clear
		bra		con1
con2	call	lcd_clr				;set a consist
		call	lcd_home
		movlw	HIGH Constr
		movwf	TBLPTRH      
		movlw	LOW Constr
		call	lcd_str				;consist string
		call	lcd_cr
		movlw	"="					;prompt for consist address
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		bsf		Locstat,2			;consist mode
		lfsr	FSR2,Con1
		clrf	Numcount
		return
con1	clrf	Con1				;clear old consist (may not be needed)
		clrf	Con2
		clrf	Con3
		bra		con2
;******************************************************************************
;
;		clear a loco from consist. (just sets screen message and disables loco) 
;
conclear call	lcd_clr				;set a consist
		call	lcd_home
		movlw	HIGH Constr
		movwf	TBLPTRH    
		movlw	LOW Constr
		call	lcd_str				;consist string
		call	lcd_cr
		movlw	HIGH Conclr
		movwf	TBLPTRH    
		movlw	LOW Conclr
		call	lcd_str
		bcf		Locstat,0
		return

;*******************************************************************************
;
;		convert consist address keys to single HEX number
;		returns with W = 0 if OK
;		returns with W = 1 if more than 127
;		FSR2 points one past last input number
;		Numcount has number of values  (1 to 3)

conconv	decf	FSR2L
		movf	Numcount,F
		bz		toobig				;if no number then flag error
		movff	POSTDEC2,Conadr		;ones
		decf	Numcount,F
		bz		last_con
		movlw	0x0A				;tens
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Conadr,F
		decf	Numcount,F
		bz		last_con
		movlw	0x64				;hundreds
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	Conadr,F
		movf	PRODH,W
		addwfc	Conadr,F
		bc		toobig
		movlw	0x80
		cpfslt	Conadr
		bra		toobig
last_con	retlw	0
toobig		retlw	1

;*******************************************************************************
;		convert and check CV value digits to single HEX byte
;
cvv_conv	decf	FSR2L
		movf	Numcount,F
		bz		noCVval				;if no number then flag error
		movff	POSTDEC2,CVval		;ones
		decf	Numcount,F
		bz		last_cvv
		movlw	0x0A				;tens
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	CVval,F
		decf	Numcount,F
		bz		last_cvv
		movlw	0x64				;hundreds
		mulwf	POSTDEC2
		movf	PRODL,W
		addwf	CVval,F
		bc		noCVval				;no carry if <256
		movf	PRODH,F			
		bnz		noCVval				;never be a PRODH if <256
		
		
last_cvv	retlw	0
noCVval		retlw	1
;******************************************************************************
;		program subroutine
;
;		First gets CV number. Press 'enter'
;		Then prompts for CV value
;		Press enter
;		Sends OTM programming command to CS.
;		Now includes service mode program and read
;
prog_sub	clrf	Numcount
			movlw	B'11101111'
			andwf	Progmode,W		;is it set at all	
			bnz		prog_1
			nop
			clrf	CVnum1
			clrf	CVnum2
			clrf	CVnum3
			clrf	CVnum4
prog_4		btfsc	Progmode,4		;service mode?
			bra		prog_4a
			call	lcd_clr
			movlw	HIGH Progstr1
			movwf	TBLPTRH  
			movlw	LOW Progstr1
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str_equ
			movwf	TBLPTRH   
			movlw	LOW Str_equ
			call	lcd_str
			lfsr	FSR2,CVnum1		;get CV number
			bsf		Progmode,0
			return
prog_1		btfsc	Progmode,4		;service?
			bra		prog_4a
			btfss	Progmode,0
			bra		prog_2
			bcf		Progmode,0
			bsf		Progmode,1
			call	lcd_clr
			movlw	HIGH Progstr2
			movwf	TBLPTRH  
			movlw	LOW Progstr2
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str_equ
			movwf	TBLPTRH  
			movlw	LOW Str_equ
			call	lcd_str
			lfsr	FSR2,L_adr1
			return
prog_2		btfss	Progmode,1
			bra		prog_3
			btfss	Progmode,4
			bra		prog_5				;service mode
			bcf		Progmode,1
;			bcf		Progmode,4
			bra		prog_sub			;do again
prog_3		btfsc	Progmode,4		;service?
			bra		prog_3a
			call	lcd_clr
			movlw	HIGH Progstr3
			movwf	TBLPTRH    
			movlw	LOW Progstr3	;prompt for CV value
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str_equ
			movwf	TBLPTRH      
			movlw	LOW Str_equ
			call	lcd_str
			lfsr	FSR2,CVval1
			bcf		Progmode,2
			bsf		Progmode,3
			return

prog_3a		btfsc	Sermode,2			;is it read
			bra		read_CV
			call	lcd_clr
			btfss	Sermode,1
			bra		prog_3b
			btfss	Sermode,0
			bra		prog_3c
			call	send_adr			
			return
prog_3b		btfsc	Sermode,3			;long address service mode prompt?
			bra		prog_3e
			movlw	HIGH Prog_CV
			movwf	TBLPTRH   
			movlw	LOW Prog_CV
			call	lcd_str
prog_3d		call	lcd_cr
			call	cv_disp
			movlw	"="
			call	lcd_wrt
prog_3f		lfsr	FSR2,CVval1
			bcf		Progmode,2
			bsf		Progmode,3
			return
prog_3c		movlw	HIGH Pmode3
			movwf	TBLPTRH
			movlw	LOW	Pmode3
			call	lcd_str
			bra		prog_3d
prog_3e		call	lcd_clr				;put up long address message
			movlw	HIGH Progstr2
			movwf	TBLPTRH
			movlw	LOW Progstr2
			call	lcd_str
			call	lcd_cr
			bsf		LCD_PORT,LCD_RS
			movlw	"="
			call	lcd_wrt
			movlw	" "
			call	lcd_wrt
			bra		prog_3f

prog_4a	call	newdisp

		lfsr	FSR2,CVnum1		;get CV number
		bsf		Progmode,0
		bcf		Progmode,3
		return
prog_4b lfsr	FSR2,CVval1
		movlw	1
		movwf	CVnum1
		movwf	Numtemp1
		bcf		Progmode,3
		bsf		Progmode,1
		return
	
		
nxtnum	movf	POSTINC2,W
		addlw	0x30
		call	lcd_wrt
		decfsz	Numtemp1
		bra		nxtnum
		movlw	"="
		call	lcd_wrt
		lfsr	FSR2,CVval1
		bcf		Progmode,2
		bsf		Progmode,3
		return

prog_5		bsf		Progmode,4		;service mode
			bsf		Progmode,0		;stay in CVnumber
			bcf		Progmode,1
			bsf		Sermode,2		; start in service mode read

			movlw	LOW	Ser_md		;write service mode default
			movwf	EEADR
			movf	Sermode,W
			call	eewrite

			call	lcd_clr
			movlw	HIGH Rmode1
			movwf	TBLPTRH      
			movlw	LOW Rmode1		;prompt for CV value
			call	lcd_str
			call	lcd_cr
			movlw	HIGH CV_equ
			movwf	TBLPTRH   
			movlw	LOW CV_equ
			call	lcd_str
			lfsr	FSR2,CVnum1		;get CV number


			return

read_CV		call	read_disp
			call	cv_read				;read the CV
			movlw	B'00010000'
			andwf	Progmode,F
			return

read_disp	call	lcd_clr			;set display for read
			btfss	Sermode,1		;test for register or adr mode
			bra		rd_disp1
			btfsc	Sermode,0		;address?
			bra		rd_disp2
		

			movlw	"R"
			call	lcd_wrt
			movlw	"e"
			call	lcd_wrt
			movlw	"g"
			call	lcd_wrt
			movlw	0x20
			call	lcd_wrt
			bra		rd_disp3
rd_disp2	movlw	HIGH Address
			movwf	TBLPTRH
			movlw	LOW Address
			call	lcd_str
			
			bra		rd_disp4
			
rd_disp1	btfsc	Sermode,3			;is it a long address read?
			bra		rd_disp5			;yes
			movlw	"C"
			call	lcd_wrt
			movlw	"V"
			call	lcd_wrt
			movlw	0x20
			call	lcd_wrt
		
rd_disp3	movff	Numcv,Numtemp1
			call	cv_disp				;display CV without leading zeroes
rd_disp4	call	lcd_cr
			movlw	"="
			call	lcd_wrt
			movlw	0x20
			call	lcd_wrt
			return

rd_disp5	nop
			return
			
;********************************************************************************

;			display CV without leading zeroes
;			needs Numtemp1 set with number of digits

cv_disp		movf	CVnum1,W
		
			addlw	0x30
			call	lcd_wrt
			dcfsnz	Numtemp1
			return
			movf	CVnum2,W
			addlw	0x30
			call	lcd_wrt
			dcfsnz	Numtemp1
			return
			movf	CVnum3,W
			addlw	0x30
			call	lcd_wrt
			dcfsnz	Numtemp1
			return
			movf	CVnum4,W
			addlw	0x30
			call	lcd_wrt
			return

;****************************************************************************

;		displays the CV value without leading zeroes
;		needs Numtemp1 set with number of digits

cvv_disp	movf	CVval1,W
		
			addlw	0x30
			call	lcd_wrt
			dcfsnz	Numtemp1
			return
			movf	CVval2,W
			addlw	0x30
			call	lcd_wrt
			dcfsnz	Numtemp1
			return
			movf	CVval3,W
			addlw	0x30
			call	lcd_wrt
			
			return

;*******************************************************************************
;
;		Here if a direction change
;
dir_sub 	btfss	Locstat,0		;no loco
		bra		dir_back
		btfss	Locstat,7
		bra		fwd
		bcf		Locstat,7
		bcf		LED_PORT,LED2			;change LEDs
		bsf		LED_PORT,LED1
		call	spd_pkt
		bra		dir_back
fwd		bsf		Locstat,7
		bcf		LED_PORT,LED1
		bsf		LED_PORT,LED2
		call	spd_pkt
dir_back		return

;*****************************************************************************
;		Emergency stop
;
;	The main entry point responds to the red key press, if it is a second press
;	then a request emergency stop all packet is sent to the command station.
;
;	The ems_mod entry point is in reponse to seeing a request emergency stop all
;	packet on CBUS, so it puts this handset into emergency stop mode. Although the 
;	command station stops all locos, if we didn't do this then our next keep alive
;	speed packet would set the loco moving again. By putting us into emergency stop
;	mode, the user has to put the control back to zero first to restart the loco
;	Yes, we do send the speed 1 (stop) packet again, but that protects against us having
;	just sent a keep alive packet after the command station responded to the emergency stop

em_sub 	btfsc	Locstat,4	; Already in emergency stop mode?
		bra		em_all		; Emergency stop pressed again 
		btfsc	Modstat,5	; Stop button flag (catches case when stop pressed twice with speed 0)
		bra 	em_all

ems_mod	btfss	Locstat,0	; valid loco?
		bra		em_back    	; 
		movlw	1			
		movwf	Speed1
		call	beep		;beep on em stop
		call	spd_pkt
		btfsc	Datmode,6	;busy?
		bra		em_bk1		;no display change
		movlw	0x40
		call	cur_pos
		movlw	HIGH Stopstr
		movwf	TBLPTRH  
		movlw	LOW Stopstr
		call	lcd_str

em_bk1	bsf		Locstat,4		;for clear 
em_back	bsf		Modstat,5		; stop button flag
		return

;****************************************************************************
;		Emergency stop all - when emergency stop pressed twice

em_all	call	rest_pkt		; Send emergency stop all to command station
		bsf		Modstat,7		; flag stop all

ems_lcd	call	beep
		call	ldely
		call	beep
		btfsc	Datmode,6		; busy?
		return					; no display change
		call 	lcd_clr			; Enter here just to display stop all message
		btfsc	Locstat,0		; If we have a valid loco
		bra		emsloco			; redisplay loco info
		call	lcd_cr			; else just move to bottom line
		bra		emsdisp
emsloco	call	loco_lcd	
emsdisp	movlw	0x40
		call	cur_pos
		movlw	HIGH EmStopstr
		movwf	TBLPTRH 
		movlw	LOW EmStopstr	; Display STOP ALL message
        call	lcd_str
		return

;****************************************************************************
;		loco not enabled till speed is zero. (safety feature)
;
adc_zero	clrwdt	
		bsf		T2CON,TMR2ON
		btfss	PIR1,TMR2IF		;beep rollover?
		bra		zero_1
		movlw	0x9F			;rese T2
		movwf	PR2
		bcf		PIR1,TMR2IF
		btg		LATC,2			;beep out
		
zero_1	call	a_to_d
		movlw	2		;is speed 0 or 1
		cpfslt	Adtemp
		bra		adc_zero
		bcf		T2CON,TMR2ON		;stop beep
		bsf		Locstat,0
		movff	Adtemp,Speed1
		clrf	Speed1
		call	lcd_clr
		call	loco_lcd
		return

;*******************************************************************************
;		send a beep
;
beep	movlw	B'00110010'
		movwf	T1CON			;set timer 1 for beep duration
		bcf		PIR1,TMR1IF
		clrf	TMR1H			;about 0.06 secs
		clrf	TMR1L
		movlw	4
		movwf	Beep			;for four times
		bsf		T1CON,TMR1ON	;start timers
		bsf		T2CON,TMR2ON
		return




;****************************************************************************
;
;		sends message to program CV OTM
;
cv_send	movlw	0x82			;OPS mode write
		movwf	Tx1d0
		movff	Handle,Tx1d1
		movff	CVnum_hi,Tx1d2
		movff	CVnum_lo,Tx1d3
		movff	CVval,Tx1d4
		movlw	5
		movwf	Dlc
		call	sendTXa			;send message
		return

;******************************************************************************
;
;		write CV in service mode

cv_wrt	btfsc	Sermode,3		;long address?
		bra		wrt_lng
cv_wrt1	movlw	0xA2
cv_wrt2	movwf	Tx1d0			;write in service mode
		movff	Handle,Tx1d1
		movff	CVnum_hi,Tx1d2
		movff	CVnum_lo,Tx1d3
		clrf	Tx1d4			;clear mode byte
		movlw	B'00000010'		;B'11111010'
		andwf	Sermode,W
		bz		wrt_dir
		movlw	B'00000011'
		andwf	Sermode,W
		addlw	1				;for page or reg mode
		movwf	Tx1d4
wrt_dir movff	CVval,Tx1d5		;get value
		movlw	6
		movwf	Dlc
		call	sendTXa
		movlw	B'00010000'
		movwf	Progmode		;for reply
		bsf		Sermode,4		;for error / ack
		return

wrt_lng	btfsc	Sermode,6		;which CV?
		bra		wrtlng1			;not CV17
		movff	Adr_hi,CVval
		bsf		Sermode,6		;for next
		bra		cv_wrt1			;do CV17
wrtlng1	btfsc	Sermode,7		;not CV18
		bra		wrtlng2
		incf	CVnum_lo,F		;now CV18
		movff	Adr_lo,CVval
		movlw	B'00000011'
		andwf	Sermode,W		;is it direct?
		bnz		wrtlng3			;not direct so don't do bit set	
		bsf		Sermode,7
		bcf		Sermode,6
		bra		cv_wrt1			;do CV18
wrtlng3	bsf		Sermode,6
		bsf		Sermode,7
		bra		cv_wrt1
		bsf		Sermode,4		;if not set?
		return
 
wrtlng2	movlw	0xA2
		movwf	Tx1d0			;write in service mode
		movff	Handle,Tx1d1
		movff	CVnum_hi,Tx1d2
		movlw	0x1D			;CV29
		movwf	Tx1d3
		movlw	1				;bit mode write
		movwf	Tx1d4
		movlw	0xFD			;NMRA set bit 5
		movwf	Tx1d5
		movlw	6
		movwf	Dlc
		bsf		Sermode,6
		bsf		Sermode,7		;for last
		movlw	B'00010000'
		movwf	Progmode		;for reply
		bsf		Sermode,4		;for error / ack
		call	sendTXa
		return
	


;		read a CV in service mode

cv_read	btfsc	Sermode,3		;already in long read?
		bra		lng_read
		movf	CVnum_hi,F		;test for long address
		bnz		cv_read1		;more than 255
		movlw	.17
		subwf	CVnum_lo,W
		bnz		cv_read1
		bra		lng_read		;read long address
;		sublw	1
;		bz		cv_read1		;not in long address mode (CV29)
		return

cv_read1		movlw	0x84		;read CV
		movwf	Tx1d0
		movff	Handle,Tx1d1
		
		movff	CVnum_hi,Tx1d2
		movff	CVnum_lo,Tx1d3
		bcf		Sermode,2
		movf	Sermode,W
		andlw	B'00000011'
		addlw	1			;direct read is always bit read
		
		movwf	Tx1d4
	
		movlw	5
		movwf	Dlc
		call	sendTXa
		movlw	B'00010000'
		movwf	Progmode		;for reply
		bsf		Sermode,2		;keep in read
		bsf		Sermode,4		;for error / ack
		return	

;************************************************************

lng_read bsf	Sermode,3		;set to long read
		bcf		Sermode,6		;read CV29
		bcf		Sermode,7
		movlw	.29
		movwf	CVnum_lo		;to read CV29
		bra		cv_read1
		
;***************************************************************************

;		answer to valid service mode read
;		converts single byte to decimal and displays	

cv_ans	movf	Handle,W
		subwf	RXB0D1,W		;is it this CAB?
		bz		cv_ans1	
		return
cv_ans1	btfss	Progmode,4	;is it service mode?
		return

cv_chr		movff	RXB0D4,CVchr2
			movlw	"0"
			movwf	CV1
			movwf	CV2
			movwf	CV3
			
CV_huns		movlw	.100
			subwf	CVchr2,W
			bnc		CV_tens
			movwf	CVchr2
			incf	CV1
			bra		CV_huns
			
CV_tens		movlw	.10
			subwf	CVchr2,W
			bnc		CV_ones
			movwf	CVchr2
			incf	CV2
			bra		CV_tens
CV_ones		movf	CVchr2,W
			iorwf	CV3,F
			bsf		LCD_PORT,LCD_RS
			movf	CV1,W
			call	lcd_wrt
			movf	CV2,W
			call	lcd_wrt
			movf	CV3,W
			call	lcd_wrt
			call	beep
			bcf		Sermode,4
			bsf		Sermode,5
			

			return

;***********************************************************************

;			long address service mode read
;			converts two bytes in CVtemp and CVtemp1 to decimal and displays			

cv_ans_l	movf	Handle,W
			subwf	RXB0D1,W		;is it this CAB?
			bz		cv_ansL	
			return
cv_ansL		btfss	Progmode,4	;is it service mode?
			return	
		
			btfss	Progmode,4	;is it service mode?
			return

;		convert two bytes to chars

			movlw	B'00111111'		;mask long address bits
			andwf	CVtemp,W
			movwf	Hi_temp			;temp for address calculations
			movff	CVtemp1,Lo_temp
			clrf	Numcount		;number of chars
			movlw	"0"				;clear chars
			movwf	CV1
			movwf	CV2
			movwf	CV3
			movwf	CV4

cthous		movlw	0xE8			;lo byte of 1000
			subwf	Lo_temp,F
			movlw	0x03			;hi byte of 1000
			subwfb	Hi_temp,F
			bn		chuns			;overflow
			incf	CV1				;add to 1000s
			bra		cthous			;again

chuns		movlw	0xE8			;add back 1000
			addwf	Lo_temp,F
			movlw	0x03
			addwfc	Hi_temp,F
chuns_1		movlw	0x64			;100
			subwf	Lo_temp,F
			movlw	0
			subwfb	Hi_temp,F
			bn		ctens_0			;overflow
			incf	CV2				;add to 100s
			bra		chuns_1

ctens_0		movlw	0x64			;add back 100
			addwf	Lo_temp,F

ctens_1		movlw	0x0A			;10
			subwf	Lo_temp,F
			bn		cones_0			;overflow
			incf	CV3			;add to tens
			bra		ctens_1

cones_0		movlw	0x0A			;add back 10
			addwf	Lo_temp,W
			addwf	CV4,F

			bsf		LCD_PORT,LCD_RS	
			movf	CV1,W				;4 address chars
			call	lcd_wrt
			movf	CV2,W
			call	lcd_wrt
			movf	CV3,W
			call	lcd_wrt
			movf	CV4,W
			call	lcd_wrt

			call	beep
			bcf		Sermode,4
			bsf		Sermode,5
			bcf		Sermode,7
			bcf		Sermode,6
			bcf		Sermode,3

			return
;*******************************************************************************
enum	clrf	Tx1con			;CAN ID enumeration. Send RTR frame, start timer

		clrf	Enum0
		clrf	Enum1
		clrf	Enum2
		clrf	Enum3
		clrf	Enum4
		clrf	Enum5
		clrf	Enum6
		clrf	Enum7
		clrf	Enum8
		clrf	Enum9
		clrf	Enum10
		clrf	Enum11
		clrf	Enum12
		clrf	Enum13
		
		call	dely			;wait a bit (didn't work without this!)
		
		movlw	B'10111111'		;fixed node, default ID  
		movwf	Tx1sidh
		movlw	B'11100000'
		movwf	Tx1sidl
		movlw	B'01000000'		;RTR frame
		movwf	Dlc
		
					;set T3 
		
		movlw	4
		movwf	T3count
		movlw	B'00110010'
		movwf	T3CON			;enable timer 3
		clrf	TMR3H
		clrf	TMR3L
		bsf		T3CON,TMR3ON
		bsf		Datmode,1		;used to flag setup state
		
		call	sendTXa			;send RTR frame
		clrf	Tx1dlc			;prevent more RTR frames
		return
		


;**************************************************************

;		send address only program frame

send_adr	movlw	0xA2
			movwf	Tx1d0
			movff	Handle,Tx1d1
			clrf	Tx1d2			;CV hi
			movlw	1
			movwf	Tx1d3			;Reg 1
			movlw	3				;address mode (same as register mode)
			movwf	Tx1d4
			movff	CVnum_lo,Tx1d5	;address value
			movlw	6
			movwf	Dlc
			call	sendTXa
			clrf	Progmode
			bsf		Progmode,4		;stay in service mode
			bsf		Sermode,4		;wait for acknowledge
			return

;***************************************************************

;			read in address only mode

read_adr	movlw	0x84
			movwf	Tx1d0
			movff	Handle,Tx1d1
			clrf	Tx1d2			;CV hi
			movlw	1
			movwf	Tx1d3			;Reg 1
			movlw	3				;address mode (same as register mode)
			movwf	Tx1d4
			movlw	5
			movwf	Dlc
			call	sendTXa
			clrf	Progmode
			bsf		Progmode,4		;stay in service mode
			bsf		Sermode,4		;wait for acknowledge
			return	

;*************************************************************

;		speed step mode sequence

ss_mode		bsf		Datmode,6		;busy
			btfsc	Progmode,5
			bra		sm_inc
			bsf		Progmode,5
ss_mode1	movlw	0
			subwf	Smode,W
			bz		sm128
			movlw	1
			subwf	Smode,W
			bz		sm14
			movlw	2
			subwf	Smode,W
			bz		sm28
			return				;invalid value

sm128		call	lcd_clr
			movlw	HIGH Selstep
			movwf	TBLPTRH
			movlw	LOW Selstep
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str128
			movwf	TBLPTRH    
			movlw	LOW Str128
			call	lcd_str
			
			return

sm14		call	lcd_clr
			movlw	HIGH Selstep
			movwf	TBLPTRH   
			movlw	LOW Selstep
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str14
			movwf	TBLPTRH    
			movlw	LOW Str14
			call	lcd_str
		
			return

sm28		call	lcd_clr
			movlw	HIGH Selstep
			movwf	TBLPTRH    
			movlw	LOW Selstep
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str28
			movwf	TBLPTRH  
			movlw	LOW Str28
			call	lcd_str
			
			return

sm_inc		incf	Smode
			movlw	3
			subwf	Smode,W			;cycle through
			btfss	STATUS,Z
			bra		ss_mode1
			clrf	Smode
			bra		ss_mode1

;*****************************************************************

;			set new SS on enter

ss_set      movlw	LOW Ss_md
			movwf	EEADR
			movf	Smode,W
			call	eewrite				;save curent ss mode
			bcf		Progmode,5
			bcf		Progmode,7			;release
			bcf		Datmode,6			;not busy
			call	locprmpt			; prompt for loco

			return

;***************************************************************

;			send speed step mode to CS for current handle

ss_send		movlw	OPC_STMOD		;STMOD
			movwf	Tx1d0
			movff	Handle,Tx1d1
			movff	Smode,Tx1d2
			btfsc	Smode,1			;only 28 step, non interleaved
			bsf		Tx1d2,0
			movlw	3
			movwf	Dlc
			call	sendTXa
			return

;**************************************************************
;		send node parameter bytes (7 maximum)
;		not implemented yet  - oh yes it is!

parasend	
		movlw	0xEF
		movwf	Tx1d0
		movlw	LOW nodeprm
		movwf	TBLPTRL
		movlw	8
		movwf	TBLPTRH
		lfsr	FSR0,Tx1d1
		movlw	7
		movwf	Count
		bsf		EECON1,EEPGD
		
para1           tblrd*+
		movff	TABLAT,POSTINC0
		decfsz	Count
		bra		para1
		bcf		EECON1,EEPGD	
		movlw	8
		movwf	Dlc
		call	sendTXa
		return

;**************************************************************************

;		check if command is for this node

thisNN	movf	NN_temph,W
		subwf	RXB0D1,W
		bnz		not_NN
		movf	NN_templ,W
		subwf	RXB0D2,W
		bnz		not_NN
		retlw 	0			;returns 0 if match
not_NN	retlw	1

;**********************************************************************


		
;*******************************************************

;			segment full so don't allocate an ID (not tested)

segful		movlw	0xFF			;default ID unallocated
			movwf	IDcount
			call	lcd_clr
			movlw	HIGH Segful
			movwf	TBLPTRH     
			movlw	LOW Segful
			movwf	TBLPTRL
			call	lcd_str
			call	lcd_cr
			movlw	HIGH Str_ful
			movwf	TBLPTRH   
			movlw 	LOW Str_ful
			movwf	TBLPTRL
			call	lcd_str
			clrf	Modstat			;no ID
			return

;**********************************************************

;		send individual parameter

para1rd	movf	RXB0D3,W
		sublw	0
		bz		numParams
		movlw	PRMCOUNT
		movff	RXB0D3,Temp
		decf	Temp
		cpfslt	Temp
		bra		pidxerr
		movlw	0x9B
		movwf	Tx1d0
		movlw	7			;FLAGS index in nodeprm
		cpfseq	Temp
		bra		notFlags
		call	getflags
		movwf	Tx1d4
		bra		addflags

notFlags	
		movlw	.14
		cpfseq	Temp
		bra		nxtparam
		call	getId1
		movwf	Tx1d4
		bra		addflags

nxtparam
		movlw	.15
		cpfseq	Temp
		bra		paramrd
		call	getId2
		movwf	Tx1d4
		bra		addflags

paramrd	
	
		movlw	LOW nodeprm
		movwf	TBLPTRL
		movlw	HIGH nodeprm
		movwf	TBLPTRH				;relocated code
		clrf	TBLPTRU
		decf	RXB0D3,W
		addwf	TBLPTRL
		bsf		EECON1,EEPGD
		tblrd*
		movff	TABLAT,Tx1d4

addflags	
		movff	RXB0D3,Tx1d3
		movlw	5
		movwf	Dlc
		movff	NN_temph,Tx1d1
		movff	NN_templ,Tx1d2
		call	sendTXa
		return	

numParams
		movlw	0x9B
		movwf	Tx1d0
		movlw	PRMCOUNT
		movwf	Tx1d4
		movff	RXB0D3,Tx1d3
		movlw	5
		movwf	Dlc
		movff	NN_temph,Tx1d1
		movff	NN_templ,Tx1d2
		call	sendTXa
		return	

pidxerr	
;		movlw	.10
;		call	errsub
		return

getflags					;create flags byte
		movlw	PF_NOEVENTS
;		btfsc	Mode,1
;		iorlw	4			;set bit 2
		movwf	Temp
		bsf		Temp,3		;set bit 3, we are bootable
		movf	Temp,W
		return


;**********************************************************
;
;getDevId returnd DEVID2 and DEVID1 in PRODH and PRODL

getId1
		call	getProdId
		movf	PRODL,W
		return

getId2
		call	getProdId
		movf	PRODH,W
		return

getProdId
		
		movlw	0x3F
		movwf	TBLPTRU
		movlw	0xFF
		movwf	TBLPTRH
		movlw	0xFE
		movwf	TBLPTRL
		bsf		EECON1,EEPGD
		tblrd*
		movff	TABLAT,PRODL
		tblrd*
		movff	TABLAT,PRODH
		return

;*****************************************************

;		send node information

sndinf	movlw	OPC_PNN
		movwf	Tx1d0
		movf	NN_temph,w
		movwf	Tx1d1
		movf	NN_templ,w
		movwf	Tx1d2
		movlw	MAN_NO
		movwf	Tx1d3
		movlw	MODULE_ID
		movwf	Tx1d4
		movlw	NODEFLGS
		movwf	Tx1d5
		movlw	6
		movwf	Dlc
		call	sendTXa
		return


;**********************************************************

;		store command station information from STAT packet

storinf	lfsr	FSR0, RXB0D5
		lfsr	FSR1, Cmdmajv
		movff	POSTINC0,POSTINC1		; Not worth a loop for 3 bytes
		movff	POSTINC0,POSTINC1
		movff	POSTINC0,POSTINC1
		return


;*******************************************************
;
;		display device select message
devdisp			
		movlw	0x40
		call	cur_pos
		movlw	HIGH Acstr
		movwf	TBLPTRH
		movlw	LOW Acstr
		call	lcd_str
		movlw	HIGH Str_equ
		movwf	TBLPTRH
		movlw	LOW Str_equ
		call	lcd_str
	
		movlw	0x47
		call	cur_pos
		movlw	" "
		call	lcd_wrt
		
ddisp0	movlw	0x43			;set to number entry point
		call	cur_pos
		movlw	" "				;clear old number
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	0x43			;reset to number entry point
		call	cur_pos
		bcf		Datmode,5		;polarity to +
		return

devdisp1						;refresh display if dev no already set
		movlw	0x40
		call	cur_pos
		movlw	HIGH Acstr
		movwf	TBLPTRH
		movlw	LOW Acstr
		call	lcd_str

		movlw	HIGH Str_equ
		movwf	TBLPTRH
		movlw	LOW Str_equ
		call	lcd_str
	
		movlw	0x47
		call	cur_pos
		btfsc	Datmode,5		;what was polarity
		bra		ddisp3
		movlw	"+"
		call	lcd_wrt
		bra		ddisp4
ddisp3	movlw	"-"
		call	lcd_wrt
ddisp4	movlw	0x43			;set to number entry point
		call	cur_pos
		movlw	" "				;clear space
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
	
		movlw	0x43			;set to number entry point
		call	cur_pos
		movff	Devcnt,Tempd		;number of digits
		movf	Devcnt,F		;any digits set?
		bz		ddisp0			;no so clear
		movf	Ddr1,W
		call	lcd_wrt
		decf	Tempd,F
		bz		ddisp2
		movf	Ddr2,W
		call	lcd_wrt
		decf	Tempd,F
		bz		ddisp2
		movf	Ddr3,W
		call	lcd_wrt
		decf	Tempd,F
		bz		ddisp2
		movf	Ddr4,W
		call	lcd_wrt
ddisp2
		return

dev_nr	bcf		LCD_PORT,LCD_RS		;to control
		movlw	B'11000111'			;set to end
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS
		btfsc	Datmode,5
		bra		rev
		movlw	"+"
		call	lcd_wrt
		bra		set_cur
rev		movlw	"-"
		call	lcd_wrt
		

set_cur	bcf		LCD_PORT,LCD_RS		;to control
		movlw	0x43
		addwf	Numcount,W		;set to number entry point
		bsf		WREG,7			
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS
		movlw	LOW	Dat_save		;save status in EEPROM
		movwf	EEADR
		movf	Datmode,W
		call	eewrite
		return

;*******************************************************************
;		generic subroutine to position display cursor
;		arrives with cursor address in W
;		resets for data display



cur_pos	bcf		LCD_PORT,LCD_RS		;to control
		bsf		WREG,7				;to write
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS
		return

;*********************************************************

;		update loco display

locdisp	call	lcd_clr			; clear lcd
		btfss	Locstat,0		; any loco
		bra		stop2
		call	loco_lcd		; display speed info
		btfss	Locstat,4		; Waiting for zero after stop?
		bra		fundisp			; Any Fn range set?
		btfsc	Modstat,7
		bra		stop2
		movlw	0x40
		call	cur_pos
	
		movlw	HIGH Stopstr
		movwf	TBLPTRH        
		movlw	LOW Stopstr		; If so, reinstate stop message
		call	lcd_str
		return
stop2	btfsc	Modstat,7		;stop all
		return
		movlw	0x40
		call	cur_pos
		movlw	HIGH EmStopstr
		movwf	TBLPTRH 
		movlw	LOW EmStopstr	; Display STOP ALL message
        call	lcd_str
		return
fundisp	movlw	B'00000011'
		andwf	Fnmode,W
		bz		funback			;no Fn range
		btfsc	Fnmode,1		;Fr2?
		bra		funFr2
		movlw	0x40
		call	cur_pos
		movlw	HIGH Fr1lbl
		movwf	TBLPTRH
		movlw	LOW Fr1lbl	
		call	lcd_str
		return
funFr2	movlw	0x40
		call	cur_pos
		movlw	HIGH Fr2lbl
		movwf	TBLPTRH
		movlw	LOW Fr2lbl	
		call	lcd_str
		
funback	return

;************************************************
;		OK message after setting long address

subOK	movlw 0x40
		call	cur_pos
		movf	CVval1,W
		addlw	0x30
		call	lcd_wrt
		movf	CVval2,W
		addlw	0x30
		call	lcd_wrt
		movf	CVval3,W
		addlw	0x30
		call	lcd_wrt
		movf	CVval4,W
		addlw	0x30
		call	lcd_wrt
		movlw	" "
		call	lcd_wrt
		movlw	"O"
		call	lcd_wrt
		movlw	"K"
		call	lcd_wrt
		return

;***************************************************

;		clear polarity sign on LCD display

pol_clr bcf		LCD_PORT,LCD_RS		;to control
		movlw	B'11000111'			;set to end
		call	lcd_wrt
		bsf		LCD_PORT,LCD_RS
		movlw	" "					;blank
		call	lcd_wrt
		return
	

;*********************************************************
;		get function status from EEPROM

get_fun movlw	LOW	Fn_stat
		addwf	Fnum,W
		movwf	EEADR
		call	eeread
		return

;***********************************************************
;
;		set function status in EEPROM
;
set_fun movwf	Temp		;save fn byte
		movlw	LOW	Fn_stat
		addwf	Fnum,W
		movwf	EEADR
		movf	Temp,W
		call	eewrite
		return

;***********************************************************
;
;           Store all functions on/off status from Frx bytes
;           Used to save status from PLOC packet
;
store_funcs     lfsr    0,Fr1
                clrf    Fnum

nxt_fun         clrwdt
                call    get_fun
                movwf   Temp
                movlw   LOW Fnbits1
                addwf   Fnum,w
                movwf   EEADR
                call    eeread
                andwf   INDF0,w
                bz      off_fun
                bsf     Temp,0
                bra     sav_fun
off_fun         bcf     Temp,0
sav_fun         movf    Temp,w
                call    set_fun

                incf    Fnum
                movlw   13
                subwf   Fnum,w
                bz      stordun
                movlw   5
                subwf   Fnum,w
                bz      incfr
                movlw   9
                subwf   Fnum,w
                bnz     nxt_fun

incfr           incf    FSR0
                bra     nxt_fun

stordun         return
 	
;
;		set / clear momentary action for FN butons
;		only valid for FNs 0 to 12 (the refreshed ones)

mom_set	btfsc	Tog_flg,0
		bra		mom_in
		btfsc	Tog_flg,2
		bra		mom_rel
		bcf		KEY_PORT,5			;strobe
		nop
		btfss	PORTB,0			;con key in?
		bra		con_in
		bsf		KEY_PORT,5			;strobe up
		retlw	0
con_in	bsf		KEY_PORT,5			;stobe up
		bsf		Tog_flg,0		;set tog key in
		retlw 	1

mom_in	bcf		KEY_PORT,5			;con key still in?
		nop
		btfss	PORTB,0
		bra		mom_in1			;yes
		bsf		KEY_PORT,5
;		clrf	Tog_flg			;not in now
		retlw	0

mom_in1	bsf		KEY_PORT,5
		clrwdt
	;	decfsz	Debcount		;count from FF to 00
	;	retlw	1
		call	deb_sub
		movf	WREG
		bnz		momi1a
		retlw	1
momi1a	bcf		KEY_PORT,5			;check again
		nop
		btfss	PORTB,0
		bra		mom_in2			;still in
		bsf		KEY_PORT,5
;		clrf	Tog_flg			;not in now
		retlw	0
		
mom_in2	bsf		KEY_PORT,5
		bsf		Tog_flg,1			;set for release
		call	momset				;do toggle setting
		bsf		Tog_flg,2			;do once only till release
		bcf		Tog_flg,0			;clear for release check
		retlw	1
		
mom_rel	btfsc	Tog_flg,0			;detected release?
		bra		mom_out
		bcf		KEY_PORT,5				;strobe
		nop
		btfsc	PORTB,0
		bra		con_out				;is up so debounce
		bsf		KEY_PORT,5
		retlw	1
con_out	bsf		KEY_PORT,5
		bsf		Tog_flg,0
		retlw	1

mom_out	bcf		KEY_PORT,5			;con key still out?
		nop
		btfsc	PORTB,0
		bra		mom_out1		;yes
		bsf		KEY_PORT,5
		retlw	0

mom_out1 bsf		KEY_PORT,5
		clrwdt
		;decfsz	Debcount		;count from FF to 00
		;retlw	1
		call	deb_sub
		movf	WREG
		bnz		momo1a
		retlw	1
momo1a	bcf		KEY_PORT,5			;check again
		nop
		btfsc	PORTB,0
		bra		mom_out2		;still out
		bsf		KEY_PORT,5
		retlw	1

mom_out2 bsf		KEY_PORT,5		;finished
		retlw	0	

;********************************************************
;
;		set momentary for FN buttons
;
momset	
mom1   	movlw	LOW Fn_stat
		addwf	Fnum,W			;point to EEPROM for status
		movwf	EEADR
		call	eeread
		movwf	Fn_temp
		btfsc	Fn_temp,1
		bra		is_tog
		bsf		Fn_temp,1
		movf	Fn_temp,W
		call	eewrite			;change to mom
		movlw	0x44
		call	cur_pos
		btfss	Fn_temp,0		;on?
		bra		mom2
		movlw	HIGH Mom_onstr
		movwf	TBLPTRH
		movlw	LOW	Mom_onstr
		call	lcd_str
		bra		no_set
mom2	movlw	HIGH Mom_ofstr
		movwf	TBLPTRH
		movlw	LOW	Mom_ofstr
		call	lcd_str
		bra		no_set
is_tog	bcf		Fn_temp,1
		bcf		Fn_temp,0		;force off
		movf	Fn_temp,W
		call	eewrite			;change to tog
		movlw	0x44
		call	cur_pos
		movlw	HIGH Offstr		;Mom_ofstr
		movwf	TBLPTRH
		movlw	LOW Offstr		;Mom_ofstr
		call	lcd_str
		call	funsend
no_set	return

;******************************************************

clr_fun	movlw	LOW Fn_stat			;sets all Fn status in EEPROM to off
		movwf	EEADR
clr_fun1	clrwdt
		call	eeread
		bcf		WREG,0
		call	eewrite
		incf	EEADR,F
		movlw	LOW Fn_stat_lst
		cpfslt	EEADR
		return
		bra		clr_fun1

res_fun	movlw	LOW Fn_stat			;sets all Fn status to clear
		movwf	EEADR
res_fun1	
		clrwdt
		movlw	0
		call	eewrite
		incf	EEADR,F
		movlw	LOW Fn_stat_lst
		cpfslt	EEADR
		return
		bra		res_fun1

;**********************************************************

;		poll for turnout state

stat_req	movlw	OPC_ASRQ	;short request
		movwf	Tx1d0			;command
		clrf	Tx1d1
		clrf	Tx1d2			;default of 0x0000 so device numbers can be taught
		movff	Dev_hi,Tx1d3
		movff	Dev_lo,Tx1d4
		movlw	5
		movwf	Dlc
		call	sendTXa
		bsf		Datmode,7		;flag for answers
		movlw	B'00100010'		;set TMR1 for 16mSec
		movwf	T1CON
		clrf	TMR1H
		clrf	TMR1L
		bsf		T1CON,TMR1ON	;start response timer

;		call	beep
		return
			

;	Debounce subroutine

deb_sub	clrwdt
		decfsz	Debcount
		retlw	0
		decfsz	Deb4
		retlw	0
		movlw	4
		movwf	Deb4
		retlw	1



;*******************************************************
;		a delay routine
			
dely	movlw	.40
		movwf	Count1
dely2	clrf	Count
dely1	clrwdt
		decfsz	Count,F
		goto	dely1
		decfsz	Count1
		bra		dely2
		return		
		
;****************************************************************

;		longer delay

ldely	movlw	.100				; counts
		movwf	Count2
ldely1	call	dely
		decfsz	Count2
		bra		ldely1
		
		return

;************************************************************************

;		short delay for LCD write strobe

sdely	nop
		nop
		nop
		nop
		return

; LCD Text strings were declared here, now moved to include file

;************************************************************************		
		ORG 0xF00000			;EEPROM data. Defaults
	
CANid	de	B'01111111',0	;CAN id default 
NodeID	de	0xFF,0xFF	;Node ID. CAB default is 0xFFFF
E_hndle de	0xFF,0		;saved handle. default is 0xFF
E_addr  de      0,0             ; Saved loco address during walkabout to check when reconnecting
Ser_md 	de	0       	;program / read mode
Ss_md   de      0               ;service mode

;key number conversion

Keytbl	de	0x0A,1		;DIR, 1
		de	2,3			;2,3
		de	0x0B,4		;EM.STOP,4
		de	5,6			;5,6
		de	0x0C,7		;CONS,7
		de	8,9			;8,9
		de	0xFF,0x0D	;null,LOCO
		de	0,0x0E		;0,ENTER
		de	0xFF,0x0F	;null,Fr1
		de	0x10,0x11	;Fr2,PROG





;	Function bits lookup

Fnbits1 de	B'00010000',B'00000001'
		de	B'00000010',B'00000100'
		de	B'00001000',B'01000001'
		de	B'01000010',B'01000100'
		de	B'01001000',B'10000001'

Fnbits2 de	B'10000010',B'10000100'
		de	B'10001000',0xFF

Fnbits3 de	B'00000001',B'00000010'
		de	B'00000100',B'00001000'
		de	B'00010000',B'00100000'
		de	B'01000000',B'10000000'

Fnbits4 de	B'00000001',B'00000010'
		de	B'00000100',B'00001000'
		de	B'00010000',B'00100000'
		de	B'01000000',B'10000000'


; Status of each function is held EEPROM
; 1 byte for each function
;   Bit 0 - Set if function is on
;   Bit 1 - Set if momentary


Fn_stat
        de	0,0		;function status.
		de	0,0
		de	0,0
		de	0,0
		de	0,0
		de	0,0
		de	0,0
		de	0,0		
		de	0,0
		de	0,0
		de	0,0
		de	0,0
		de	0,0
		de	0,0
Fn_stat_lst	de	0,0

Dat_save	de	0,0		;save status and device numbers for walkaround
			de	0,0
			de	0,0
			de	0,0
		



	ORG 0xF003FE

		de	0x00,0x00				;for boot
	
		end
