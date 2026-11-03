# Ampex 210 Video Display Terminal — Operation Manual

Transcription of `3515196_AMPEX_210_Operating_Manual_Apr84.pdf` (Ampex publication 3515196, April 1984, second edition June 1984), a 102-page scan with no text layer.

How it was made:

- Every page was rasterised at 300 dpi and run through Tesseract 5.
- The pages that matter for programming the terminal were then proofread against the scan and retyped by hand: the five status lines (Set-Up parameters, Tables 3-1 to 3-5), function key codes and visual attributes (Tables 5-2 to 5-6), the emulation sequence table (Table 6-2), and Appendices A, C, E and F. Each page carries a `<!-- page N (proofread) -->` or `<!-- page N (OCR) -->` marker; N is the PDF page number.
- The other pages are cleaned-up OCR: headers and page footers removed, lines joined into paragraphs. Prose there is mostly right, but tables on those pages have lost their layout and individual characters can be wrong. Check the PDF before relying on them.
- Left out: the table of contents and lists of figures and tables (PDF pages 5–10), the ASCII chart, the keyboard layout drawings and the national character table. Pages 101–102 are a German distributor's brochure bound in at the end, left as OCR.

Notation follows the manual: `ESC x` is the escape character followed by `x`, and `CTRL/x` is the control character typed as Ctrl+x (`CTRL/^` is RS, 1E hex; `CTRL/_` is US, 1F hex).

Where the manual contradicts itself, the cells are marked [sic]. Table 6-2 leaves cursor addressing and three of the cursor shapes blank in the A210 column, but Appendix A lists them for native mode. It gives Reverse Linefeed as `CTRL/j` where Appendix A has `ESC j`.

<!-- page 1 (OCR) -->

®

AMPEX

Ampex Corporation - One of The Signal Companies

AMPEX 210 VIDEO DISPLAY TERMINAL OPERATION MANUAL

APRIL 1984

Ampex Corporation, Computer Products Division 200 N. Nash Street - El Segundo, California - 90245

<!-- page 2 (OCR) -->

AMPEX

Ampex Corporation - One of The Signal Compenies@

AMPEX 210 VIDEO DISPLAY TERMINAL OPERATION MANUAL

3515196 APRIL 1984

DISCLAIMER

AMPEX CORPORATION MAKES NO REPRESENTATION OR WARRANTIES WITH RESPECT TO THE CONTENTS OF THIS MANUAL AND DISCLAIMS ANY IMPLIED WARRANTIES OR FITNESS FOR ANY PARTICULAR APPLICATION. AMPEX CORPORATION RESERVES THE RIGHT TO REVISE THIS MANUAL WITHOUT OBLIGATION OF AMPEX CORPORATION TO NOTIFY ANY PERSON OR ORGANIZATION OF SUCH REVISION.

COPYRIGHT NOTICE

COPYRIGHT 1984 BY AMPEX CORPORATION. ALL RIGHTS RESERVED WORLDWIDE. NO PART OF THIS PUBLICATION MAY BE REPRODUCED WITHOUT THE EXPRESS WRITTEN PERMISSION OF AMPEX CORPORATION.

WARNING

THIS EQUIPMENT GENERATES, USES, AND CAN RADIATE RADIO FREQUENCY ENERGY AND IF NOT INSTALLED AND USED IN ACCORDANCE WITH THE INSTRUCTIONS IN THIS BOOK, MAY CAUSE INTERFERENCE TO RADIO COMMUNICATIONS. IT HAS BEEN TESTED AND FOUND TO COMPLY WITH THE LIMITS FOR A CLASS A COMPUTING DEVICE PURSUANT TO SUBPART J OF PART 15 OF FCC RULES, WHICH ARE DESIGNED TO PROVIDE REASONABLE PROTECTION AGAINST SUCH INTERFERENCE WHEN OPERATED IN A COMMERCIAL ENVIRONMENT. OPERATION OF THIS EQUIPMENT IN A RESIDENTIAL AREA IS LIKELY TO CAUSE INTERFERENCE IN WHICH CASE THE USER AT HIS OWN EXPENSE WILL BE REQUIRED TO TAKE WHATEVER MEASURES MAY BE REQUIRED TO CORRECT THE INTERFERENCE.

Ampex Corporation, Computer Products Division 200 N. Nash Street - El Segundo, California - 90245

<!-- page 3 (OCR) -->

SECOND EDITION: JUNE 1984 SAFETY WARNING

Dangerous voltages are present when the terminal is on, and may remain after the power is off, Use caution whenever connecting/ disconnecting serial interfaces or cables to the Ampex 210 Video Display Terminal.

The internal phosphor of the cathode ray tube is toxic. Use extreme caution whenever the protective housing is removed and the tube is exposed, If the tube breaks, exposing skin or eyes to the phosphor, rinse the affected area with cold water and consult a physician.

The terminal power cable is supplied with a safety ground. Do not use the terminal with an ungrounded outlet.

Do not connect or disconnect the keyboard cable when the power is on; doing so may result in damage to the terminal that is not covered under the warranty.

DISCLAIMER

Ampex Corporation makes no representation or warranties with respect to the contents of this manual and disclaims any implied warranties or fitness for any particular application. Ampex Corporation reserves the right to revise this manual without-obligation of Ampex Corporation to notify any person or organization of such revision.

COPYRIGHT NOTICE

Copyright 1984 by Ampex Corporation. All rights reserved worldwide. No part of this publication may be reproduced without the express written consent of Ampex Corporation.

WARNING

This equipment generates, uses, and can radiate radio frequency enerqgy and if not installed and used in accordance with the instructions provided in this manual, may cause interference to radio communications. It has been tested and found to comply with the limits for a Class A computing device pursuant to Subpart J of Part 15 of FCC Rules, which are designed to provide reasonable protection against such interference when operated in a commercial environment. Operation of this equipment in a residential area is likely to cause interference in which case the user, at the user's expense, will be required to take whatever measures regquired to correct the interference.

<!-- page 4 (OCR) -->

SERVICE AND ASSISTANCE

Ampex Corporation provides a comprehensive post sales service and support program for the Ampex 210 product line. This service program is structured to provide immediate access to support assistance and information.

Customer commitment is maintained through the expertise and skills of a competent, professional staff whose dedication assures all Ampex 210 customers the maximum benefits of quality support.

Limited Warranty

Ampex Corporation warrants products sold to the buyer against defects in material or workmanship.

To obtain warranty and arrange for factory repair, refer to the Warranty documentation and Registration Card (3515020-01 and 3514020-02, respectively) enclosed with each Ampex 210 Video Display Terminal.

Technical Assistance Technical assistance may be obtained through the Customer Service Department, Terminals, within the Computer Products Division of Ampex Corporation. -To obtain such assistance, call:

800~538-7838 (outside California)

800-524-2850 (within California, except 415 area code) 408-725-2069 (locations having 415 area code)

ii

<!-- page 5: table of contents / lists of figures and tables, omitted -->

<!-- page 11 (OCR) -->

## SECTION I OVERVIEW

### 1.1 PURPOSE AND SCOPE

This manual provides the information necessary to operate the Ampex 210 video display terminal while in Ampex native mode. Included are installation and set-up instructions as well as explanations of all operating functions. The manual is intended to be useful to both terminal operators and computer programmers.

### 1.2 GENERAL DESCRIPTION

The Ampex 210 is a desktop video display terminal (Figure 1-1) designed to function as an input/output peripheral for a computer system. Physical and functional descriptions are provided in the remaining paragraphs of this section.

FRONTISMECE 6097

Figure 1-1., Ampex 210 Video Display Terminal

<!-- page 12 (OCR) -->

#### 1.2.1 Physical Description

The Ampex 210 consists of two major subassemblies: the keyboard and the display unit.

##### 1.2.1.1 Keyboard

The keyboard provides the means for the operator to input information and commands to the computer system. The detached keyboard attaches to the display unit via a coiled cable extending to a maximum of six feet. This provides flexibility and comfort to the operator during use of the terminal.

The keyboard has a step-sculptured profile and adjustable slope to 7, 11, and 15 degrees. Key cap surfaces are a nonglare gray with selected keys a darker shade of gray for ease of access. Key legends are black.

##### 1.2.1.2 Display Unit

The display unit consists of a molded plastic case which houses the electrical and electronic circuitry necessary to display and transmit information, and a cathode ray tube (CRT) for displaying the information. The display has a l4-inch (diagonal) viewing screen. The display unit is seated on a pedestal which allows the unit to tilt and swivel.

#### 1.2.2 Display Terminal Features

Table 1-1 lists and describes the various features of the Ampex 210 terminal.

Table 1-1. Display Terminal Features

Features Description

DISPLAY FORMAT The viewing screen can display a page of 2,000 characters, formatted in twenty-four horizontal lines of eighty characters each. An additional status line, located at the bottom of the screen, may be selected for display by the user. The status line provides a display of current operating and emulation modes, functions, and other useful information.

<!-- page 13 (OCR) -->

Table 1-1. Display Terminal Features

(Cont.)

Features

Description

CRT SAVER CIRCUIT

DISPLAY MEMORY

AUDIBLE KEY CLICK

CHARACTER SET

CHARACTER PRESENTATION

After about 10 minutes if no information is sent to the terminal by either the operator or host computer, all information displayed on the viewing screen, disappears from the screen. The screen reactivates as soon as any key is depressed or prompted by the host computer. Any information previously displayed on the screen will reappear.

The purpose of the CRT saver circuit is

to prolong the operating life of the CRT,

The Ampex 210 terminal can store one page (or screen) of data.

An electronically-generated click (operator—-selectable) occurs whenever a key is depressed. The audible key click feature may be turned on and off while in the Set-Up mode.

The Ampex 210 can display 168 letters, numerals, and symbols. Included is the 86-character American Standard Code for Information Interchange (ASCII) set, 15 line graphic symbols, 32 control character facsimiles, and 25 national characters

and symbols. In addition to the standard character set, United States/United Kingdom, there are five optional character sets for the following countries: Germany, France, Sweden, Norway, and Denmark.

Each alphanumeric or symbolic character is presented on the screen in a 7 by 10 dot matrix within a position field of nine dots horizontally by twelve dots vertically.

<!-- page 14 (OCR) -->

Table 1-1. Display Terminal Features

(Cont.) Features Description CHARACTER VISUAL Each character can be assigned visual ATTRIBUTES attributes from either ' the terminal key-

board or the host computer. Character visual attributes are designed to not extend character positions (except for half-intensity), can be assigned to single characters or to fields of characters, and can be used in combination. Refer to Table 5-6 for a list of possible visual attributes and combinations thereof.

CURSOR The cursor is the pointer-indicator used to designate the current character position; alsc defined as the position at which the next character received will be displayed. The cursor is readable and addressable.

#### 1.2.3 Operating Modes

Operating modes are host computer- or operator keyboard-selectable and determine the effects of the terminal's functions. The various operating modes are discussed in Table 1-2.

Table 1-2. Operating Modes

Mode Description

HALF DUPLEX/ In order to properly communicate with

FULL DUPLEX the host computer, a selection must be made between these two conversational modes.,

BLOCK This operating mode provides for a block

of data to be entered from the keyboard to the terminal display memory without immediate transmission to the host computer. This allows for editing of data locally before transmitting to the host.

LINE This operating mode is the same as Block mode except that a line, not a block, of data may be edited and then transmitted to the host computer.

<!-- page 15 (OCR) -->

Table 1-2. Operating Modes

WRITE PROTECT

PROTECT

MONITOR

FUNCTION KEYS

AUTO SCROLL

(Cont.)

Mode Description

CHARACTER This operating mode provides for the entry of data from the keyboard and for transmission of each character to the host computer immediately upon depression of a key.

LOCAL This operating mode provides for the

local execution of terminal functions. Transmission between the terminal and the host computer is prohibited.

In Write Protect mode, characters are written in half intensity on the screen and will be protected when the terminal is in Protect mode.

In Protect mode, areas previously written in Write Protect can be designated as protected against erasure, change, or transmission. These areas are displayed in half-intensity.

Monitor mode permits entry and display of all control characters to the screen., The displayed control characters will not be interpreted or executed.

14 function key sequences are available for the operator to transmit code sequences to the host computer.

Scrolling may be enabled and disabled by making the appropriate selection while in Set-Up mode. It may also be enabled and disabled by toggling ESC H. When scrolling is disabled, the cursor will wrap around to line 1 column 1 if a carriage return line feed or line feed

is issued while the cursor is on line 24.

Operating modes and their functions are explained in more detail in Section Five of this manual.

<!-- page 16 (OCR) -->

### 1.3 EMULATION CAPABILITIES

The Ampex 210 terminal is capable of emulating the functions, escape and control code sequences, operator-selectable options, and ASCII code structure of the terminals listed in Table 1-3.

Table 1-3. Emulated Terminals

Manufacturer VDT Model ADDS Corp. Regent 20/25, Viewpoint Al, A2 Hazeltine Corp. 1400, 1410, 1500 Lear Siegler, Inc. ADM5 (ADM3, 3A, 3A+) Qume Corp. QVT102 TeleVideo Systems Inc. 910, 910+, 920, 925 l.4 SPECIFICATIONS

The following is a list of operating characteristics and specifications for the Ampex 210 video display terminal,

Display Screen

l4-inch nonglare screen

Green or amber phosphor '

60 or 65 Hz refresh rate (operator-selectable)

Displayed Character Set

168 displayable characters

96 ASCII characters

32 control characters

15 line graphic characters

25 national characters

24 data lines; 25th status line 80 characters per line

2000 characters per screen

Character Typestyle 7 x 10 dot matrix in a 9 x 12 dot field

National Character Sets United States/United Kingdom German

French

Swedish

Danish

Norwegian

<!-- page 17 (OCR) -->

Visual Attributes Flash

Blank (security) Reverse video Underline Half-intensity Combination attribute

Cursor

9 x 12 dot matrix

Block or underline Flashing or Steady

No cursor

Readable and addressable

Cursor Control Keys v, T, ¢, >, Home, Tab, Back Tab, Retu Linefeed, Backspace

Edit Keys

Line insert/delete Character insert/delete Erase to end of line Erase to end of page

Emulations

ADDS Regent 20/25, Viewpoint Al, A2 Hazeltine 1400, 1410, 1500

Lear Siegler ADM5, ADM3, ADM3A, ADM3A Qume QVT 102

TeleVideo 910, 910+, 920, 925

Operating Modes Half-duplex/full-duplex Block, line, character, local Protect, write protect Function Key

Monitor

Auto Scroll

Set-Up

Primary Port and Printer Port

Data Transmission Rates (Independently-Selectable)

50, 75, 110, 135, 150, 300, 600, 1200 1800, 2400, 3600, 4800, 7200, 9600, 19,200 (19.2) bits per second.

Interfaces Standard RS232C port RS232C printer port (bi-directional)

<!-- page 18 (OCR) -->

Printer Functions

Local print (page print) Transparent print

Copy print

Operating Environment Temperature: 320F to 104°F (0°C to 40°C) Humidity: 5% to 95%

Physical Dimensions

Display Unit Keyboard width 13.5in (343mm) 19.0in (483 mm) Depth 13.5in (343mm) 7.5in (191mm) Height 14.5in (369mm) 1.5in ( 38mm) Weight 19.41b (8.7kg) 2.01b (.9kqg)

Power Requirements

115 vac (+10%, -15%) at 0.5 amp 230 vac (+10%, -15%) at 0.25 amp 50/60 Hz (+3%), 55W

Transmission Protocol XON/XOFF DTR High/DTR Low

Requlatory Compliance

UL (United States) FCC Class A (United States)

<!-- page 19 (OCR) -->

## SECTION II INSTALLATION

### 2.1 INTRODUCTION

The Ampex 210 video display terminal may be operated in a wide variety of physical environments., The remainder of this section provides explanations and diagrams to assist the user during installaton of the Ampex 210.

### 2.2 Primary Port Interface

