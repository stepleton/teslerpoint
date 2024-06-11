* Teslerpoint slide carousel system: Lisa-side program
* ====================================================
*
* Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.
*
* "Teslerpoint" is system for displaying bitmap images on the screen of an
* Apple Lisa computer. It comprises `build_teslerpoint_presentation.py`, which
* prepares Teslerpoint slide shows as full hard drive images, and this program,
* which runs on the Lisa and loads bitmaps from the hard drive to the display.
* This program runs on the Lisa's "bare metal", i.e. without any operating
* system, and it reads bitmap data directly from contiguous blocks of the hard
* drive: there is no filesystem per se.
*
* This program expects to be loaded to address $800 in RAM, a typical loading
* location for several bootloaders. It further expects to find the various
* in-memory system parameters (particularly the "top of memory" address at
* $2A8) and the MMU configuration in the state the boot ROM leaves them in at
* power-up.
*
* The raw binary assembled from this file needs to be modified for a specific
* set of slides. Specifically, the 3rd-4th bytes (zNumSlides) must be replaced
* with a big-endian two-byte count of the number of slides in the slide show,
* and the 5th-7th bytes (zFirstBlock) must be replaced with the 3-byte big
* endian block number of the presentation's first block. Teslerpoint will
* refuse to run (i.e. it quits gracefully to the ROM) if zNumSlides is 0.
*
* Screen bitmaps are stored as uncompressed bitmaps across 62 contiguous hard
* drive blocks; when displayed, bitmap data is loaded directly into video
* memory. (Each block holds 532 bytes, meaning that the 62nd block has 224
* unused bytes: Teslerpoint does not make use of that space.) Individual
* bitmaps (as 62-block, 32,984-byte disk regions) are then concatenated to form
* multiple-bitmap "slide shows". A slide show can be placed on any contiguous
* empty region of the hard drive provided that zFirstBlock indicates the first
* block of the slide show's first slide.
*
* Note that `build_teslerpoint_presentation.py` takes care of all the work of
* assembling Teslerpoint and a collection of image files into a bootable hard
* drive image. See the documentation in that file for details.
*
* On startup, Teslerpoint loads and displays the first bitmap. The user
* interface is minimal: press space, `.`, or the mouse button to advance to the
* next bitmap, `b` or `,` to go back to the previous bitmap, `>` to advance
* five bitmaps ahead, or `<` to go back five bitmaps. It's not possible to go
* beyond the last or first bitmaps. Press `Q` (note capital-Q) to quit to the
* ROM. Teslerpoint ignores the power button: if you wish to turn off the Lisa,
* quit to the ROM first and then press power.
*
* Teslerpoint makes use of the lisa_io library: the lisa_console_kbmouse module
* and optionally (see below re `fStandalone`) the lisa_profile_io module.
* (https://github.com/stepleton/lisa_io).
*
* Compilation size can be reduced by approximately half a kilobyte if you know
* the "stepleton_hd" bootloader (https://github.com/stepleton/bootloader_hd)
* will load this program; see the `fStandalone` flag below.


* Compilation flags -----------------------------


    ; Set this flag to 0 if and only if it will be loaded and executed by the
    ; "stepleton_hd" bootloader; otherwise, set to 1 (see comments in MAIN)
fStandalone EQU 0


* Preamble --------------------------------------


    ; This program is organised into four sections. Clarifying the brief
    ; descriptions below: kSecScratch is mainly for small items that you would
    ; find on the heap in conventional programs, but this program doesn't have a
    ; heap: we just preallocate various data structures (and statically
    ; initialise some of their data members). kSecBuffer is all of the memory
    ; past kSecScratch: we use it for buffered data from the hard drive.
kSecCode    EQU 0                ; For executable code
kSecData    EQU 1                ; For immutable data (e.g. many strings)
kSecScratch EQU 2                ; For mutable temporary storage
kSecBuffer  EQU 3                ; More mutable temporary storage


kSecC_Start EQU $800             ; The bootloader loads code to $800
    ; We manually trim these sizes down to the smallest values that won't result
    ; in more than one byte being assigned to the same memory location (the
    ; telltale sign of which is an error message from srec_cat).
kSecC_SSize EQU $4A8             ; The size of all code if fStandalone=0
kSecC_PSize EQU $1F6             ; Additional code size if fStandalone=1
kSecD_Size  EQU $320             ; The size of the kSecData section
kSecS_Size  EQU $2A              ; The size of the kSecScratch section


    IFEQ fStandalone
kSecD_Start EQU (kSecC_Start+kSecC_SSize)
    ENDC
    IFNE fStandalone
kSecD_Start EQU (kSecC_Start+kSecC_SSize+kSecC_PSize)
    ENDC
kSecS_Start EQU (kSecD_Start+kSecD_Size)
kSecB_Start EQU (kSecS_Start+kSecS_Size)


    SECTION kSecCode
    ORG     kSecC_Start
    SECTION kSecData
    ORG     kSecD_Start
    SECTION kSecScratch
    ORG     kSecS_Start
    SECTION kSecBuffer
    ORG     kSecB_Start


* Macros ----------------------------------------


    ; _mLcsIDis -- Disable interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Uses a word of stack space; moves the stack pointer
    ;   Copied from lisa_console_screen.x68 in the lisa_io library
_mLcsIDis   MACRO
      MOVE.W  SR,-(SP)
      ORI.W   #$0700,SR
            ENDM

    ; _mLcsIEna -- Enable interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Frees a word of stack space; moves the stack pointer
    ;   Copied from lisa_console_screen.x68 in the lisa_io library
_mLcsIEna   MACRO
      MOVE.W  (SP)+,SR
            ENDM


* Main program ----------------------------------


    SECTION kSecCode


MAIN:
    ; A Teslerpoint slideshow hard-codes the number of slides in the second
    ; word of its machine code: programs like build_teslerpoint_presentation.py
    ; can easily change the size of the slideshow by altering this word. It
    ; also hardcodes the lisa_profile_io:ProFileIo command for reading the
    ; first block of the first slide of the presentation. Ordinarily we would
    ; place these constants in kSecData, but changes to that code will usually
    ; move kSecData around, which makes locating the word a challenge.
    BRA.S   MainForReal          ; In any case the code jumps beyond all that
zNumSlides:
    DC.W    $A5A5                ; Replace with the true number of slides!
zFirstBlock:
    DC.L    $5A5A5A00            ; Replace upper three bytes with block addr.!

MainForReal:
    TST.W   zNumSlides           ; Do we have more than zero slides?
    BNE.S   SeriouslyItsMainNow  ; Then carry on
    LEA.L   sEmptyDeck,A3        ; Otherwise quit to the ROM monitor with a...
    BRA.S   Bye                  ; ..."no slides found" message

SeriouslyItsMainNow:
    ; If this program is loaded by the "stepleton_hd" bootloader, we can count
    ; on the lisa_io/lisa_profile_io.x68 routines being resident in memory
    ; somewhere, the data structures for those routines being initialised to
    ; work with the boot disk, and registers A0-A3 pointing to useful elements
    ; within that library. But if we were loaded by anything else, we have to
    ; bring our own copy of those routines (see the includes section below)
    ; and initialise things the same way the "stepleton_hd" bootloader does.
    IFNE fStandalone
    MOVE.B  $1B3,D0              ; Boot device ID saved by the ROM into D0
    ANDI.W  #$000F,D0            ; Just in case it's weird: force into [0,15]
    MOVE.W  #kDrive_Prts,D1      ; In D1: load parport device ID bitmap
    BTST.L  D0,D1                ; Is the device ID a parallel port?
    BNE.S   .ps                  ; If so, skip ahead to initialise it
    MOVEQ.L #$2,D0               ; Otherwise, fall back on the internal port
.ps BSR     ProFileIoSetup       ; Set up the parallel port for that device
    BSR     ProFileIoInit        ; Initialise the VIAs (or VIA, for exp.cards)
    LEA.L   ProFileIoSetup(PC),A0  ; Set registers like the "stepleton_hd"...
    LEA.L   ProFileIoInit(PC),A1   ; ...bootloader does
    LEA.L   ProFileIo(PC),A2
    LEA.L   zProFileErrCode(PC),A3
    ENDC

    ; By this point, thanks to the "stepleton_hd" bootloader or the code just
    ; above, a library for hard drive I/O will be memory resident, with pointers
    ; to key routines waiting in the address registers. We save these pointers
    ; to locations in memory with a single instruction.
    LEA.L   zProFileIoSetupPtr(PC),A4
    MOVEM.L A0-A3,(A4)

    ; Initialise library components for screen and keyboard/mouse I/O.
    BSR.W   InitLisaConsoleKbMouse
    BSR.W   InitLisaConsoleScreen

    ; And we're off to the races.
.lo BSR.B   LoadAndShowSlide     ; Main loop: load and show current slide
.li BSR.B   HandleUserInput      ; Await and deal with user input
    BEQ.S   .li                  ; Await again if nothing needs handling
    TST.B   zQuit                ; Does the user wish to quit?
    BEQ.S   .lo                  ; If not, loop; otherwise quit with...
    LEA.L   sBye,A3              ; ...a "Bye for now" error message


    ; Bye -- quit to the ROM monitor with a message but no icon or error code
    ; Args:
    ;   A3: Address of null-terminated string using ROM-supported chars only
    ; Notes:
    ;   Never returns; feel free to just BRA or fall in here
Bye:
    MOVEQ.L #$0,D0               ; No error code
    SUBA.L  A2,A2                ; No icon
    JMP     $FE0084              ; Return to ROM


    ; LoadAndShowSlide -- Load the slide from the drive; show it on the display
    ; Args:
    ;   zSlide: index of the slide to show on the display
    ; Notes:
    ;   The slide is loaded from a run of 62 contiguous blocks on the drive
    ;       as described at the top of the file
    ;   Trashes D0-D3/A0-A2
LoadAndShowSlide:
    ; Calculate address/ProFileIo command for the slide's first block.
    MOVE.W  zSlide,D0              ; Copy current slide number to D0
    MULU.W  #$3E,D0                ; Multiply by 62: # of blocks a slide uses
    LSL.L   #$8,D0                 ; Shift it one byte left, since ProFileIo...
    MOVE.L  zFirstBlock,D1         ; ...puts the command in the LSByte, then...
    ADD.L   D0,D1                  ; ...add to the "get first block" command
    MOVE.W  #$0a03,D2              ; And the ProFile retry/sparing parameters
    MOVEA.L zProFileIoPtr(PC),A1   ; Copy ProFile I/O routine address to A1

    ; For the first 61 blocks, we can load the data directly from the hard
    ; drive to the video memory.
    MOVEA.L zLisaConsoleScreenBase,A0  ; Point A0 at start of video memory
    MOVEQ.L #$3C,D3                ; Repeat 61 times:
.l0 JSR     (A1)                   ; Load a block directly into video memory
    ADD.L   #$100,D1               ; Increment block address for next block
    DBRA.W  D3,.l0                 ; And loop

    ; But for the final block, we only need part of it, and if we tried to
    ; load the whole block into the remaining bit of video memory, we'd go
    ; beyond video memory and probably past the top of the RAM as well
    ; (causing a bus error). So instead we read the block to a safer space
    ; and then copy the part of it we need into video memory.
    MOVEA.L A0,A2                  ; Copy pointer into video memory into A2
    LEA.L   zBlock,A0              ; Point A0 at our buffer memory
    JSR     (A1)                   ; Load the last block there
    LEA.L   zBlock,A0              ; Rewind A0 to our buffer memory
    ; We must copy 308 bytes (or 77 longs) into video memory
    MOVEQ.L #$4C,D3                ; Repeat 77 times
.l1 MOVE.L  (A0)+,(A2)+            ; Copy a word to video memory
    DBRA.W  D3,.l1                 ; And loop
    RTS                            ; Screen is now filled; all done


    ; HandleUserInput -- wait and react to user keyboard and mouse input
    ; Args:
    ;   (none)
    ; Notes:
    ;   Z flag is set if there's no action to take and this routine should
    ;       just be called again
    ;   zQuit flag is set if Teslerpoint should exit to the ROM
    ;   Updates zSlide where appropriate
    ;   Trashes D0-D1/A0-A1
HandleUserInput:
    BSR.W   LisaConsoleWaitForKbMouse  ; Await a keyboard or mouse event
    BEQ.S   .kb                    ; A full keypress happened; go handle it
    ROXR.W  #$1,D0                 ; Rotate the X bit into D4's MSBit
    BMI.S   HandleUserInput        ; If X had been set, we need to poll again

    ; Mouse handler: on mouseUp, advance the slide by 1
    TST.B   zLastLisaConsoleMouseB   ; Has the mouse button just been down?
    BNE.S   .fn                    ; No, return to the caller with Z set
    TST.B   zLisaConsoleMouseB     ; Yes, so is the button up now?
    BEQ.S   .fn                    ; No, return to the caller with Z set

    ; Slide navigation
.p1 ADDQ.W  #$1,zSlide             ; Try advancing the current slide by 1
    BRA.S   .go                    ; Go try it
.p5 ADDQ.W  #$5,zSlide             ; Try advancing the current slide by 5
    BRA.S   .go                    ; Go try it
.m1 SUBQ.W  #$1,zSlide             ; Try retreating the current slide by 1
    BRA.S   .go                    ; Go try it
.m5 SUBQ.W  #$5,zSlide             ; Try retreating the current slide by 5
.go BPL.S   .g1                    ; Is the slide number positive?
    CLR.W   zSlide                 ; No, force it to 0
.g1 MOVE.W  zNumSlides,D0          ; Copy total slides to D0
    CMP.W   zSlide,D0              ; Compare slide number to total slides
    BGT.S   .fy                    ; Is it less than that? If so, all done
    MOVE.W  zNumSlides,zSlide      ; No, force it to total slides...
    SUBQ.W  #$1,zSlide             ; ...less 1, then we're all done; fall into

    ; Exit point if there's user input to handle
.fy MOVE.B  zLisaConsoleMouseB,zLastLisaConsoleMouseB  ; Update button status
    ANDI.B  #$FB,CCR               ; Clear Z (handle user input)
    RTS                            ; Back to caller

    ; Exit point if there's no user input to handle
.fn MOVE.B  zLisaConsoleMouseB,zLastLisaConsoleMouseB  ; Update button status
    ORI.B   #$04,CCR               ; Set Z (no user input to handle)
    RTS                            ; Back to caller

    ; Exit point if the user wishes to quit
.qt MOVE.B  #1,zQuit               ; Set zQuit, clear Z
    RTS                            ; Back to caller

    ; Keyboard handler
.kb MOVE.B  zLisaConsoleKbChar,D0  ; Load keyboard byte into D0 for speed
    CMPI.B  #'Q',D0                ; Does the user want to quit Teslerpoint?
    BEQ.S   .qt                    ; Yes, return to caller with quit flag set
    CMPI.B  #' ',D0                ; Does the user want to advance one slide?
    BEQ.S   .p1                    ; Yes, advance one slide
    CMPI.B  #'.',D0                ; Does the user want to advance one slide?
    BEQ.W   .p1                    ; Yes, advance one slide
    CMPI.B  #'b',D0                ; Does the user want to go back one slide?
    BEQ.W   .m1                    ; Yes, go back one slide
    CMPI.B  #',',D0                ; Does the user want to go back one slide?
    BEQ.W   .m1                    ; Yes, go back one slide
    CMPI.B  #'>',D0                ; Does the user want to advance five slides?
    BEQ.W   .p5                    ; Yes, advance five slides
    CMPI.B  #'<',D0                ; Does the user want to go back five slides?
    BEQ.W   .m5                    ; Yes, go back five slides
    BRA.S   .fn                    ; Oh well, return to caller with Z clear


    ; InitLisaConsoleScreen -- Prepare this library's global data structures
    ; Args:
    ;   (none)
    ; Notes:
    ;   Copied from lisa_console_screen.x68 in the lisa_io library
    ;   Must be called prior to LoadAndShowSlide
InitLisaConsoleScreen:
    MOVE.L  $2A8,zLisaConsoleScreenBase  ; Copy "end of RAM" from ROM data
    SUB.L   #$8000,zLisaConsoleScreenBase  ; Subtract 32k (the screen data)
    RTS                            ; Back to caller


* Included components ---------------------------


    INCLUDE lisa_io/lisa_console_kbmouse.x68
    IFNE fStandalone
    SECTION kSecCode               ; (lisa_profile_io.x68 doesn't use sections)
    INCLUDE lisa_io/lisa_profile_io.x68
    ENDC


* Fixed data ------------------------------------


    SECTION kSecData


sEmptyDeck:
    DC.B    'NO SLIDES FOUND',$00
sBye:
    DC.B    'BYE FOR NOW...',$00


* Scratch data ----------------------------------


    SECTION kSecScratch


    DS.W    0                    ; Word alignment
    ; Pointers to ProFile I/O library data and routines
zProFileIoSetupPtr:
    DC.L    'I/O '               ; Points to: I/O data structure setup routine
zProFileIoInitPtr:
    DC.L    'lib '               ; Points to: I/O port initialisation routine
zProFileIoPtr:
    DC.L    'poin'               ; Points to: block read/write routine
zProFileErrCodePtr:
    DC.L    'ters'               ; Points to: error code byte

    ; Miscellaneous
zLisaConsoleScreenBase:
    DC.L    $12345678            ; Address of beginning of video RAM

    ; State tracked by this program
zSlide:
    DC.W    0                    ; Which slide we're currently displaying
zLastLisaConsoleMouseB:
    DC.B    0                    ; Mouse button down when we last checked?
zQuit:
    DC.B    0                    ; Does the user wish to quit?


* Buffer data -----------------------------------


    SECTION kSecBuffer


    ; 532 bytes of RAM for blocks read from/written to the disk
    DS.W    0                    ; Word alignment just in case...
zBlock:
    ; This data is here just so the assembler will complain if the contents of
    ; the kSecScratch section start to impinge on this section. We can comment
    ; this out altogether if the code is building without complaint, but there's
    ; probably no need for that unless these are the only two bytes in the final
    ; 512-byte block.
    DC.B    'OK'                 ; Not used; unnecessary


* That's all, folks! ----------------------------


    END     MAIN
