  TITLE "Source for CANCAB LCD messages in various languages"

; This is a stub to allow a hex file to be built that 
; contains just the message table so that the language  
; can be bootloaded into a cab via CBUS

; A define for the language to be built is set in the project file
; The project file contains configurations for each language

; Assembly options
  LIST  P=18F2480,r=hex,N=75,C=120,T=ON

  include   "p18f2480.inc"

  include "..\cbuslib\cbusdefs8h.inc"

; Define the node parameters to be stored at nodeprm

MAJOR_VER   equ 2
MINOR_VER   equ "s"
BETA_VER    equ 0           ; Beta build number: Set to zero for a release build

MAN_NO      equ MANU_MERG ;manufacturer number
MODULE_ID   equ MTYP_CANCAB ; id to identify this type of module
EVT_NUM     equ 0           ; Number of events
EVperEVT    equ 0           ; Event variables per event
NV_NUM      equ 0           ; Number of node variables
NODEFLGS  equ B'00001010'  ; Node flags  Consumer=No, Producer=Yes, FliM=No, Boot=YES
CPU_TYPE  equ P18F2480
loadadr     equ 0x3000


    ifdef CAB_BRITISH
        include "cabmessages2s-British.inc"
    endif

    ifdef CAB_CANADIAN_FRENCH
        include "cabmessages2s-CanadianFrench.inc"
    endif

    ifdef CAB_AMERICAN
        include "cabmessages2s-American.inc"
    endif

    ifdef CAB_GERMAN
        include "cabmessages2s-German.inc"
    endif

    ifdef CAB_DUTCH
        include "cabmessages2s-Dutch.inc"
    endif



; NODE PARAMETER BLOCK

    ORG   0820h
nodeprm db    MAN_NO, MINOR_VER, MODULE_ID, EVT_NUM, EVperEVT, NV_NUM, MAJOR_VER,NODEFLGS,CPU_TYPE,PB_CAN ; Main parameters
    dw    loadadr     ; Load address for message table
    dw    0       ; Top 2 bytes of 32 bit address not used
        dw      0               ;15-16 CPU Manufacturers ID low
    dw      0       ;17-18 CPU Manufacturers ID high
    db    CPUM_MICROCHIP,BETA_VER     ;19-20 CPU Manufacturers code, Beta revision
sparprm fill  0, prmcnt-$   ; Unused parameter space set to zero

PRMCOUNT equ  sparprm-nodeprm ; Number of parameter bytes implemented

    ORG   0838h

prmcnt  dw    PRMCOUNT
nodenam dw    Cabstr
    dw    0

PRCKSUM equ MAN_NO+MINOR_VER+MODULE_ID+EVT_NUM+EVperEVT+NV_NUM+MAJOR_VER+NODEFLGS+CPU_TYPE+PB_CAN+HIGH Cabstr+LOW Cabstr+HIGH loadadr+LOW loadadr+PRMCOUNT+CPUM_MICROCHIP+BETA_VER

cksum dw    PRCKSUM     ; Checksum of parameters
    
        end
  