The Ampex 210 terminal uses a standard RS232C primary port interface to connect the terminal to a host computer or modem.

Table 2-1 provides interface pin signal assignments at the primary port,

Table 2-1. Primary Port Pin Signal Assignments

=FPin No. Signal Name Mnemonic Signal Direction

1 Chassis ground

2 Transmit Data Output From Terminal

3 Receive Data Input To Terminal

4 Request-to-Send Output RTS From Terminal

5 Clear—-to-Send Input CTS To Terminal

6 Data-Set—-Ready Input DSR To Terminal (optional)

7 Signal Ground

8 Data Carrier Detect DCD To Terminal

20 Data-Terminal-Ready DTR From Terminal Output

<!-- page 20 (OCR) -->

### 2.3 Interface Jumper Option

The Ampex 210 terminal offers an alternative to the standard primary interface. Table 2-2 lists and describes the jumper options available.

Table 2-2, Jumper Options

Jumper Description

W23-W24 Allows Data Carrier Detect to monitor the readiness of an external modem,

wW20-w21 Data Terminal Ready. Output signal sent from the terminal to the host to enable communications.

Options

1. Cutting W23-W24 and connecting W24 and W25 allows Data Set Ready to monitor the readiness of an external modem.

2, Cutting W20-w21 and connecting W21 to W22 uses a Request to Send (RTS) signal to the computer to enable communications.

### 2.4 Installation Requirements

The Ampex 210 terminal is designed to be mounted on a flat, hard surface such as a desk or table top capable of supporting at least 22 pounds (10 kg). Ambient temperature of the operating environment must be within 32° F to 104° F (0° to 40©° C) range.

CAUTION

Do not block any of the air vents on the unit. All air vents in the terminal case must be kept clear in order to provide proper cooling during operation,

<!-- page 21 (OCR) -->

#### 2.4.1 Space Allocation

The detached keyboard permits considerable flexibility in positioning the unit for use, Figure 2-1 illustrates the terminal's overall dimensions as well as the minimum surface area required for installation.

13.50 in. (343 ) A A 13.50 in. (343 mm) 21.00 in {534 mm) Y s . _ Y .00 in.

6151

Figure 2-1., Overall Dimensions

<!-- page 22 (OCR) -->

2.,4,2 Input Power

The Ampex 210 is configured at the factory for either 115 or 230 vac. Installation site power requirements for both versions are listed in Table 2-3.

Table 2-3. Input Power Requirements

Version Phasing Frequency Current 115 vac +10% Single Phase 60 Hz +3% 0.50 A -15% 230 vac +10% Single Phase 50 Hz 3% 0.25 A -15% WARNING

High voltage is present within the case when power is on. Remove the power cable from the ac receptacle before removing the top cover. Only authorized service personnel should open the case.

The Ampex 210 may be strapped for 115 or 230 vac. Figure 2-2 contains drawings showing the two versions of the strapping plug. Refer to these drawings when changing the voltage from 115 vac (applicable in the United States) to 230 vac (applicable outside the United States) or vice versa as needed.

NOTE The fuse, located in fuseholder on back

panel of the VDT (Figure 2-3), must be

changed when the voltage is changed. For:

115 vac - Use a 2A fuse 230 vac - Use a 1A fuse

<!-- page 23 (OCR) -->

6109

Version 2

Figure 2-2, Voltage Strapping Plug (Version 1 and Version 2)

<!-- page 24 (OCR) -->

#### 2.4.3 AC Power Cord and Plug

Each terminal is shipped with either a 115vac/60 Hz power plug (for use in the United States) or a 230vac/50 Hz power plug (for use outside the United States). Ampex 210 terminals in the United Kingdom and Australia may need customized power plugs to fit the receptacles in these countries.

WARNING

Electric shock may result if the power cord is connected to ac power when the plug is cut off, Be sure to disconnect the cord from ac power before customizing the power plug.

2.,4.4 Interface Cable Connections

Figure 2-3 is a view of the back panel of the Ampex 210 video display terminal. Refer to this figure when attaching the primary port (to computer) and the printer port (to printer) interface cables.

WARNING

It is recommended that any cable used be shielded and jacketed. Using such a cable properly will help to minimize electromagnetic interference. Reducing such interference will not only protect your terminal from signal noise, but will also protect other devices near your terminal (e.g., a TV or radio) from interference radiated by an improperly shielded cable.

2.4.5 Keyboard Port Connection Figure 2-4 shows the location of the keyboard cable port. Refer to

this figure when attaching the keyboard cable to the display terminal.

CAUTION

Do not connect or disconnect the keyboard to or from the display unit when power is on. Erratic performance may result.

<!-- page 25 (OCR) -->

POWER SWITCH

AUXILIARY (PRINTER) RS232S PORT

FUSEHOLDER PRIMARY R$2328 PORT

REAR PANEL VIEW 6008

Figure 2-3. Ampex 210 Video Display Terminal (Back Panel View)

Figure 2-4. Keyboard Port on Display Terminal

<!-- page 26 (OCR) -->

2,5 Power-on and Reset To power-on the terminal:

1. Make sure all interface cables are connected properly to their respective ports (see 2.4.4 Interface Cable Connections and 2.4.5 Keytoard Port Connection).

2. Make sure the power cable is plugged into the proper outlet (see 2.4.3 AC Power Cord and Plug).

3, Within seconds, the unit undergoes its self-test,

4. After the self-test is completed, the cursor will display in the top left-hand corner of the screen.

5. Adjust the phosphor intensity by rotating the intensity control dial, located underneath the right-hand portion of the display unit.

6. The terminal is now ready to begin performing the operations described in the remaining sections of this manual.

To reset the terminal while performing normal operations press SHIFT and the BREAK key twice simultaneously.

### 2.6 SELF-TEST

The self-test feature is activated each time the terminal is powered on. For the most part, the test pattern on the screen cannot be viewed at initial power-up. To view the test pattern, initiate a self-test while the terminal is already "on" by entering an ESC V.

The self-test operation checks the following:

CMOS RAM (a check sum of the terminal set-up information) DATA RAM

DISPLAY RAM

ROM

VISUAL ATTRIBUTES (displays the test pattern)

Result of Terminal Self-Test

A test pattern will display, showing all character sets, visual attributes, firmware version number, and copyright information. 'If any component errors are detected, a message will display on the lower portion of the screen. Possible error messages are:

CMOS CHECKSUM ERROR DATA RAM ERROR DISPLAY RAM ERROR ROM ERROR

<!-- page 27 (OCR) -->

If any of the above error messages display on the screen:

1. 2.

Reset the terminal. Press twice.

Enter ESC V. (System will undergo another self-test procedure) .

Verify any error messages.

a. If the error message is no longer on the screen, the terminal is ready to operate.

b, If the error message still displays on the screen,

contact an Ampex service location immediately. Do not attempt to correct the problem.

2-9/2-10

<!-- page 28 (OCR) -->

<!-- page 29 (OCR) -->

## SECTION III SETTING UP

### 3.1 SET-UP Mode

Operating parameters of the Ampex 210 terminal may be selected while in the Set-Up mode. When Set-Up mode is entered, status lines containing operating default parameters will display. This chapter provides instructions for entering Set-Up mode, viewing the status lines, and selecting and saving operating parameters.

### 3.2 Entering Set-Up Mode

To enter Set-Up mode, press SHIFT/SETUP. This signals to the host computer (XOFF or DTR Low) to stop transmission. When Set-Up mode is exited, an appropriate signal (XON or DTR High) will be sent to the host computer to resume transmission.

#### 3.2.1 Viewing Status Lines

Once in the Set-Up mode, the first of five (5) status lines will appear on the 25th line of the display screen. Status lines will display in half-intensity reverse video unless the data area has been set to reverse video. In that case, the status lines will display in normal video at half-intensity. To display the next status line, press the cursor down key, This action will position the cursor at the first parameter of the next status line. Continue viewing succeeding lines in this manner.

To return to a previous status line, depress the cursor up key. This action .will position the cursor at the first parameter of the previous status line., Continue viewing preceding status lines in this manner,

#### 3.2.2 Modifying Parameters

To modify existing parameters, move the cursor to the parameter needing modification using either the cursor right key or the cursor left key. Once the cursor is at the parameter to be changed, depress the space bar (or T key) to view the various selections in the status line area. When the appropriate selection appears on the status line, go on to the next parameter.

Modified parameters are in effect as long as the terminal maintains power. Once the terminal is reset or has loss of power, these modifications will be lost. To save modifications so that they are still in effect at terminal reset and power on/off, follow the instructions provided in the following paragraphs.

<!-- page 30 (OCR) -->

##### 3.2.2.1 Saving Individual Modifications

Once the appropriate selection appears on the status line, save the selection by depressing SHIFT/S. Any of the parameters may be modified and saved in this manner except:

Protect ON/OFF Keyboard LOCK/UNLOCK Monitor mode ON/OFF Auxiliary Port ON/OFF Graphics mode ON/OFF BIDIR ON/OFF

These parameters may not be saved and will default to their original setting at power-on., Once SHIFT/S is issued, the parameter is saved and the terminal exits the Set-Up mode. The screen displayed before entering Set-Up will reappear.

##### 3.2.2.2 Saving Multiple Modifications

Multiple changes on any or all status lines may be saved as well as individual changes. To do so, make the appropriate selections on any given status line. After all selections have been made, depress SHIFT/S. This action causes all of the modified parameters of the current status lines to be saved and the terminal to exit the Set-Up mode.

Saved selections are stored in nonvolatile memory and will still be effective at power-off and power-on except for those mentioned in paragraph 3.2.2.1. To return all of the parameters to their default selections, depress SHIFT/D. This action will also cause the terminal to exit the Set-Up mode. To recall the most current "saved" selections, depress the SHIFT/R Kkey. The most recent "saved" selections will be in effect and the terminal will exit the Set-Up mode,

### 3.3 EXITING THE SET-UP Mode

The Set-Up mode is exited when Shift/Set-Up, SHIFT/S, SHIFT/R, or SHIFT/D keys are depressed. Exiting the Set-Up mode effects two reactions: the cursor returns to its original position on the screen displayed before entering Set-Up mode and a signal is sent to the host computer allowing the resumption of transmission.

<!-- page 31 (proofread) -->

### 3.4 STATUS LINE DISPLAY

Status lines consist of operational parameters and selections within those parameters. There are five different status lines (Figures 3-1 through 3-5).

#### 3.4.1 Status Line 1

Figure 3-1 illustrates the default operating parameters and corresponding selections of Status Line 1. Parameters and selections are described in Table 3-1.

**Figure 3-1. Status Line 1** (defaults on the line, other selections below each field):

```
|      | CHAR  | FDX | A210  | USA | KB ON | MON OFF | AUX OFF | NUMER | PROT OFF | GFX OFF | DSR ON  | 00:00 |
  CAPS   BLOCK   HDX   TV925   FRE   KB LK   MON ON    AUX ON    FUNCT   PROT ON    GFX ON    DSR OFF
         LINE          TV920   UK                      TPR ON
         LOCAL         T910+   GER
                       TV910   SWD
                       QT102   NOR
                       ADM5    DAN
                       VP
                       R25
                       H1500
                       H1400
```

**Table 3-1. Status Line 1**

| Default | Other | Field description |
|---|---|---|
| | CAPS | At power on, the state of the CAPS LOCK key is retrieved from the parameter LWCS/UPCS on Status Line 2. When set to UPCS, all alpha characters will display and transmit in their shifted state. The message "CAPS" will display on the status line. When LWCS is selected, alpha characters will return to their unshifted state and the "CAPS" message will no longer display. |
| CHAR | BLOCK, LINE, LOCAL | Defines the mode of communication with the host computer. If communication with a host computer is not required, select Local. |

<!-- page 32 (proofread) -->

**Table 3-1. Status Line 1 (Cont.)**

| Default | Other | Field description |
|---|---|---|
| FDX | HDX | Indicates the method of communication with a host computer. Set to FDX (full duplex) if the host computer is capable of echoing received character codes back to the terminal. Set to HDX (half duplex) if the host computer cannot echo received character codes back to the terminal. |
| A210 | TV925, TV920, T910+, TV910, QT102, ADM5, VP, R25, H1500, H1410 | Indicates the terminal model being emulated. Emulation models include TeleVideo systems, Qume system, Lear Siegler system, ADDS systems, and Hazeltine systems. Refer to Section VI for more information on emulation capabilities. |
| USA | FRE, UK, GER, SWD, NOR, DAN | The type of national character set utilized by the keyboard. Choices include: FRE – French, UK – United Kingdom, GER – German, SWD – Swedish, NOR – Norwegian, DAN – Danish. All Ampex 210 terminals are supplied with the standard U.S./U.K. keycap set. For those terminals requiring other keycap sets, refer to 4.2.2, Character Set Group, for instructions in adapting the standard keycap set to the desired national character set. |
| KB ON | KB LK | When set to LK, the keyboard becomes inoperable. |
| MON OFF | MON ON | When set to ON, monitor mode is in effect and all characters, including escape sequences and control characters, will display. |

<!-- page 33 (proofread) -->

**Table 3-1. Status Line 1 (Cont.)**

| Default | Other | Field description |
|---|---|---|
| AUX OFF | AUX ON, TPR ON | Indicates the status of the printer port. AUX OFF – data received from the host computer will be directed to the screen only. AUX ON – data received from the host computer will be directed to both the screen and the printer port. TPR ON – data received from the host computer will be directed to the printer port only. When a page print command is executed, the message "PTG" will appear here. |
| NUMER | FUNCT | Indicates the status of the numeric keypad. When set to NUMER, the unshifted state of the numerical keys will respond as numbered keys while at the same time the shifted state of the numeric keys will operate as lead-in function keys. When set to FUNCT, numeric keys will respond only as lead-in function keys. |
| PROT OFF | PROT ON | Indicates whether write-protected characters are protected. |
| GFX OFF | GFX ON | Indicates whether or not graphics mode is in effect. Applies only to Ampex 210 and Qume QT102 emulations. |
| DSR ON | DSR OFF | Indicates the state of the DCD (Data Carrier Detect). This parameter can be changed to indicate the state of the DSR (Data Set Ready) by following the instructions in Table 2-2. |
| 01:01 | | Indicates the cursor's current position on the screen (in rows and columns). |

#### 3.4.2 Status Line 2

Figure 3-2 illustrates the default operating parameters and corresponding selections of Status Line 2. Parameters and selections are described in Table 3-2.

**Figure 3-2. Status Line 2**

```
| STAT ON  | NORVID | BLK FLH | JUMP   | (blank) | LN ATB | DUPE | (blank)     | KB CLICK | KB RPT  | LWCS |
  STAT OFF   REVVID   BLK CUR   SMOOTH   ESC CR    PG ATB   LOCE   AUX/KB:KB     CLK OFF    RPT OFF   UPCS
                      UDL FLH            ESC                       AUX/KB:AUX
                      UDL CUR            STX CR
                      CUR OFF            STX
```

<!-- page 34 (proofread) -->

**Table 3-2. Status Line 2**

| Default | Other | Field description |
|---|---|---|
| STAT ON | STAT OFF | Indicates whether a status line is to be displayed during normal operation. |
| NORVID | REVVID | If REVVID is selected, the screen displays in reverse video with the status line shown in half-intensity normal video. |
| BLK FLH | BLK CUR, UDL FLH, UDL CUR, CUR OFF | Indicates the cursor configuration. Selections are: BLK FLH – cursor appears as a flashing block. BLK CUR – cursor appears as a steady block. UDL FLH – cursor appears as a flashing underline. UDL CUR – cursor appears as a steady underline. CUR OFF – no cursor will display. |
| JUMP | SMOOTH | Indicates the scrolling mode. When set to JUMP, the data is scrolled vertically on the screen as fast as it is received from the host computer. When set to SMOOTH, the data is scrolled vertically on the screen, one scan line at a time. |
| | ESC CR, ESC, STX CR, STX | Indicates the configuration of the program function key code sequences. Applies to VP and R25 emulation modes only. ESC CR – Escape; carriage return. ESC – Escape; no code. STX CR – Start of text; carriage return. STX – Start of text; no code. |
| LN ATB | PG ATB | A selection of "LN ATB" will cause any visual attribute(s) selected to affect one line. The other selection, "PG ATB", will cause the attribute(s) to affect an entire page. For example, if the attribute, underline, was activated and "PG ATB" was selected, then all data displayed on the screen (page) would be underlined. |

<!-- page 35 (proofread) -->

**Table 3-2. Status Line 2 (Cont.)**

| Default | Other | Field description |
|---|---|---|
| DUPE | LOCE | This parameter designates the communications mode of edit keys with the host computer. DUPE – codes will be transmitted to the host computer. LOCE – editing is done locally and will not transmit any codes to the computer. |
| | AUX/KB:KB, AUX/KB:AUX | Applies only to ADM5 emulation. Selection of: AUX/KB:KB – locks and unlocks the keyboard when a CTRL/N (locks) or CTRL/O (unlocks) is issued. AUX/KB:AUX – enables and disables the auxiliary port as a gating function when a CTRL/N (enables) or CTRL/O (disables) is issued. |
| KB CLICK | CLK OFF | When KB Click is designated, an electronically synthesized click sounds whenever a key is depressed. Set to "CLK/OFF" if click is not desired. |
| KB RPT | RPT OFF | Repeating keys will repeat when depressed for any length of time if KB RPT is selected. The keys will not repeat if RPT OFF is selected. Keys that will never repeat are: LOC ESC/ESC, CTRL, CAPS LOCK, BACK TAB, SHIFT, NO SCRL, FUNCT, PRINT, CLEAR/HOME, BREAK, SET UP/SEND. |
| LWCS | UPCS | Indicates the shift state of alpha keys at power up. UPCS – indicates upper case letters. LWCS – indicates the default lower case letters. If UPCS is selected, then the message "CAPS" will display in the first position of Status Line 1. |

<!-- page 36 (proofread) -->

#### 3.4.3 Status Line 3

Figure 3-3 illustrates the default operating parameters of Status Line 3. Parameters and selections are described in Table 3-3.

**Figure 3-3. Status Line 3**

```
| TIME AM 08:00 | SAV ENB | CUR 950 | SCROLL ON  | (blank)  | WRAP ON  | BELL ON  | CR=CR   |
  TIME PM 08:00   SAV OFF   CUR 920   SCROLL OFF   LEAD=ESC   WRAP OFF   BELL OFF   CR=CRLF
                                                   LEAD=HZ~
```

**Table 3-3. Status Line 3**

| Default | Other | Field description |
|---|---|---|
| TIME AM 08:00 | TIME PM 08:00 | Real time indication. At initial power on, an internal 12-hour clock will begin measuring the time of day starting at its default 08:00 AM setting. To alter this setting, press the right cursor key to the "08" (hours) setting and depress the space bar until the correct hour(s) display. To change the minutes, press the cursor right key to the "00" (minutes) setting and depress the space bar until the correct number of minutes are displayed. |
| SAV ENB | SAV OFF | If "on", this parameter activates the CRT saver feature. In other words, if the terminal is left "on" with data displayed on the screen, that data will disappear after a period of 10 minutes in order to prolong the life of the video display. Pressing any key or receiving any data from the host will cause the display to reappear. SAV OFF disables this feature. |

<!-- page 37 (proofread) -->

**Table 3-3. Status Line 3 (Cont.)**

| Default | Other | Field description |
|---|---|---|
| CUR 950 | CUR 920 | Cursor down key selection for the TeleVideo 910+ emulation mode. CUR 950 – CTRL/V moves cursor down one line. CUR 920 – CTRL/J moves cursor down one line. |
| SCROLL ON | SCROLL OFF | Indicates the terminal's scrolling status. SCROLL ON – causes all data lines to move up one line when line 24 is exceeded in order to make room for the next line. SCROLL OFF – data lines will remain stationary when data entered exceeds line 24. Exceeding data will cause cursor to return to the Home position and overwrite existing lines. |
| | LEAD=ESC, LEAD=HZ~ | Indicates the type of lead-in code affecting escape sequences. Applies to Hazeltine emulations only. |
| WRAP ON | WRAP OFF | If cursor is at column 80 and data is entered, WRAP ON will cause the cursor and exceeding data to wraparound to the start of the next line. If WRAP OFF is selected, cursor will not move at column 80. |
| BELL ON | BELL OFF | If "on", a bell sounds when the cursor reaches column 72. This feature acts as an indication of the right margin when entering data. |
| CR=CR | CR=CRLF | Indicates terminal response to a carriage return received from the keyboard or host. CR=CR – cursor will move to column 1 of the same line when a carriage return is executed. CR=CRLF – cursor will move to column 1 of the next line when a carriage return is executed. |

<!-- page 38 (proofread) -->

#### 3.4.4 Status Line 4

Figure 3-4 illustrates the default operating parameters and corresponding selections of Status Line 4. Parameters and selections are described in Table 3-4.

**Figure 3-4. Status Line 4**

```
| HOST 9600 | DTR     | AUX 9600 | BIDIR OFF | BIT 8=0 | STOP 1 | PAR OFF  | NO PAR CHK | FREQ 65 |
  19.2        DTR-XON   19.2       BIDIR ON    BIT 8=1   STOP 2   PAR ODD    PAR CHECK    FREQ 60
  50          MODEM     50                     7 BITS             PAR EVEN
  75          XON/XOFF  75                                        PAR = 1
  110                   110                                       PAR = 0
  135                   135
  150                   150
  300                   300
  600                   600
  1200                  1200
  1800                  1800
  2400                  2400
  3600                  3600
  4800                  4800
  7200                  7200
```

**Table 3-4. Status Line 4**

| Default | Other | Field description |
|---|---|---|
| HOST 9600 | 19.2, 50, 75, 110, 135, 150, 300, 600, 1200, 1800, 2400, 3600, 4800, 7200 | Indicates the rate of transmission (in bits per second) of data sent between the terminal and the host computer. |
| DTR | DTR-XON, MODEM, XON/XOFF | Indicates the transmission protocol. Selections are: DTR – Data Terminal Ready only. DTR-XON – Data Terminal Ready and XON/XOFF protocol. MODEM – Modem transmission. XON/XOFF – XON/XOFF protocol only. |

<!-- page 39 (proofread) -->

**Table 3-4. Status Line 4 (Cont.)**

| Default | Other | Field description |
|---|---|---|
| AUX 9600 | 19.2, 50, 75, 110, 135, 150, 300, 600, 1200, 1800, 2400, 3600, 4800, 7200 | Defines the rate of transmission (in bits per second) data is sent through the printer port. |
| BIDIR OFF | BIDIR ON | Indicates whether the direction of data transmission from the printer port to the host computer is enabled. If BIDIR ON is selected, the print information will be bidirectional. |
| BIT 8=0 | BIT 8=1, 7 BITS | Indicates the data word configuration and the contents of Bit 8. |
| STOP 1 | STOP 2 | Indicates the stop bit configuration. |
| PAR OFF | PAR ODD, PAR EVEN, PAR=1, PAR=0 | Indicates the type of parity applicable to each data word. |
| NO PARCHK | PAR CHECK | If the terminal, when receiving a data word, requires a parity check for compatibility with the host computer, select PAR CHECK. |
| FREQ 65 | FREQ 60 | Indicates the refresh rate of the terminal. Select: FREQ 65 – when the terminal being operated is in a 50 Hz line power area (eliminates flicker and ambient magnetic field interference). FREQ 60 – when the terminal being operated is in a 60 Hz line power area. |

<!-- page 40 (proofread) -->

#### 3.4.5 Status Line 5

Figure 3-5 illustrates the default operating parameters and corresponding selections of Status Line 5. Parameters and selections are described in Table 3-5.

**Figure 3-5. Status Line 5**

```
| HEOL -^_ | HEOM -^M | AEOM -^F | HERE IS -                                  |
```

**Table 3-5. Status Line 5**

| Default | Other | Field description |
|---|---|---|
| HEOL = ^_ | | Indicates the host's end of line terminator. The default setting is a US (unit separator, 1FH Hex). Any two characters may be entered. |
| HEOM = ^M | | Indicates the host's end of message terminator. The default setting is a CTRL/M (carriage return). Any two characters may be entered. |
| AEOM = ^F | | Indicates the auxiliary port's end of message terminator. The default setting is CTRL/F (ACKnowledge). Any two characters may be entered. |
| Here Is = | | This is a 20-character field available to the operator for entering a message that specifically identifies a particular terminal to the host computer. In this field, the first key entered and the last key entered must be the same characters in order to act as message delimiters (delimiters are not transmitted or displayed). Use a cursor key to exit this field before performing a Save function. Issuing a CTRL/E will cause the message to be transmitted to the host computer. |

<!-- page 41 (OCR) -->

## SECTION IV TERMINAL CONTROLS

### 4.1 DISPLAY UNIT CONTROLS

There are two operator controls located on the exterior of the video display unit: the power switch and the intensity control dial.

#### 4.1.1 Power Switch

The power switch is located to the right and towards the back of the unit when facing the screen., The switch is a rocker-type, and is designed to be operated by touch. A short time after the power is switched on, an alarm (beep) will sound indicating the completion of the self-test, the cursor will appear on the screen (unless cursor off was selected in Set-Up mode) at the Home position and the unit will be ready for use.

#### 4.1.2 Intensity Control Dial

The intensity control dial is positioned underneath the right-hand portion of the screen. Adjust the intensity when sufficient video is displayed on the screen to establish the most comfortable level of intensity/ contrast.

CAUTION

Do not leave intensity at a high level for long periods of time; to do so may wear the phosphor-coated screen unnecessarily. The CRT Saver Circuit, which 1is operator selectable while in the Set-Up mode, blanks the display of on-screen information after a period of about 10 minutes, if the terminal is turned on but is not being used.

### 4.2 KEYBOARD CONTROLS

Keyboard controls, as shown in Figures 4-1 and 4-3, through 4-6, can be divided into five groups: Character Sets, Numeric Keypad, Cursor Control Keys, Edit Keys, and Control keys.

#### 4.2.1 Lock and Unlock

The keyboard may be disabled by a command issued from the keyboard or host computer and enabled from the host computer. For:

<!-- page 42 (OCR) -->

Keyboard Lock = Enter Set-Up mode and select KB LK on Status Line 1 or receive an ESC # from the host computer.

Keyboard Unlock - ESC " from the host computer will enable keyboard operation, 1In addition, there are two ways of unlocking the keyboard from the keyboard.

1. Reset the terminal to its default unlock setting.

Depress

2. Return to Set-Up mode.

~Depress

The keyboard automatically returns to its default setting of KB ON,

During print and send operations, the keyboard will remain locked until the operations are complete with the exception.that Set-up mode may be entered and parameters changed. After exiting Set-up, the keyboard resumes its locked state until completion of the print or send command. ’

4,2.2 Character Set Group The Character Set group contains alphabetic, numeric, and special

symbol keys whose functions and arrangements are similar to those of an IBM Selectric III typewriter (Figure 4-1).

AMPEX 210

Figure 4-1. Standard (United States/United Kingdom) Character Set

<!-- page 43 (OCR) -->

In addition to the standard Character Set group, United States/United Kingdom, any one of five national character sets may

be selected when in Set-Up mode. These national character sets are German, French, Swedish, Norwegian, and Danish (refer to Appendix D).

When using one of the optional national character sets, remove and replace keycaps properly using the keycap remover provided by Ampex (Part No, 074-297) in each character set kit or use an equivalent device (Figure 4-2). Position replacement keycaps and snap in place by hand. The optional national character sets illustrated in Appendix D identify the correct location of replacement keycaps.

Appendix D also provides hexadecimal codes and a comparison of special symbols for the national character sets (Figure D-6),

T$§

Vo

A - . | Swe \

5783

Figure 4-2. Keycap Remover

<!-- page 44 (OCR) -->

#### 4.2.3 Numeric Keypad Group

The keys constituting the Numeric Keypad Group are shown in Figure 4-3, All keys function identically to their counterparts in the Character Set and Edit Keys Groups while in the (Numer)ic mode. If in the Funct (function) mode, numeric keys will respond only as

function lead-in keys (refer to paragraph 5.6 for more information concerning the Function Key modes).

AMPEX 210

GEEEE

= ]

5 L

Figure 4-3, Numeric Keypad Group

When Numeric keypad is enabled, the keys generate'codes for numbers, 0 through 9, period, comma, minus, and Enter. In their shifted

state, these keys act as program function keys and send a threecharacter code to the host computer. ‘

The numeric keypad may be enabled either as a program function keypad or as a numeric keypad by toggling, ESC c, or by making the appropriate selection in Set-Up mode.

<!-- page 45 (OCR) -->

#### 4.2.4 Cursor Control Keys Group

The keys in this group dictate the cursor movement on the display page (Figure 4-4). Table 4-1 provides a cursor movement guide.

AMPEX 210

Figure 4-4, Cursor Control Keys Group

##### 4.2.4.1 BACK TAB Key

Depression of the

key generates an ESC I to return the cursor

to the previous tab stop’when Protect mode is off or to the start of

the previous unprotected field when Protect mode is on.

If there are no previous tab stops (when Protect mode is off) the

cursor returns to column 1 of the same line.

##### 4.2.4.2 TAB Key

When depressed, the key moves the cursor forward to the next tab stop when Piotec; moée is off or to the first character of the next unprotected field when Protect mode is on. The cursor will not move if no tab stops are set or if the cursor is on the last tab

position. This key generates a CTRL/I code.

<!-- page 46 (OCR) -->

##### 4.2.4.3 BACK SPACE Key

When depressed, the ’ %key causes the cursor to move backward one

column. If>the»cur§or\is at the first position on a line, fhe cursor will move to the.last position of the preceding line. If the cursor is at the home position when the Back Space key is depressed, the cursor will move to the last column of line 24 if Auto Scroll is disabled and will cause no cursor movement if Auto Scroll is’

enabled. This kéy genérates a CTRL/H code.

##### 4.2.4.4 HOME Key

The unshifted state of theg key causes the cursor to return to

the first position of the display page when Protect Mode is off and to the first unprotected position of the display page when Protect

Mode is on. When depressed, this key generates a CTRL/" code,

##### 4.2.4.5 RETURN Key

When depressed, the . i key causes the cursor to return to the firstﬂunprotected»posifiqn'of-the'same'line when auto line feed is disabled. When auto line feed is enabled, the cursor moves to the first position of the next line or the first unprotected position of-

the next line. If that entire line is protected, the cursor will

move to the next ﬁnprotectedbposition on the display page.

<!-- page 47 (OCR) -->

The local action of this key is dependent on which operating mode is selected. For example, if auto scroll is enabled, a CRLF’(carriage return line feed) activated while on the 24th line will cause the screen to‘scroll up one line. If auto scroll is disabled, then a CRLF while on the 24th line will cause the cursor to return to the first unprotected position on the currentbdisplay page with no

scrolling taking place. This key generates a CTRL/M.

##### 4.2.4.6 LINE FEED Key

key causes the cursor to descend one line. If the cursor

The

is on line 24 and auto scroll is enabled, then depression of this key causes the screen to scroll up one line. If the cursor is on line 24 and auto séroll is disabled, then depression of this key cauéesrthe cursor to return to line 1 of the current screen with no

scrdlling taking plaqg. This key generates a CTRL/J .

4.2.4,7

4] Key (Down Cursor)

The

key causes the cursor to descend one line. If the cursor

is on line 24, then depression of this key will cause no movement.

This key generates a CTRL/V.

<!-- page 48 (OCR) -->

4.2.4.8 When depressed, the key causes the cursor to move up one line (in the same column). When 11ne 1 1s reached, the cursor will not

move.: This key generates a CTRL/K.

4.2.4.9

Key (Left Cursor)

i key responds in the same manner as the BACK SPACE key

(4.2.4.3) and also generates a CTRL/H.,

to the right. If the cursor is at the last column on a line, it

w111 move to the flrst posn:lon of the next line if wraparound is on or 1t w1ll not move if wraparound is off. If the cursor is posrtloned at the last column of line 24 and auto scroll is on, the screen w1ll scroll up one line and the cursor w111 move to the flrst position of the new line. This key generates a CTRL/L code. If auto scroll is off, the cursor will return to the home position with no

scrolling taking place.

<!-- page 49 (OCR) -->

Table 4-1., Cursor Conttol Keys Movement Guide

L

Command Code

Mode

Cursor Movement

CTRL/I

CTRL/"

CTRL/H

ESC I

Protect

Protect

Protect

Protect

Protect

Protect

Auto Scroll Off

Auto Scroll On

Mode On

Mode Off

Mode On

Mode Off

Mode On

Mode Off

Cursor returns to the start of the previous unprotected - field. : ,

Cursor returns to a previous tab stop or to column 1 of the current line if there are no previous tab stops.

Cursor moves forward to next unprotected field.

Cursor moves forward to next tab stop or remains stationary if there are no tab stops.

Cursor returns to first unprotected £field on screen display.

Cursor returns to Column 1, Line 1 (first position) on screen display.

Cursor moves backward one space., If cursor is at Column 1 of a line, it will move to the last position on previous line, '

If at Home position, cursor. will move to the 1last position of line 24,

If at Home position, cursor will not move.

<!-- page 50 (OCR) -->

Table 4-1.

Cursor Control Keys

Movement Guide (Cont.)

Command Code

Mode

Cursor Movement

CTRL/M

CTRL/J

CTRL/Y

Auto Linefeed On Protect Mode On

‘Auto Linefeed On Protect Mode Off

Auto Linefeed Off Protect Mode On

Auto Linefeed Off Protect Mode Off

Auto Scroll On Auto Linefeed On

Auto Scroll Off Auto Linefeed On

Auto Scroll On

Auto Scroll Off

Cursor moves to first unprotected position of the next line, If next line is protected, cursor moves to the next unprotected position on screen display.

Cursor moves to the first position of the next line.

Cursor returns to first unprotected position of the same line. If that line is protected,cursor will move to the next unprotected position on the screen display.

Cursor returns to the first position of the same line.

Screen will scroll up one line if cursor is on line 24 and a carriage return is executed.

Cursor returns to the Home position with no scrolling taking place.

Cursor descends one line at the same vertical column,

Screen scrolls up one line, if cursor was on 1line 24. Cursor is positioned on the new line 24,

Cursor returns to line 1 of the current screen. No scrolling takes place.’

Cursor descends one line at the same vertical column. If on line 24, the cursor will not move.

<!-- page 51 (OCR) -->

Table 4-1, Cursor Control Keys Movement Guide (Cont.)

Command Code Mode Cursor Movement CTRL/K Cursor moves up one line. CTRL/H Same as Back Space key. CTRL/L Cursor moves one position to the right. Wraparound If at last position of line,

cursor moves to the first position of the next line.

Wraparound Off If at last position of line,

cursor will not move. Auto Scroll On If at last position of 1line Wraparound On 24, screen scrolls up one

line, and cursor moves to .the first position of the new

line. Auto Scroll Off If at last position of line Wraparound On 24, cursor returns to the

Home position with no scrolling taking place.

#### 4.2.5 Edit Keys Group

Thé keys in the Edit group are primarily used to alter the display of text and data., The following paragraphs. will present these keys and give a description of their functions. Figure 4—5 will show the

location of these keys on the keyboard.

<!-- page 52 (OCR) -->

AMPEX 210

L

Figure 4-5. Edit Keys Group

4.2.,5.1 SHIFT Key:

When used with another key, the j key causes the shifted state

of the other key to be activated. The key must be depressed

first and then held down during depression of the second key.

##### 4.2.5.2 CAPS LOCK Key

The key toggles the alphabetic keys into and out of the shifted

state.-When activated, this key causes alphgbetic keys to display in their upper-case state and the message "CAPS" to appear in half

intensity at the bottom left-hand corner of the screen.

<!-- page 53 (OCR) -->

##### 4.2.5.3 DELETE CHAR Key

The shifted state of the - key deletes the characte; at the cursor position and causes the remaining_characters on the line to move one position to the left. A space character is written to the

last position on the line,

When Protect mode is on, character delete operates only from the

cursor position to the end of the first unprotected field or line,

This action generates an ESC W.

##### 4.2.5.4 INSERT CHAR Key

The unshifted state of the ke_y causes all characters at and to the right of the cursor tb mové one column to the right. This action enters a space charécter at the cursor position. The character at

column 80 is lost,

If protect mode is on, character insert operates from the cursor

position to the end of the line or to the first protected field.

This action generates an ESC Q.

##### 4.2.5.5 DELETE LINE Key

The shifted state of the key deletes the entire line the cursor

is positioned on, All remaining lines move up one line. The cursor

will move to column 1 of the replaced line and Space'characters will be added to the last line of the screen. This functibn has no

effect when Protect mode is on.

This action generates an ESC R.

<!-- page 54 (OCR) -->

##### 4.2.5.6 INSERT LINE key

The unshifted state of thefmrﬂ key causes a line to be inserted consisting of spaces at the cursor positon. This action moves the cursor to the start of the new line and all remaining lines down one

line, resulting in the loss of the last line of the SCréen.

When Protect mode is on, this command has no effect.

This action generates an ESC E.

##### 4.2.5.7 ERASE PAGE Key

The shifted state of the %@%‘key causes all unprotected characters starting from the cursor position to the endAof the page, to disappear'frbm tHe'screeh'and beireplacéd with spaces if Pfotect mode is on. If Protect mode is off, all characters starting fromthe:éurSOr'posiﬁion to the end of the page will disappear from the

sCreen,

If the half intensity attribute is on, the characters are replaced

with half intensity spaces, This action generates an ESC Y,

##### 4.2.5.8 ERASE LINE Key

The unshifted state\of the Kesti key causes all unprotected characters, starting;from the cursor-poéition\to the end of the ling,,tpibeheraged_fxom,the screen if protect mode is on. If protectjmgdekis off, all characters, starting from the cursor

position to the end of the line, will be erased. - Space characters

<!-- page 55 (OCR) -->

will replace erased characters. If half intensity is enabled, the

characters are replaced with half intensity spaces. - This action‘génerates an EsC T,

4.,2,6 Control Keys Group The keys in this group perform special control functions (Figure

4"6) »

——

A

AMPEX 210

Figure 4-6, Control Keys Group

##### 4.2.6.1 PRINT Key

When depressed, the key causes the terminal to transmit, to a

printer, all characters from the Home position to and including the

current cursor position.

This key generates and ESC P,

<!-- page 56 (OCR) -->

##### 4.2.6.2 FUNCT Key

When the key is depressed first and then held down in -

conjunction'with another alphanumeric key, a three-character code sequence is transmitted (e.g., "FUNCT/6" will transmit SOH 6 CR

[carriage return]).

##### 4.2.6.3 CTRL Key

The (control) key is used as a prefix for control codes

initiated at the terminal, To implement a control code, press and

hold the

| key while pressing the key corresponding to the

desired function,

For a listing of control codes and escape sequences, refer to

.Appendix A or B,

##### 4.2.6.4 ESC Key

‘The unshifted state of the ; key is used as a prefix for escape

sequences initiated at the termina1 to allow the user to momentarily leave a program and perform a specific function. To implement an escape sequence at the terminal,; press and.release the ESC key. Then

press the key corresponding to the desired function.

Depressing the ESC key also causes the nextlpontrolrcharacter‘” entered to.be displayed without having to enter the monitor: mode. For a listing of escape sequences and control codes, refer to

Appendix A or B.

##### 4.2.6.5 LOC ESC Key

The shifted state of the key causes local action only of

escape sequences,

<!-- page 57 (OCR) -->

##### 4.2.6.6 CLEAR Key

The shifted state of the i

key generates the control code for clear unprotected to the space character. (CTRL/Z).

##### 4.2.6.7 BREAK Key

When the {key is pressed in conjunction with the CTRL key, a

nondisplayable standard teletypewriter signal (a 250 millisecond break pulse) is transmitted to the host computer. Depressing the SHIFT key first and holding it down, then depressing the BREAK key

twice will cause the terminal to reset.

The

key transmits a nondisplayable ASCII delete code to the

host computer. Display memory is unaffected.

##### 4.2.6.9 SETUP Key

Depression of the shlfted state of the key toggles the terminal

in and out of Set-Up mode. The Set-Up mode consists of a series of parameter~selectable status lines (refer to Section III; Setting

up) .

##### 4.2.6.10 SEND Key

When depressed, the unshifted state of the [jzfll key causes

unprotected blocks (in Block mode) or lines (in Line mode) to be sent to the host computer. The SEND key is effective only in Block

or Line mode.

<!-- page 58 (OCR) -->

##### 4.2.6.11 NO SCRL Key

When depressed, the key toggles the host computer to stop

scrolling the screen (i.e., transmitting characters to the terminal). A second depression of this key signals the host computer

to resume scrolling.

<!-- page 59 (OCR) -->

## SECTION V OPERATION

### 5.1 USING THE OPERATING MODES

This section describes the various operating modes of the Ampex 210 terminal.

#### 5.1.1 Full Duplex Conversational Mode (FDX)

In full duplex mode, all escape sequences, control codes, and data entered at the keyboard are sent to the host computer only. To select this mode, enter Set-Up mode and make the appropriate selection,

#### 5.1.2 Half Duplex Conversational Mode (HDX)

This mode is the conversational alternative to full duplex mode. When in half duplex mode, all escape sequences, control codes, and data entered at the keyboard are sent to the display screen and host computer simultaneously. Half duplex mode may be selected while in Set~-Up mode,

#### 5.1.3 Character Mode

This operating mode provides for entry of data from the keyboard and for transmission of each character as it is received from the keyboard to the host computer.

The display of data as it is received from the keyboard will depend on what conversational mode is selected; i.e., full or half duplex.

To change this mode to another mode (block, line, or local) enter Set-Up mode and make the appropriate selection. Character mode may also be enabled with an ESC C,

#### 5.1.4 Block Mode

When in Block mode, data is entered from the keyboard to the terminal display without immediate transmission to the host computer. It is entered in a protected format displayed on the screen, edited, and then transmitted in entirety or in unprotected parts only to the host computer.

Block mode may be selected while in Set-Up mode or enabled with an ESC B. To disable Block Mode, enter Set-Up mode and make another selection.

<!-- page 60 (OCR) -->

#### 5.1.5 Line Mode

Line mode operates in the same manner as Block mode except that only the contents of the line, on which the cursor is positioned,are transmitted.

This mode may be selected while in Set-Up mode or enabled with an ESC D. To disable Line mode, enter Set-Up mode and make another selection.

#### 5.1.6 Local Mode

Local mode provides for the local execution of terminal functions. In this mode, transmission of data and commands between the terminal and the host are prohibited.

This mode is enabled and disabled via the Set-Up mode.

#### 5.1.7 Write Protect and Protect Modes

These modes allow the user to designate certain areas on the screen in half-intensity and to later protect them from change and transmission during operator input.

##### 5.1.7.1 Write Protect Mode

When this mode is set, each written character will appear in halfintensity, designating a protected area, and when Protect mode is enabled, the cursor is prevented from entering the protected area. Write Protect is entered with an BSC ) [before entering information] and is disabled with an BESC ( [after entering information].

##### 5.1.7.2 Protect Mode

This mode protects designated character positions (those positions written while in Write Protect mode). Protect mode is enabled while in the Set-Up mode or with an ESC & and can be disabled while in the Set-Up mode or with an BSC °,

#### 5.1.8 Monitor Mode

Monitor mode permits the display of all characters, without interpretation, including all escape sequences and control characters. This mode may be enabled when in the Set-Up mode or by a CTRL/1 and disabled in the Set-Up mode or by a CTRL/2,

For a listing of Monitor mode facsimile characters, refer to Appendix F,

<!-- page 61 (OCR) -->

### 5.2 EDITING MODES AND COMMANDS

The following paragraphs describe the editing modes and commands available on the Ampex 210 terminal.

#### 5.2.1 Local Edit Mode

Local edit mode may be enabled while in the Set-Up mode or with an ESC k. When set to local edit mode, the following keys will affect only the display page (they are not transmitted to the host computer) :

o) Back Space o Back Tab

o] Cursor Up. o Erase Line

o Cursor Down o Erase Page

o Cursor Left o Insert Character o Cursor Right 0 Delete Character o] Tab o Insert Line

o Home o Delete Line

#### 5.2.2 Duplex Edit Mode

Duplex edit mode may be enabled while in Set-Up mode or with an ESC 1l (lower case L), When set to duplex edit mode, those edit keys indicated in paragraph 5.2.1 will operate in the same manner as the alphanumeric keys (they will be transmitted to the host computer).

#### 5.2.3 Edit Commands

The following paragraphs contain descriptions of the various edit commands available to the user.

##### 5.2.3.1 Character Insert

This command may be executed either by depressing the CHAR INSERT key or by issuing an ESC Q. Execution of this command causes all characters at and to the right of the cursor to move one column to the right while inserting a space character at the cursor position. The character at column 80 is lost.

If Protect mode is on, this command will insert from the cursor

position to the end of the line or to the start of the first protected field.

<!-- page 62 (OCR) -->

##### 5.2.3.2 Character Delete

This command may either be executed by depressing the SHIFT DELETE CHAR keys or by issuing an ESC W. Execution of this command will delete the character at the cursor position and move the remaining characters of that same line one position to the left. At the end of the delete function, a space character will be written to column 80 of that line.

If Protect mode is on, character delete operates only from the cursor position to the end of the first unprotected field or line.

##### 5.2.3.3 Line Insert

This command may either be executed by depressing the LINE INSERT key or by issuing an ESC E, This action inserts a line consisting of space characters at the cursor position. The result of this command causes the cursor to move to column 1 of the inserted line. This command has no effect when protect mode is on.

##### 5.2.3.4 Line Delete

To execute a line delete command either depress the SHIFT/DELETE LINE keys or issue an ESC R, This action will delete the line the cursor is positioned on and move the remaining lines on the screen up one line,

At the completion of this command, the cursor will move to column 1 of the line replacing the deleted line and spaces will be written to the last line of the screen.

This command has no effect when protect mode is on.

##### 5.2.3.5 Erase To End of Line

Erasing to the end of the line with spaces (ESC T) erases all unprotected characters from the cursor position to the end of the line and replaces them with space characters. If protect mode is on, only those characters from the cursor position to the first protected field are erased. 1If half-intensity is on, then halfintensity spaces replace the erased characters.

Erasing to the end of the line with nulls (ESC t) erases all unpzr otected characters starting from the cursor position to the end of the line and replaces them with null characters. If halfintensity is enabled, then half-intensity null characters will replace erased characters. If protect mode is on, only those characters starting from the cursor position to the end of the unprotected field are erased and then replaced with nulls.

<!-- page 63 (OCR) -->

NOTE

When the terminal is in the Qume QVT 102 emulation mode, all characters protected and unprotected, are erased with this command.

##### 5.2.3.6 Erase To End of Screen

Erasing to the end of a screen with spaces (ESC Y) erases unprotected characters (Protect mode On), starting from the cursor position to the end of the screen and replaces those characters with spaces. When Protect mode is off, all characters, starting from the cursor position to the end of the screen, are erased, If halfintensity is on, erased characters are replaced with half-intensity space characters,

Erasing to the end of a screen with nulls (ESC y) erases all unprotected characters, starting from the cursor position to the end of the screen, and replaces them with null characters., If halfintensity mode is on, then half-intensity null characters will replace erased characters.

NOTE

When terminal is in the Qume QVT 102 emulation mode, all characters are erased, not just unprotected characters.

### 5.3 CLEAR FUNCTIONS

Clear functions are used to clear data from the display and/or the host computer memory. Since some of the clear commands during TeleVideo emulation and Qume emulation do not always correspond,

a summary of those clear commands is shown in Table 5-1,

<!-- page 64 (OCR) -->

Table 5-1. Summary of Clear Commands

Emulation Mode

Command A210 TV925 TV920 |TV910+ TVI10 QVvVT102

CLEAR UNPROTECTED TO NULLS ESC: ESC: ESC: ESC: ESC:

CLEAR UNPROTECTED TO SPACES ESC; ESC; ESC; CTRL/Z| ESC+ CTRL/ 2

CLEAR ALL ESC* ESC* ESC* ESC* ESC* ESC* TO NULLS

CLEAR ALL ESC+ ESC+ TO SPACES ESC+ CTRL/Z CTRL/Z

CLEAR UNPROT TO HALF INTENSITY SPACES ESC, ESC, ESC,

CLEAR ALL TO HALF- ESC, INTENSITY SPACES

CLEAR UNPROT TO ESC; ESC; INSERT ESC+ ESC+ CHARACTER CTRL/Z |CTRL/Z (DEFAULT = SPACE)

### 5.4 SEND COMMANDS

There are six send commands available to the operator. These commands cause data to be transmitted from the display terminal to the host computer.

#### 5.4.1 Send Line Unprotected

This command causes all unprotected characters from column 1 to and including the cursor position to be transmitted. Send line unprotected is initiated by an BESC 4 or by depressing the SEND key while in Line mode. The result of this action sends an FS code (1C Hex)

<!-- page 65 (OCR) -->

The cursor must be positioned somewhere on the line being transmitted.

#### 5.4.2 Send Line All

This command causes all data,from column 1 to, and including, the cursor position to be transmitted. This action is initiated by an ESC 6. This command also sends an ESC ), denoting the beginning of a protected field and an ESC (, denoting the end of a protected field. At the end of transmission, an end-of-message character will be ~sent. The result of this command causes attribute characters, as applicable, to be sent (the terminal automatically inserts the correct escape sequences) to the host computer.

The cursor must be positioned somewhere on the line being transmitted.

#### 5.4.3 Send Page Unprotected

This command causes all unprotected characters from the Home position to, and including, the cursor position to be transmitted. Send page unprotected is initiated by an ESC 5 or by depressing the SEND key while in Block mode. This command also sends an FS code (1C Hex) as a field delimiter in place of each protected field, an end-of-line character at the end of each line, and an end-of-message character at the end of the transmission.

#### 5.4.4 Send Page All

This command causes all data, protected and unprotected, from the home position to, and including, the cursor position to be transmitted. This action is initiated by an ESC 7. This command also sends an ESC ), denoting the beginning of a protected field and an ESC (, denoting the end of a protected field. This command also sends an end-of-line character at the end of each line, and at the end of transmission an end-of-message character is sent.

#### 5.4.5 Send UNPROTECTED Message

This command (ESC S) causes all unprotected data, bracketed by start of text (STX) and end of text (ETX) codes displayed on a screen, to be transmitted. After transmission, the cursor will be positioned after the ETX Code. If the screen contains no STX codes, transmission will begin from the Home position. If the screen contains no ETX codes, the terminal will transmit data to the end of the screen and the cursor will return to the Home position after the data is sent. If there are neither STX nor ETX codes, the entire screen will be transmitted.

<!-- page 66 (OCR) -->

This command sends an FS code (1C Hex) as a field delimiter in place of protected fields. It also sends an end-of-line character at the

end of each line and an end-of-message character at the end of transmission.

#### 5.4.6 SEND ENTIRE Message

This command, initiated by an ESC s, is similar to sending an unprotected message except that protected fields are also transmitted.

#### 5.4.7 Terminator Character Selection

The terminal transmits delimiters (terminator characters) at the end of each transmitted line and at the end of text upon completion of each send command. Both line and page terminators are stored in nonvolatile memory and are not affected by power on/off transmission,

##### 5.4.7.1 Line Terminator (Or End-Of-Line Character)

At the end of each transmitted line, a US (1FH Hex) is sent. This delimiter may be changed while in Set-Up mode or by entering an ESC x 1 NN (where NN is any two ASCII characters). The second character

may be a null used as a filter code. For example, to change US to ETX, enter:

ESC x 1 CTRL/C (ETX) and CTRL/€ (null)

##### 5.4.7.2 Page Terminator (Or End-Of-Message Character)

At the end of each transmitted page of text, a CR (carriage return)

is sent. This delimiter may be changed while in Set-Up mode or for: Ampex 210 and TeleVideo Emulation — Enter ESC x 4NN

(where NN is any two ASCII characters).

Qume QVT 102 Emulation - Enter ESC x N (where N is any ASCII character).

<!-- page 67 (OCR) -->

### 5.5 TABULATION

Cursor movement to designated areas on the screen may be initiated using the TAB and BACK TAB keys. There are two types of tab stops: column and field. Column tab stops are applicable only when protect mode is off and field tab stops are applicable only when Protect mode is on.

#### 5.5.1 TAB Key

The TAB key (CTRL/I) moves the cursor forward to the next fab stop.

##### 5.5.1.1 Protect Mode OFF

With Protect mode disabled the TAB key moves the cursor to the right to the next column tab stop. If no tab stops are set or if the cursor is on the last tab position, the cursor will not move.

##### 5.5.1.2 Protect Mode ON

The TAB key moves the cursor to the first unprotected positon following a protected field.

When protect mode is enabled, ESC 1 generates a vertical column of half-intensity spaces from the cursor position down the display column to the first write protected character or to the end of the page whichever comes first.

#### 5.5.2 BACK Tab

The BACK TAB key (ESC I) moves the cursor backward to a previous tab stop.

##### 5.5.2.1 Protect Mode OFF

When protect mode is off, the BACK TAB causes the cursor to go back to the previous tab position. If no tabs were set, or if the cursor is on the first tab position, the cursor will return to column 1 of the 1line.

##### 5.5.2.2 Protect Mode ON

When protect mode is on, the BACK TAB key moves the cursor back to

the start of the preceding unprotected field. If no unprotected fields precede the cursor's position, the cursor will not move.

<!-- page 68 (OCR) -->

#### 5.5.3 Setting Tab Stops

Columnar tab stops (or typewriter tab stops) are set (when protect mode is off) by positioning the cursor at the desired column and then executina an ESC 1 from the keyboard or host.

The default tab stops at power-on are set at every eighth column, i.e., columns 8, 16, 24, 32, etc. To change these tab stops:

l. Clear all the default tab stops. Enter: BSC 3. (To clear individual tab stops, position the cursor at the applicable tab stop and enter ESC 2).

2., Position the cursor at the desired locations on the line and enter: ESC 1.

3. Enter Set-up Mode.

4, Execute a SHIFT/S to save the new tab stop(s) in nonvolatile memory. This action causes the new tab stop(s) to be in effect at power on.

Note: Tab stops cannot be cleared when protect mode is on.

#### 5.5.4 Clearing Tab Stops

Columnar tab stops may be cleared when protect mode is off. ESC 2 clears a single tab stop. ESC 3 clears all tab stops.

### 5.6 Function Key Modes

There are two function key modes available to Ampex 210 operators and there are fourteen function key codes in all., 1In addition, some terminal emulations allow use of the function key modes:

Function Key Mode - For use with Ampex 210, TeleVideo 910+, 920, and 925 emulations,

Program Function Key Mode - For use with Ampex 210, TeleVideo 920, 925, and Qume QVT 102 emulations.

"FUNCT" Key with Numeric Keypad Mode - For use with TeleVideo 910 emulation only.

<!-- page 69 (proofread) -->

#### 5.6.1 Function Key Mode

Using the FUNCT (Function) key in combination with another key enables transmission of a three-character sequence of commands.

To enter a function key command, press the FUNCT key and at the same time press another key. The first character which is transmitted will always be SOH (Control A). The second will be the ASCII character of the depressed key. The third character will always be a CR.

#### 5.6.2 Program Function Key Mode

The program function key mode allows the operator to use the numeric keypad as function keys. To enable this mode, enter Set-Up mode and make the appropriate selection, or enter an **ESC c**. (Entering another **ESC c** will return the terminal to the numeric mode.)

While in the Program (Funct)ion Key mode, unshifted numeric keys will transmit the codes listed in Table 5-2. If the terminal is in (Numer)ic mode, shifted numeric keys will operate as Function keys.

#### 5.6.3 "FUNCT" Key with Numeric Keypad Mode

This mode allows the operator to use the numeric keypad with the FUNCT key as function keys (Table 5-3).

**Table 5-2. Function Key Code Sequences**

| Function key | Numeric keypad key | Transmitted: TV920, TV925 | Transmitted: QVT102 |
|---|---|---|---|
| F1 | 1 | SOH @ CR | SOH @ CR |
| F2 | 2 | SOH A CR | SOH A CR |
| F3 | 3 | SOH B CR | SOH B CR |
| F4 | 4 | SOH C CR | SOH C CR |
| F5 | 5 | SOH D CR | SOH D CR |
| F6 | 6 | SOH E CR | SOH E CR |
| F7 | 7 | SOH F CR | SOH F CR |
| F8 | 8 | SOH G CR | SOH G CR |
| F9 | 9 | SOH H CR | SOH H CR |
| F10 | 0 | SOH I CR | SOH I CR |
| F11 | . (period) | SOH J CR | SOH J CR |
| F12 | ENTER | SOH \` CR | SOH \` CR |
| F13 | , (comma) | SOH a CR | SOH a CR |
| F14 | - (minus) | SOH b CR | SOH b CR |

<!-- page 70 (proofread) -->

**Table 5-3. TeleVideo 910 "FUNCT" Key Code Sequences**

| Lead-in key | Numeric keypad key | Code sequence transmitted |
|---|---|---|
| FUNCT | 0 | SOH @ CR |
| FUNCT | 1 | SOH A CR |
| FUNCT | 2 | SOH B CR |
| FUNCT | 3 | SOH C CR |
| FUNCT | 4 | SOH D CR |
| FUNCT | 5 | SOH E CR |
| FUNCT | 6 | SOH F CR |
| FUNCT | 7 | SOH G CR |
| FUNCT | 8 | SOH H CR |
| FUNCT | 9 | SOH I CR |

#### 5.6.4 ADDS Regent 20/25 and Viewpoint Program Function Key Mode

The ADDS Regent 20/25 and ADDS Viewpoint A1 and A2 emulations also utilize the Program Function Key mode. Tables 5-4 and 5-5 show the various code sequences transmitted for these emulations.

**Table 5-4. ADDS Regent 20/25 Program Function Key Codes**

| Function key | Numeric keypad key | Lead-in code | ASCII code | Terminator code |
|---|---|---|---|---|
| F1 | 1 | STX or ESC | 1 | CR or No Code |
| F2 | 2 | STX or ESC | 2 | CR or No Code |
| F3 | 3 | STX or ESC | 3 | CR or No Code |
| F4 | 4 | STX or ESC | 4 | CR or No Code |
| F5 | 5 | STX or ESC | 5 | CR or No Code |
| F6 | 6 | STX or ESC | 6 | CR or No Code |
| F7 | 7 | STX or ESC | 7 | CR or No Code |
| F8 | 8 | STX or ESC | 8 | CR or No Code |
| F9 | 9 | STX or ESC | 9 | CR or No Code |
| F10 | 10 | STX or ESC | . | CR or No Code |
| F11 | . (period) | | CR | |
| F12 | ENTER | STX or ESC | , | CR or No Code |
| F13 | , (comma) | | - | |
| F14 | - (minus) | | | |

*Transcriber's note: rows F10–F14 are reproduced as printed; the ASCII codes appear shifted by one row relative to the keys.*

<!-- page 71 (proofread) -->

**Table 5-5. ADDS Viewpoint A1 and A2 Program Function Key Codes**

| Function key | Numeric keypad key | Code sequence transmitted |
|---|---|---|
| F1 | 1 | STX 1 |
| F2 | 2 | STX 2 |
| F3 | 3 | STX 3 |
| F4 | 4 | STX ! |
| F5 | 5 | STX " |
| F6 | 6 | STX # |

### 5.7 VISUAL ATTRIBUTE SYSTEM

The Ampex 210 visual attributes provide reverse video, half-intensity, underline, flash, and blank. The attribute characters are normally displayed as a space on the screen. They also appear as a half intensity space on a reverse video background.

Attributes are implemented with an ESC G sequence followed by a parameter. Table 5-6 lists the attributes, possible combinations, and their respective escape sequences.

**Table 5-6. Visual Attributes and Escape Sequences**

| Attribute(s) | Escape sequence |
|---|---|
| Normal | ESC G0 |
| Blank | ESC G1 |
| Flash | ESC G2 |
| Invisible Flash | ESC G3 |
| Reverse Video | ESC G4 |
| Invisible Reverse | ESC G5 |
| Reverse Flash | ESC G6 |
| Invisible Reverse Flash | ESC G7 |
| Underline | ESC G8 |
| Invisible Underline | ESC G9 |
| Underline Flash | ESC G: |
| Invisible Underline Flash | ESC G; |
| Underline Reverse | ESC G< |
| Invisible Underline Reverse | ESC G= |
| Underline Reverse Flash | ESC G> |
| Invisible Underline Reverse Flash | ESC G? |
| Half Intensity On | ESC ) |
| Half Intensity Off | ESC ( |

When used in combination with Protect Mode, all half intensity fields will denote a protected field. Half intensity fields do not take up a character space on the screen.

<!-- page 72 (OCR) -->

The entire screen may be reversed with an ESC b and returned to normal video with an ESC d. These codes do not take up a character

space on the screen.

### 5.8 Setting The Time

An internal 1l2-hour clock provides the Ampex 210 terminal operator the opportunity to set the clock to the time of day. To do so, enter Set-Up mode and make the appropriate selection on Status Line 3, or:

Enter BSC space ln HH MM (when in Local mode) or SHIFT ESC spPace N HH MM (when in Full Duplex mode)

where N = A (am) or P (pm) HH = hours MM = minutes Example:

To set the time to 3 o'clock in the afternoon, enter:

ESC space 1 P 03 00 (when in Local mode), or SHIFT ESC Space 1 P 03 00 (when in Full Duplex mode)

The time of day may be read by entering Set-Up mode and advancing to Status Line 3. The time of day will also appear on a printout if a SHIFT/PRINT command is initiated after the time of day is set. The host computer may request the time by sending the following sequence:

BESC space 2

The Ampex 210 terminal will respond with a six-character code consisting of A (or P) HH MM CR,

### 5.9 PRINT FUNCTIONS

The Ampex 210 printer (auxiliary) port may be set for page print, transparent print, and copy print functions. If during a print operation, the printer connected to the auxiliary port cannot accept any more data, the printer may signal the terminal (lowering DTR signal) to stop sending data. The printer may then request the transmission of more data by signaling the terminal (raising DTR signal).

<!-- page 73 (OCR) -->

#### 5.9.1 Page Print

Sends data from the Home position through the cursor position to the printer port. Initiate a Page Print command by an ESC P, This print mode prints page data exactly as entered including line delimiters (a carriage return and linefeed) at the end of each line. During the print process, the message "PTG" will appear on the status line. An ACK code (06 Hex) will be sent to the host computer at the end of the print process.

#### 5.9.2 Transparent Print

When transparent print is in effect, escape sequences, control codes, and all characters received from the host computer are not acted upon, but are transmitted to the printer port. This print function is enabled by an BESC ' and disabled by an ESC a.

#### 5.9.3 Copy Print

This print function causes all subsequent data (including escape sequences and control codes) received by the terminal to be sent to the screen and to the printer port. Copy print is enabled by an ESC @ and disabled by an ESC A.

5.9.4 Bidirectional Printer Port This function allows a printer connected to the printer port to communicate directly with the computer while allowing screen editing

to continue on the terminal. Bidirectional printer port is enabled by a CFRL/R and disabled by a CTRL/T.

5-15/5-16

<!-- page 74 (OCR) -->

<!-- page 75 (OCR) -->

## SECTION VI EMULATION MODES

### 6.1 INTRODUCTION

The Ampex 210 display terminal offers emulation of several terminal models without additional need of modifying host software. These emulations modes are operator-selectable while in the Set-Up mode.

### 6.2 EMULATION MODES

Descriptions of emulation modes are presented in a alphabetical order in the following paragraphs.

#### 6.2.1 ADDS Regent 20/25 Mode

To emulate the ADDS, Regent 20/25, enter Set-Up mode and select R25 on Status Line 1. While in the Regent 20/25 mode, program function keys are available to the operator. Refer to Table 5-4 for a list of available function key code sequences.

#### 6.2.2 ADDS Viewpoint

To emulate the ADDS Viewpoint terminal, enter Set-Up mode and select VP on Status Line 1. Program function keys are available to the operator while on Viewpoint emulation. Refer to Table 5-5 for a list of function key code sequences,

#### 6.2.3 Hazeltine 1410 (1400) Mode

The Hazeltine 1400 and 1410 terminals are emulatedwhenH1410 is

selected in Set-Up mode. When using the German, French, Danish, Swedish, and Norwegian national character sets in conjunction with a Tilde (") as the lead-in code (e.g. Lead = Hz ), the tilde is replaced with the appropriate national character or symbol (refer to Appendix D).

#### 6.2.4 Hazeltine 1500 Mode

To emulate the Hazeltine 1500 terminal, select H1500 when in Set-Up mode. When using the optional national character sets_in conjunction with a tilde (7) as the lead-in code (e.g. Lead = Hz"), the tilde is replaced with the appropriate national character or symbol (refer to Appendix D).

<!-- page 76 (OCR) -->

#### 6.2.5 Lear Siegler ADM5 Mode

To emulate the Lear Siegler ADM5, ADM3, ADM 3A, and ADM 3A+ terminals, select ADM5 when in Set-Up mode. Also in Set-Up mode, ADM5 emulation offers the selection of the auxiliary port as a gating function (CTRL/N enables this feature; CTRL/O disables this feature) when AUX KB:AUX is selected. ADMS5 also offers a keyboard lock function (CTRL/N locks the keyboard; CTRL/0O from the host unlocks the keyboard) when AUX KB:KB is selected,

#### 6.2.6 Qume QVT102 Mode

To emulate the Qume QVT102 terminal, select QT102 when in Set-Up mode. This emulation allows use of the Graphics mode and all of the printing functions. QVT102 emulation mode does not prevent ‘protected characters from being erased when an ERASE command is issued (refer to paragraphs, 5.2.3.5 and 5.2.3.6).

#### 6.2.7 TeleVideo 910 and 910+ Modes

To emulate the TeleVideo 910 and 910+ terminals, select TV910 and T910+, respectively, when in Set-Up mode. Escape sequences for the various visual attributes, as well as attribute delimiters for send operations, are listed in Table 6-1,

#### 6.2.8 TeleVideo 920 Mode

To emulate the TeleVideo 920 terminal, select TV920 when in Set-Up mode. Escape sequences for the various visual attributes, as well as attribute delimiters for send operations, are listed in Table 6-1. When in this emulation, the transparent print feature is available.

6.2.9 TeleVideo 925 Mode To emulate the TeleVideo 925 terminal, select TV925 when in Set-Up mode. Escape sequences for the various visual attributes, as well as

attribute delimiters for send operations, are listed in Table 6-1.

The time of day is set by entering an ESC (space) 1 A (or P) HHMM where:

A=a,m.,, P=p,m, HH = hours MM = minutes

HH and MM must be two-digit entries. For example, to set the time of day to 1:15 p.m., enter: :

ESC (space) 1 P 01 15 P.m. hours minutes

<!-- page 77 (OCR) -->

Table 6-1. TeleVideo 910/910+/920/925/950 Visual Attributes

Escape Attribute Delimiter

Attribute Sequence Control Code Normal ESC GO DL Blank ESC Gl D1 Flash ESC G2 D2 Invisible Flash ESC G3 D3 Reverse Video ESC G4 D4 Invisible Reverse ESC G5 NK Reverse Flash ESC G6 SN Invisible Reverse Flash ESC G7 EB Underline ESC G8 CN Invisible Underline ESC G9 EM Underline Flash ESC G: SB Invisible Underline ESC G; ES Underline Reverse ESC G< FS Invisible Underline Reverse ESC G= GS Underline Reverse Flash ESC G> RS Invisible Underline Flash ESC G? Us 6.3 Emulation Mode Escape Sequences

Table 6~2 provides a list of eumlation mode escape sequences and control codes by function,

<!-- page 78 (proofread) -->

#### Table 6-2. Emulation Mode Escape Sequences and Control Codes

*Transcribed from pages 6-4 to 6-8. "\~" is the Hazeltine lead-in (LEAD=HZ\~ on Status Line 3); "—" means the function is not available in that emulation. Footnotes: ¹ n = any ASCII character; ² from host; ³ NHHMM — N = A (am) or P (pm), HH = hours, MM = minutes; ⁴ see Appendix C.*

| Function | Ampex A210 | ADDS R25 | ADDS VP | Hazeltine 1410 | Hazeltine 1500 | Lear Siegler ADM5 | Qume QT102 | TeleVideo 910 | TeleVideo 910+ | TeleVideo 925 | TeleVideo 920 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **OPERATING MODES** |||||||||||| 
| Block Mode ON | ESC B | — | — | — | — | — | ESC B | — | ESC B | ESC B | ESC B |
| Character Mode ON | ESC C | — | — | — | — | — | ESC C | — | ESC C | ESC C | ESC C |
| Line Mode ON | ESC D | — | — | — | — | — | ESC D | — | — | — | — |
| Monitor Mode ON | CTRL/1 or ESC U | CTRL/1 | CTRL/1 | — | — | — | CTRL/1 or ESC U | CTRL/1 or ESC U | CTRL/1 or ESC U | ESC U | — |
| Monitor Mode OFF | CTRL/2 or ESC X | CTRL/2 | CTRL/2 | — | — | — | CTRL/2, ESC X, or ESC u | CTRL/2, ESC X, or ESC u | CTRL/2, ESC X, or ESC u | ESC X or ESC u | — |
| Protect Mode ON | ESC & | — | — | — | — | — | ESC & | — | ESC & | ESC & | ESC & |
| Protect Mode OFF | ESC ' | — | — | — | — | — | ESC ' | — | ESC ' | ESC ' | ESC ' |
| Write Protect ON | ESC ) | — | — | — | — | — | ESC ) | ESC ) | ESC ) | ESC ) | ESC ) |
| Write Protect OFF | ESC ( | — | — | — | — | — | ESC ( | ESC ( | ESC ( | ESC ( | ESC ( |
| Jump Scroll ON | ESC 9 | — | — | — | — | — | — | — | — | — | — |
| Smooth Scroll ON | ESC 8 | — | — | — | — | — | — | — | — | — | — |
| Auto Scroll Mode ON/OFF | — | — | — | — | — | — | ESC H | ESC H | — | — | — |
| **EDITING COMMANDS** |||||||||||| 
| Set Local Edit | ESC k | — | — | — | — | — | — | — | ESC k | ESC k | — |
| Set Duplex Edit | ESC l (lc L) | — | — | — | — | — | — | — | ESC l (lc L) | ESC l (lc L) | — |
| Cursor Up | CTRL/K | CTRL/Z | CTRL/Z | — | \~CTRL/L | CTRL/K | CTRL/K | CTRL/K | CTRL/K | CTRL/K | CTRL/K |
| Cursor Down | CTRL/V | — | — | — | \~CTRL/K | — | — | — | CTRL/V | CTRL/V | — |
| Cursor Right | CTRL/L | CTRL/F | CTRL/F | CTRL/P | CTRL/P | CTRL/L | CTRL/L | CTRL/L | CTRL/L | CTRL/L | CTRL/L |
| Cursor Left | CTRL/H | CTRL/H or CTRL/U | CTRL/H or CTRL/U | CTRL/H | CTRL/H | CTRL/H | CTRL/H | CTRL/H | CTRL/H | CTRL/H | CTRL/H |
| Cursor Home | CTRL/^ | CTRL/A | CTRL/A | \~CTRL/R | \~CTRL/R | CTRL/^ | CTRL/^ | CTRL/^ | CTRL/^ | CTRL/^ | CTRL/^ |
| Carriage Return | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M | CTRL/M |
| Linefeed | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J | CTRL/J |
| Reverse Linefeed | CTRL/j [sic; Appendix A: ESC j] | — | — | — | — | — | — | — | — | ESC j | CTRL/j |
| New Line | CTRL/_ | — | — | — | — | — | CTRL/_ | CTRL/_ | CTRL/_ | CTRL/_ | CTRL/_ |
| Tab | CTRL/I | — | — | — | — | CTRL/I | CTRL/I | CTRL/I | CTRL/I | CTRL/I | CTRL/I |
| Back Tab | ESC I | — | — | — | — | — | ESC I | ESC I | ESC I | ESC I | ESC I |
| Field Tab | ESC i | — | — | — | — | — | — | — | ESC i | ESC i | ESC i |
| Set Column Tab | ESC 1 | — | — | — | — | — | ESC 1 | ESC 1 | ESC 1 | ESC 1 | ESC 1 |
| Clear Column Tab | ESC 2 | — | — | — | — | — | ESC 2 | ESC 2 | ESC 2 | ESC 2 | ESC 2 |
| Clear All Tabs | ESC 3 | — | — | — | — | — | ESC 3 | ESC 3 | ESC 3 | ESC 3 | ESC 3 |
| Character Insert | ESC Q | — | — | — | — | — | ESC Q | — | ESC Q | ESC Q | ESC Q |
| Character Delete | ESC W | — | — | — | — | — | ESC W | — | ESC W | ESC W | ESC W |
| Line Insert | ESC E | — | — | — | \~CTRL/Z | — | ESC E | — | ESC E | ESC E | ESC E |
| Line Delete | ESC R | — | — | — | \~CTRL/S | — | ESC R | — | ESC R | ESC R | ESC R |
| Erase Line to Spaces | ESC T | ESC K | ESC K | — | \~CTRL/O | ESC T | ESC T | ESC T | ESC T | ESC T | ESC T |
| Erase Line to Nulls | ESC t | — | — | — | — | — | ESC t | — | ESC t | ESC t | ESC t |
| Erase Page to Spaces | ESC Y | ESC k | ESC k | — | \~CTRL/X | ESC Y | ESC Y | ESC Y | ESC Y | ESC Y | ESC Y |
| Erase Page to Nulls | ESC y | — | — | — | — | — | ESC y | — | ESC y | ESC y | ESC y |
| Erase Page to Background space | — | — | — | — | \~CTRL/W | — | — | — | — | — | — |
| Clear Foreground | — | — | — | — | \~CTRL/] | — | — | — | — | — | — |
| Clear All to Nulls | ESC * | — | — | — | — | — | ESC * | ESC * | ESC * | ESC * | ESC * |

<!-- page 79 (proofread) -->

**Table 6-2 (cont.)**

| Function | Ampex A210 | ADDS R25 | ADDS VP | Hazeltine 1410 | Hazeltine 1500 | Lear Siegler ADM5 | Qume QT102 | TeleVideo 910 | TeleVideo 910+ | TeleVideo 925 | TeleVideo 920 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **EDITING COMMANDS (cont.)** |||||||||||| 
| Clear All to Spaces | — | CTRL/L | CTRL/L | \~CTRL/\\ | \~CTRL/\\ | CTRL/Z | CTRL/Z | CTRL/Z | — | — | ESC + |
| Clear Unprotected to Spaces | CTRL/Z or ESC * [sic; Appendix A: CTRL/Z, ESC +] | — | — | — | — | — | ESC ; | — | CTRL/Z, ESC +, or ESC ; | CTRL/Z, ESC +, or ESC ; | CTRL/Z |
| Clear Unprotected to Nulls | ESC : | — | — | — | — | — | ESC : | — | ESC : | ESC : | ESC : |
| Clear Unprotected to Half-Intensity | ESC , | — | — | — | — | — | — | — | ESC , | ESC , | — |
| Clear All to Half-Intensity | — | — | — | — | — | — | ESC , | — | — | — | — |
| **SEND COMMANDS** |||||||||||| 
| Send Line All | ESC 6 | — | — | — | — | — | ESC 6 | — | ESC 6 | ESC 6 | ESC 6 |
| Send Line Unprotected | ESC 4 | — | — | — | — | — | ESC 4 | — | ESC 4 | ESC 4 | ESC 4 |
| Send Page All | ESC 7 | — | — | — | — | — | ESC 7 | — | ESC 7 | ESC 7 | ESC 7 |
| Send Page Unprotected | ESC 5 | — | — | — | — | — | ESC 5 | — | ESC 5 | ESC 5 | ESC 5 |
| Send Message All | ESC s | — | — | — | — | — | — | — | ESC s | ESC s | ESC s |
| Send Message Unprotected | ESC S | — | — | — | — | — | — | — | ESC S | ESC S | ESC S |
| Send ID Message | CTRL/E | — | — | — | — | CTRL/E | CTRL/E | — | — | — | — |
| Program Line Terminator | ESC x1nn¹ | — | — | — | — | — | — | — | ESC x1nn¹ | ESC x1nn¹ | — |
| Program Page Terminator | ESC x4nn¹ | — | — | — | — | — | ESC xn¹ | — | ESC x4nn¹ | ESC x4nn¹ | — |
| Send Character | — | — | — | \~CTRL/T | — | — | — | — | — | — | — |
| **TRANSMISSION COMMANDS** |||||||||||| 
| Enable XON/XOFF Protocol | CTRL/O | — | — | — | — | — | — | — | CTRL/O | CTRL/O | — |
| Disable XON/XOFF Protocol | CTRL/N | — | — | — | — | — | — | — | CTRL/N | CTRL/N | — |
| **PRINT COMMANDS** |||||||||||| 
| Page Print (From Home to Cursor) | ESC P | — | — | — | — | — | ESC N | — | — | ESC P | ESC P |
| Print Page (From Cursor to End) | — | — | — | — | — | — | ESC O | — | — | — | — |
| Page Print (Entire Screen) | — | — | — | — | — | — | ESC P | — | — | — | — |
| Copy Print ON | ESC @ | CTRL/R | CTRL/R | — | — | CTRL/N (GT) | ESC @ | ESC @ | ESC @ | ESC @ | ESC @ |
| Copy Print OFF | ESC A | CTRL/T | CTRL/T | — | — | CTRL/O (GT) | ESC A | ESC A | ESC A | ESC A | ESC A |
| Transparent Print ON | ESC \` | ESC 3 | ESC 3 | — | — | — | CTRL/R | CTRL/R | ESC \` | ESC \` | — |
| Transparent Print OFF | ESC a | ESC 4 | ESC 4 | — | — | — | CTRL/T | CTRL/T | ESC a | ESC a | — |
| Program Print Terminator | ESC pn¹ | — | — | — | — | — | — | — | — | ESC pn¹ | — |
| Bidirectional Print ON | CTRL/R | — | — | — | — | — | — | — | — | CTRL/R | — |
| Bidirectional Print OFF | CTRL/T | — | — | — | — | — | — | — | — | CTRL/T | — |
| **SPECIAL FUNCTIONS AND MISCELLANEOUS COMMANDS** |||||||||||| 
| Alarm (Beep) | CTRL/G | CTRL/G | CTRL/G | — | CTRL/G | CTRL/G | CTRL/G | CTRL/G | CTRL/G | CTRL/G | CTRL/G |
| Alignment E Pattern | — | — | — | — | \~CTRL/S | — | — | — | — | — | — |
| Test Pattern | ESC V | — | — | — | — | — | ESC V | ESC V | ESC V | — | — |
| Keyclick ON | ESC > | — | — | — | — | — | — | — | — | ESC > | — |
| Keyclick OFF | ESC < | — | — | — | — | — | — | — | — | ESC < | — |
| Keyboard Lock² | ESC # | ESC 5 or CTRL/D | ESC 5 or CTRL/D | \~CTRL/U | \~CTRL/U | CTRL/O (LK) | ESC # | ESC # | ESC # | ESC # | ESC # |
| Keyboard Unlock² | ESC " | ESC 6 or CTRL/B | ESC 6 or CTRL/B | \~CTRL/F | \~CTRL/F | CTRL/N (LK) | ESC " | ESC " | ESC " | ESC " | ESC " |
| Graphic Mode ON | ESC $ | — | — | — | — | — | ESC $ | — | — | — | — |
| Graphic Mode OFF | ESC % | — | — | — | — | — | ESC % | — | — | — | — |
| Set Time of Day | ESC space 1NHHMM³ | — | — | — | — | — | — | — | — | ESC space 1NHHMM³ | — |
| Read Time | ESC space 2 | — | — | — | — | — | — | — | — | ESC space 2 | — |
| Print Time of Day | ESC L | — | — | — | — | — | — | — | — | ESC L | — |
| Display Control Characters | ESC F | ESC Z | — | — | — | — | ESC F | ESC F | — | — | ESC F |
| Display Status Line | ESC } | — | — | — | — | — | ESC } | — | — | — | — |
| Status Line OFF | ESC { | — | — | — | — | — | ESC { | — | — | — | — |
| Write Message to User Line | ESC f | — | — | — | — | — | — | — | — | ESC f | — |
| Display User Line Message | ESC g | — | — | — | — | — | — | — | — | ESC g | — |
| User Line OFF | ESC h | — | — | — | — | — | — | — | — | ESC h | — |
| **CURSOR ADDRESS** |||||||||||| 
| Cursor Enable | — | — | CTRL/X | — | — | — | — | — | — | — | — |
| Cursor Disable | — | — | CTRL/W | — | — | — | — | — | — | — | — |
| Address Cursor (Row, Column) | - [sic; Appendix A: ESC =] | ESC Y | ESC Y | — | — | ESC = | ESC = | ESC = | ESC = | ESC = | ESC = |
| Address Cursor (Row) | - [sic; Appendix A: ESC [] | CTRL/K | CTRL/K | — | — | — | ESC [ | ESC [ | — | ESC [ | — |
| Address Cursor (Column) | - [sic; Appendix A: ESC ]] | CTRL/P | CTRL/P | — | — | — | ESC ] | ESC ] | — | ESC ] | — |
| Read Cursor (Row, Column) | - [sic; Appendix A: ESC ?] | — | — | — | — | — | ESC ? | ESC ? | ESC ? | ESC ? | ESC ? |
| Address Cursor (Column, Row) | — | — | — | \~CTRL/Q | \~CTRL/Q | — | — | — | — | — | — |
| Read Cursor (Column, Row) | — | — | — | \~CTRL/E | \~CTRL/E | — | — | — | — | — | — |
| Address Cursor (Page, Row, Column) | — | — | — | — | — | — | — | — | — | ESC - | — |
| Read Cursor (Page, Row, Column) | — | — | — | — | — | — | — | — | — | ESC / | — |
| Flashing Block Cursor | ESC .1 | — | — | — | — | — | — | — | ESC .1 | ESC .1 | — |
| Steady Block Cursor | - [sic; Appendix A: ESC .2] | — | — | — | — | — | — | — | ESC .2 | ESC .2 | — |
| Flashing Underline Cursor | - [sic; Appendix A: ESC .3] | — | — | — | — | — | — | — | ESC .3 | ESC .3 | — |
| Steady Underline Cursor | - [sic; Appendix A: ESC .4] | — | — | — | — | — | — | — | ESC .4 | ESC .4 | — |
| Cursor OFF | ESC .0 | — | — | — | — | — | — | — | ESC .0 | ESC .0 | — |
| Cursor Visible/Invisible | — | — | — | — | — | — | ESC . | ESC . | — | — | — |

<!-- page 80 (proofread) -->

<!-- page 81 (proofread) -->

**Table 6-2 (cont.)**

| Function | Ampex A210 | ADDS R25 | ADDS VP | Hazeltine 1410 | Hazeltine 1500 | Lear Siegler ADM5 | Qume QT102 | TeleVideo 910 | TeleVideo 910+ | TeleVideo 925 | TeleVideo 920 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **VISUAL ATTRIBUTES** |||||||||||| 
| Normal Video | ESC G0 | — | — | — | — | — | ESC G0 | ESC G0 | ESC G0 | ESC G0 | ESC G0 |
| Blank | ESC G1 | — | — | — | — | — | ESC G1 | ESC G1 | ESC G1 | ESC G1 | ESC G1 |
| Flash | ESC G2 | — | — | — | — | — | ESC G2 | ESC G2 | ESC G2 | ESC G2 | ESC G2 |
| Invisible Flash | ESC G3 | — | — | — | — | — | ESC G3 | ESC G3 | ESC G3 | ESC G3 | ESC G3 |
| Reverse | ESC G4 | — | — | — | — | — | ESC G4 | ESC G4 | ESC G4 | ESC G4 | ESC G4 |
| Invisible Reverse | ESC G5 | — | — | — | — | — | ESC G5 | ESC G5 | ESC G5 | ESC G5 | ESC G5 |
| Reverse Flash | ESC G6 | — | — | — | — | — | ESC G6 | ESC G6 | ESC G6 | ESC G6 | ESC G6 |
| Invisible Reverse Flash | ESC G7 | — | — | — | — | — | ESC G7 | ESC G7 | ESC G7 | ESC G7 | ESC G7 |
| Underline | ESC G8 | — | — | — | — | — | ESC G8 | ESC G8 | ESC G8 | ESC G8 | ESC G8 |
| Invisible Underline | ESC G9 | — | — | — | — | — | ESC G9 | ESC G9 | ESC G9 | ESC G9 | ESC G9 |
| Underline Flash | ESC G: | — | — | — | — | — | ESC G: | ESC G: | ESC G: | ESC G: | ESC G: |
| Invisible Underline Flash | ESC G; | — | — | — | — | — | ESC G; | ESC G; | ESC G; | ESC G; | ESC G; |
| Underline Reverse | ESC G< | — | — | — | — | — | ESC G< | ESC G< | ESC G< | ESC G< | ESC G< |
| Invisible Underline Reverse | ESC G= | — | — | — | — | — | ESC G= | ESC G= | ESC G= | ESC G= | ESC G= |
| Underline Reverse Flash | ESC G> | — | — | — | — | — | ESC G> | ESC G> | ESC G> | ESC G> | ESC G> |
| Invisible Underline Reverse Flash | ESC G? | — | — | — | — | — | ESC G? | ESC G? | ESC G? | ESC G? | ESC G? |
| Black on White | ESC b | — | — | — | — | — | — | — | — | ESC b | — |
| White on Black | ESC d | — | — | — | — | — | — | — | — | ESC d | — |
| Normal Screen | ESC n | — | — | — | — | — | — | — | — | ESC n | — |
| Blank Screen | ESC o | — | — | — | — | — | — | — | — | ESC o | — |
| Tag Bit Set | — | — | CTRL/N | — | — | — | — | — | — | — | — |
| Tag Bit Reset | — | — | CTRL/O | — | — | — | — | — | — | — | — |
| Set Attribute | — | — | ESC 0 | — | — | — | — | — | — | — | — |
| Background Follows | — | — | — | — | \~CTRL/Y | — | — | — | — | — | — |
| Foreground Follows | — | — | — | — | \~CTRL/_ | — | — | — | — | — | — |
| Reverse Video ON/OFF | — | — | — | — | — | ESC G | — | — | — | — | — |
| Half-Intensity ON | — | — | — | — | — | ESC ) | — | — | — | — | — |
| Half-Intensity OFF | — | — | — | — | — | ESC ( | — | — | — | — | — |

*Transcriber's note: the TeleVideo 920 column prints ESC G; for Underline Reverse, an evident misprint for ESC G<; it is given as ESC G< here.*

<!-- page 82 (proofread) -->

<!-- page 83 (proofread) -->

## APPENDIX A — ESCAPE SEQUENCES AND CONTROL CODES

| Function | Escape sequence or control code | Key |
|---|---|---|
| **OPERATING MODES** | | |
| Block Mode On | ESC B | |
| Character Mode On | ESC C | |
| Line Mode On | ESC D | |
| Monitor Mode On | CTRL/1 or ESC U | |
| Monitor Mode Off | CTRL/2, ESC X, or ESC u | |
| Protect Mode On | ESC & | |
| Protect Mode Off | ESC ' | |
| Write Protect On | ESC ) | |
| Write Protect Off | ESC ( | |
| Jump Scroll On | ESC 9 | |
| Smooth Scroll On | ESC 8 | |
| Function Key Mode On/Off | ESC c | |
| **EDITING COMMANDS** | | |
| Set Local Edit | ESC k | |
| Set Duplex Edit | ESC l (lower case L) | |
| Cursor Up | CTRL/K | ↑ |
| Cursor Down | CTRL/V | ↓ |
| Cursor Left | CTRL/H | ← |
| Cursor Right | CTRL/L | → |
| Cursor Home | CTRL/^ | CLEAR HOME |
| Carriage Return | CTRL/M | RETURN |
| Linefeed | CTRL/J | LINEFEED or SHIFT/↓ |
| Reverse Linefeed | ESC j | |
| New Line | CTRL/_ | |
| Tab | CTRL/I | TAB |
| Back Tab | ESC I | BACK TAB |
| Field Tab | ESC i | TAB |
| Set Column Tab | ESC 1 | |
| Clear Column Tab | ESC 2 | |
| Clear All Tabs | ESC 3 | |
| Character Insert | ESC Q | DEL CHAR INS |
| Character Delete | ESC W | SHIFT/DEL CHAR INS |
| Line Insert | ESC E | DEL LINE INS |
| Line Delete | ESC R | SHIFT/DEL LINE INS |
| Erase Line to Spaces | ESC T | PAGE ERASE LINE |
| Erase Line to Nulls | ESC t | |
| Erase Page to Spaces | ESC Y | SHIFT/PAGE ERASE LINE |
| Erase Page to Nulls | ESC y | |
| Clear All to Nulls | ESC * | |
| Clear Unprotected to Spaces | CTRL/Z, ESC + | SHIFT/CLEAR HOME |
| Clear Unprotected to Nulls | ESC : | |

<!-- page 84 (proofread) -->

| Function | Escape sequence or control code | Key |
|---|---|---|
| **SEND COMMANDS** | | |
| Clear Unprotected to Half-Intensity | ESC , | |
| Send Line All | ESC 6 | |
| Send Line Unprotected | ESC 4 | |
| Send Page All | ESC 7 | |
| Send Page Unprotected | ESC 5 | |
| Send Message All | ESC s | |
| Send Message Unprotected | ESC S | |
| Program Line Terminator | ESC x1nn¹ | |
| Program Page Terminator | ESC x4nn¹ | |
| **TRANSMISSION COMMANDS** | | |
| Enable XON/XOFF Protocol | CTRL/O | |
| Disable XON/XOFF Protocol | CTRL/N | |
| **PRINT COMMANDS** | | |
| Page Print | ESC P | PRINT |
| Copy Print On | ESC @ | |
| Copy Print Off | ESC A | |
| Transparent Print On | ESC \` | |
| Transparent Print Off | ESC a | |
| Program Print Terminator | ESC pn¹ | |
| Bidirectional Print On | CTRL/R | |
| Bidirectional Print Off | CTRL/T | |
| **SPECIAL FUNCTIONS AND MISCELLANEOUS COMMANDS** | | |
| Alarm (beep) | CTRL/G | |
| Test Pattern | ESC V | |
| Keyclick ON | ESC > | |
| Keyclick OFF | ESC < | |
| Keyboard Lock | ESC #² | |
| Keyboard Unlock | ESC "² | |
| Graphic Mode On | ESC $ | |
| Graphic Mode Off | ESC % | |
| Set Time of Day | ESC space 1NHHMM³ | |
| Print Time of Day | ESC L | |
| Read Time | ESC space 2 | |

¹ n = any ASCII character. ² From host. ³ NHHMM: N = A (am), P (pm), HH = hours, MM = minutes.

<!-- page 85 (proofread) -->

| Function | Escape sequence or control code | Key |
|---|---|---|
| **SPECIAL FUNCTIONS AND MISCELLANEOUS COMMANDS (cont.)** | | |
| 25th Line On | ESC } | |
| 25th Line Off | ESC { | |
| Write Message to User Line | ESC f | |
| Display User Line Message | ESC g | |
| Display Status Line | ESC h | |
| Display Control Character | ESC F | |
| **CURSOR ADDRESSES** | | |
| Address Cursor (Row, Column) | ESC = | |
| Address Cursor (Row) | ESC [ | |
| Address Cursor (Column) | ESC ] | |
| Read Cursor (Row, Column) | ESC ? | |
| Flashing Block Cursor | ESC .1 | |
| Steady Block Cursor | ESC .2 | |
| Flashing Underline Cursor | ESC .3 | |
| Steady Underline Cursor | ESC .4 | |
| Cursor Off | ESC .0 | |
| **VISUAL ATTRIBUTES** | | |
| Normal Video | ESC G0 | |
| Blank | ESC G1 | |
| Flash | ESC G2 | |
| Invisible Flash | ESC G3 | |
| Reverse | ESC G4 | |
| Invisible Reverse | ESC G5 | |
| Reverse Flash | ESC G6 | |
| Invisible Reverse Flash | ESC G7 | |
| Underline | ESC G8 | |
| Invisible Underline | ESC G9 | |
| Underline Flash | ESC G: | |
| Invisible Underline Flash | ESC G; | |
| Underline Reverse | ESC G< | |
| Invisible Underline Reverse | ESC G= | |
| Underline Reverse Flash | ESC G> | |
| Invisible Underline Reverse Flash | ESC G? | |
| Black on White | ESC b | |
| White on Black | ESC d | |
| Normal Screen | ESC n | |
| Blank Screen | ESC o | |

*Transcriber's note: Table 6-2 lists ESC h as "User Line OFF" and ESC } / ESC { as "Display Status Line" / "Status Line OFF"; read together, ESC h hides the user line and shows the status line again.*

<!-- page 86 (proofread) -->

## APPENDIX B — ASCII CODE CHART

*The manual prints the standard 7-bit ASCII code chart (columns 0–7 by rows 0–F, with bit patterns b7…b1). It is not reproduced here; any ASCII chart is equivalent. See the PDF, page 86.*

<!-- page 87 (proofread) -->

## APPENDIX C — LINE GRAPHIC SYMBOLS

Fifteen line graphic symbols may be displayed on the screen when the terminal is in the Graphics Mode. Select GFX ON when in Set-Up Mode (refer to Table 3-1) or enable Graphics Mode by an ESC $ and disable with an ESC %. The terminal must be in Ampex 210 or Qume QVT102 mode to enable graphics feature.

| Description | Symbol | Key |
|---|---|---|
| Bottom Left Curve | ╰ | a |
| Top Left Curve | ╭ | b |
| Top Right Curve | ╮ | c |
| Bottom Right Curve | ╯ | d |
| Bottom Left Corner | └ | e |
| Top Left Corner | ┌ | f |
| Top Right Corner | ┐ | g |
| Bottom Right Corner | ┘ | h |
| Crossed Lines | ┼ | i |
| Vertical Line | │ | j |
| Horizontal Line | ─ | k |
| Right Intersection | ┤ | l |
| Left Intersection | ├ | m |
| Top Intersection | ┬ | n |
| Bottom Intersection | ┴ | o |

*Symbols are the closest Unicode box-drawing characters to the printed glyphs.*

<!-- page 88 (proofread) -->

## APPENDIX D — NATIONAL CHARACTER SETS

Any one of six national character sets may be selected when in Set- Up mode (refer to Table 3-1). The U.S./U.K. keycap is standard on each unit (see Figure 4-1). Optional German, French, Swedish, Norwegian, and Danish keycap sets are available for the alternate national character sets.

*Figures D-1 to D-5 (optional German, French, Swedish, Norwegian and Danish keyboard layouts, pages 88–90) and Table D-1 (characters substituted at hex codes 23, 24, 40, 5B–5E, 60, 7B–7E per national set, page 91) are not transcribed; see the PDF.*

<!-- page 89 (proofread) -->

<!-- page 90 (proofread) -->

<!-- page 91 (proofread) -->

<!-- page 92 (proofread) -->

## APPENDIX E — CURSOR ADDRESSES

Cursor addressing (ESC = line column, ESC [ line, ESC ] column) encodes each line and column as one character: line or column *n* is sent as the character with code 1F hex + *n*, so line 1 and column 1 are Space (20 hex). Lines run 1–24 and columns 1–80. The table below is regenerated from that rule; the manual lists the same values as a table on pages 92–93 (spot-checked), and Figure E-1 shows the same mapping across the screen with the cursor in the home position).

| Line/column | Hex | Code | Column | Hex | Code | Column | Hex | Code | Column | Hex | Code |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 20 | Space | 21 | 34 | 4 | 41 | 48 | H | 61 | 5C | \\ |
| 2 | 21 | ! | 22 | 35 | 5 | 42 | 49 | I | 62 | 5D | ] |
| 3 | 22 | " | 23 | 36 | 6 | 43 | 4A | J | 63 | 5E | ^ |
| 4 | 23 | # | 24 | 37 | 7 | 44 | 4B | K | 64 | 5F | \_ |
| 5 | 24 | $ | 25 | 38 | 8 | 45 | 4C | L | 65 | 60 | \` |
| 6 | 25 | % | 26 | 39 | 9 | 46 | 4D | M | 66 | 61 | a |
| 7 | 26 | & | 27 | 3A | : | 47 | 4E | N | 67 | 62 | b |
| 8 | 27 | ' | 28 | 3B | ; | 48 | 4F | O | 68 | 63 | c |
| 9 | 28 | ( | 29 | 3C | < | 49 | 50 | P | 69 | 64 | d |
| 10 | 29 | ) | 30 | 3D | = | 50 | 51 | Q | 70 | 65 | e |
| 11 | 2A | \* | 31 | 3E | > | 51 | 52 | R | 71 | 66 | f |
| 12 | 2B | + | 32 | 3F | ? | 52 | 53 | S | 72 | 67 | g |
| 13 | 2C | , | 33 | 40 | @ | 53 | 54 | T | 73 | 68 | h |
| 14 | 2D | - | 34 | 41 | A | 54 | 55 | U | 74 | 69 | i |
| 15 | 2E | . | 35 | 42 | B | 55 | 56 | V | 75 | 6A | j |
| 16 | 2F | / | 36 | 43 | C | 56 | 57 | W | 76 | 6B | k |
| 17 | 30 | 0 | 37 | 44 | D | 57 | 58 | X | 77 | 6C | l |
| 18 | 31 | 1 | 38 | 45 | E | 58 | 59 | Y | 78 | 6D | m |
| 19 | 32 | 2 | 39 | 46 | F | 59 | 5A | Z | 79 | 6E | n |
| 20 | 33 | 3 | 40 | 47 | G | 60 | 5B | [ | 80 | 6F | o |

<!-- page 93 (proofread) -->

<!-- page 94 (proofread) -->

## APPENDIX F — MONITOR MODE FACSIMILE SYMBOLS

In Monitor Mode each control character is displayed as a single-cell facsimile: two small letters, the second set lower (subscript) than the first.

| Facsimile | ASCII mnemonic | Hex | Description |
|---|---|---|---|
| N<sub>U</sub> | NUL | 00 | Null |
| S<sub>H</sub> | SOH | 01 | Start of Heading |
| S<sub>X</sub> | STX | 02 | Start of Text |
| E<sub>X</sub> | ETX | 03 | End of Text |
| E<sub>T</sub> | EOT | 04 | End of Transmission |
| E<sub>Q</sub> | ENQ | 05 | Enquiry |
| A<sub>K</sub> | ACK | 06 | Acknowledge |
| B<sub>L</sub> | BEL | 07 | Bell (beep) |
| B<sub>S</sub> | BS | 08 | Back Space |
| H<sub>T</sub> | HT | 09 | Horizontal Tab |
| L<sub>F</sub> | LF | 0A | Line Feed |
| V<sub>T</sub> | VT | 0B | Vertical Tab |
| F<sub>F</sub> | FF | 0C | Form Feed |
| C<sub>R</sub> | CR | 0D | Carriage Return |
| S<sub>O</sub> | SO | 0E | Shift Out |
| S<sub>I</sub> | SI | 0F | Shift In |
| D<sub>L</sub> | DLE | 10 | Data Link Escape |
| D<sub>1</sub> | DC1 | 11 | Device Control 1 |
| D<sub>2</sub> | DC2 | 12 | Device Control 2 |
| D<sub>3</sub> | DC3 | 13 | Device Control 3 |
| D<sub>4</sub> | DC4 | 14 | Device Control 4 |
| N<sub>K</sub> | NAK | 15 | Negative Acknowledge |
| S<sub>N</sub> | SYN | 16 | Synchronous Idle |
| E<sub>B</sub> | ETB | 17 | End of Transmission Block |
| C<sub>N</sub> | CAN | 18 | Cancel |
| E<sub>M</sub> | EM | 19 | End of Medium |
| S<sub>B</sub> | SUB | 1A | Substitute (clear all to spaces) |
| E<sub>S</sub> | ESC | 1B | Escape |
| F<sub>S</sub> | FS | 1C | File Separator |
| G<sub>S</sub> | GS | 1D | Group Separator |
| R<sub>S</sub> | RS | 1E | Record Separator, (Home) |
| U<sub>S</sub> | US | 1F | Unit Separator, (New Line) |
| | SP | 20 | Space, Blank |

<!-- page 95 (proofread) -->

<!-- page 96 (OCR) -->

## APPENDIX G SIMPLIFIED TROUBLESHOOTING GUIDE

This appendix is intended to assist the terminal operator should there be any difficulty operating the terminal.

"Non—-Printer Related Problems/Causes

Problem

Possible Cause

Terminal will not turn on when power switch is set to ON,

AC cord not plugged in to wall outlet. Blown Fuse. Replace (see Figure 1-2). No power at wall outlet.

Display screen on but will not display characters when keys are pressed.

Keyboard cable not plugged in to display unit.

Keyboard is locked -- Enter Set-Up mode and toggle to KB ON,

Unable to communicate with host computer.

I/0 cables not properly connected from terminal primary port to host computer.

Incorrect operating mode - should be Character (CHAR) mode.

Jumbled display on screen.

2. 3. 4.

Incorrect primary port baud rate -- enter Set-up mode and correct the condition.

Incorrect bits-per-character -- enter Set-up mode and correct the condition. Incorrect parity -- enter Set-up mode and correct the condition.

Monitor mode is ON -- Enter Set-Up mode and toggle to MON OFF.

Continuous beeping when receiving data from host computer.

Bell is ON. bell off,

Enter Set-up mode and turn

<!-- page 97 (OCR) -->

Printer Related Problems/Causes

Problem Possible Cause Printer is not l. Printer is using a port other than an interfacing properly RS232 asynchronous interface port.

with the terminal, 2. The terminal's printer port is not set to "output”,

3. Incorrect data word structure. Change printer operating configuration.

4. The printer's VDT port pins are set incorrectly to the printer's input and signal ground pins. Set VDT port pins to Pin 3 (output) and Pin 7 (signal ground).

5. The "Printer Ready" signal is set incorrectly. Set this signal to Pin 20%*,

* NOTE: Printer pin assignments may vary; consult the printer's manufacturer for more information,

PRINTER INTERFACE SELF-TEST

After checking the five possible causes and correcting, as necessary, the printer should interface properly with the terminal. To verify that all problems have been corrected, perform this selftest procedure on your terminal not connected to a modem or a host computer. If the unit is connected to a host or modem, disconnect before performing this self-test.

Set the terminal in Block Mode. Type in several lines of information. Depress the PRINT key.

WN = o o o

Result: If interface problems have been resolved, all data from the Home position to, and including, the current cursor position should print.

<!-- page 98 (OCR) -->

## APPENDIX H OPERATOR'S QUESTIONNAIRE

Ampex Corporation is continuously searching for ways to improve its products and product documentation. Your comments will help.

1,

4.

What specific Ampex terminal(s) are you using? Check all that apply.

A210 D30 D80 D81 ___ D125

D150 D175

Is this manual helpful to you? Why or why not? How can this manual be improved? Have you found any mistakes in the manual?

Describe any problems you have had in using your Ampex terminal,

Please give us any additional comments that you may have, If you like, use additional sheets of paper.

Would you like to be contacted by a representative of Ampex Corporation? If you would, why? (Need more terminals, equipment problem, etc.). Please supply us with your name, address, and telephone number so that we can reach you.

Name and address:

Telephone:

Mail your completed Operator's Questionnaire to: Ampex Corporation, Marketing Services Dept. Mail Stop M-22, Attn., VDT MANUALS, 200 N, Nash St., E1 Segundo, Calif., 90245, U,S.A.

<!-- page 99 (OCR) -->

WARRANTY

Your Ampex Video Display Terminal is supported by warranty service. The terms and conditions of this service, and the procedures to follow for exercising your warranty options are:

Ampex warrants that this Terminal, when used in the manner for which it was designed, will perform in accordance with Ampex’s published specifications, and will be free from defects in material and workmanship for a period of six (6) months from date of shipment to the Buyer. Ampex will, without charge to the Buyer, repair any Terminal or part thereof which Ampex determines to have failed to meet Ampex specifications or to be defective within the terms and conditions of this warranty, provided that:

A. The Buyer shall have notified Ampex of any alleged defect in the Terminal within the period of this Warranty.

B. The Buyer shall have followed the instructions provided by Ampex pertaining to returning the Terminal within the period of this Warranty.

C. The Terminal has not been altered, damaged, or repaired in any way which Ampex reasonably determines to have adversely affected performance or reliability, nor has it been subjected to misuse, neglect, or accident, including, but not limited to, failure of or excessive electric power, failure of environmental-control equipment, failure of the Buyer’s preventive maintenance program, or inadequate protection during transit to Ampex. Ampex shall not be obligated to repair or replace any Terminal, parts, or components for cosmetic or similar reasons.

The above Warranty extends to the original Buyer only, and repair or replacement of component parts shall not extend this Warranty, nor create any other warranty.

This Warranty shall survive acceptance and payment by the Buyer. To exercise this Warranty :

1. Complete the Warranty Registration Card, 3515020—-02, and mail to the designated Ampex location, postage-paid and pre-addressed, on that card.

2. If adefect in material or workmanship is determined within the six (6) month warranty period, notify Ampex and obtain further instructions. Call:

800-538-7838 (outside of California)

800-524-2850 (within California, except locations having a 415 area code) 408-725-2069 (locations having a 415 area code)

351502001 5/84

<!-- page 100 (OCR) -->

<!-- page 101 (OCR) -->

AMPEX 210

Sie bestellen beim authorisierten Distributor

SIGNA

COMPUTER GMBH

NordstraBe 5

6333 BraunfelsAltenkirchen

Telefon (06445) 804

Telex 483800 sigma

Geben Sie die gewlinschte Bildschirmfarbe an und ob Sie die deutschen Tastenkappen zuséatzlich wiinschen.

Das Ampex 210 ist unvergleichlich. In der Ergonomie, in den Madglichkeiten. Und im Preis.

Kein Wunder.

Das AMPEX 210 ist nicht einfach ein herkémmliches Bildschirmgerat zu einem Magerpreis, sondern eine Neukonstruktion mit allen Eigenschaften, die man von einem weit teureren Terminal erwartet. So bietet es unter anderem 14 verschiedene Emulationen und soft Scrolling.

Dazu kommt eine fla-

che Tastatur mit Dezimalblock {als Option nach DIN) und ein groBer 14" Bildschirm, der in fast allen Richtungen geschwenkt werden kann. Bildschirmfarbe ist griin oder amber (bernsteinfarben).

Und wenn Sie jetzt fragen, wie das zu dem Preis zu machen ist—ganz einfach: AMPEX hat schlieBlich 30 Jahre Erfah-

rung in der Herstellung von Videogeréaten und Computerperipherie und weiB, wie man preisgiinstig fertigt. Wir geben 6 Monate Garantie auf das Gerat.

Sie kédnnen das AMPEX 210 gerne mit Konkurrenzprodukten vergleichen. Bitte seien Sie nicht (iberrascht, wenn das nicht geht, weil Sie keine gefunden haben.

oM 169 Y

39

St

AMPEX

Ampex Corporation - One of The Signat Companies %

TeleVideo, ADDS, Lear Siegler und Selectric sind Handelsmarken von TeleVideo Inc., Applied Digital Data Systems Inc., Lear Siegler Inc. and IBM.

<!-- page 102 (OCR) -->

AMPEX 210

[ Technische Daten:

Bildschirm:

14 Zoll Bildrbhre, entspiegelt Amber oder griiner Phosphor 60 oder 65 Hz Refresh (einstellbar)

Dreh- und schwenkbar gelagert

24 Zeilen zu je 80 Zeichen 7x9 Punktmatrix im 9x12 Feld 15 Strichgrafikzeichen

Cursor

9x12 Punkt Matrix

Block oder Unterstreichung Blinkend oder nicht blinkend Les- und setzbar

An- und ausschaltbar

Nationale Zeichensétze Vereinigte Staaten GroBbritannien Frankreich Deutschland Norwegen

Schweden

Danemark

Videoattribute

Blinken, inverse Darstellung, Unterstreichen, halbe Intensitat

Tastatur

niedriges Profil nach DIN (30 mm)

abgesetzt mit langem Spiralkabel

horbarer Klick (kann abgeschaltet werden) Tastaturbelegung wie Selectric

Option DIN Tastensatz verschieden hohe Tastenreihen

14 Funktionstasten Separate Editiertasten Separater Numerik/Funktionsblock Neigungswinkel verstellbar

Betriebsmodi

Voll- oder Halbduplex

Block, Zeile, Zeichen, Lokal Monitor

weiches Rollen (smooth Scroll)

Einstellmodus

Geschutzt, schreibgeschiitzt Strichgrafik

Kommunikation

2 serielle Ports

beide RS 232 C asynchron mit 50 bis 19.200 Baud

Druckerfunktionen lokaler Druck (Seitendruck) Kopie der Bildschirmausgabe

Emulationen ADDS Regent 20/25, Viewpoint

Hazeltine 1400/1410/1500 Lear Siegler

ADM 3/3A/3A+/5

Qume QVT 102 Televideo 910, 910+, 925

Stromversorgung 115/230 Volt umschaitbar, 55 Watt

erfiillte Sicherheitsnormen UL, FCC Class A (USA) CSA (Kanada)

VDE, FTZ (Deutschland) EANGW (Australien)

AusmaBe in mm/kg

L AMPEX hat Niederlassungen in

Vereinigte Staaten Allendale, New Jersey Arlington Heights, lllinois Carrollton, Texas

El Segundo, Kalifornien

international

Bildschirm Tastatur Toronto, Kanada

Breite 343 483 Tiefe 343 191 Hoéhe 369 38 Gewicht 8,7 kg 0,9kg

AMPEX behalt sich das Recht vor, die obigen Spezifikationen zur Verbesserung des Produkts zu andern.

Reading, GroBbritannien Paris, Frankreich

Frankfurt (Tel. 0611/60581) Hong Kong

Rom, ltalien

Stockholm, Schweden Utrecht, Niederlande Madrid, Spanien

Fribourg, Schweiz

AIVIPEX

Ampex Corporation * One of The Signal Companies %
