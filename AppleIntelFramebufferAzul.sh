#!/bin/bash

#
# This script is a stripped/rewrite of AppleIntelSNBGraphicsFB.sh 
#
# Version 0.9 - Copyright (c) 2012 by † RevoGirl
# Version 2.9 - Copyright (c) 2013 by Pike R. Alpha <PikeRAlpha@yahoo.com>
#
#
# Updates:
#			- v1.0	no longer requires/calls nm (Pike, August 2013)
#			- v1.1	no longer requires/calls otool (Pike, August 2013)
#			- v1.2	cleanups (Pike, August 2013)
#			- v1.3	support for optional filename added (Pike, October 2013)
#			- v1.4	asks to reboot (Pike, June 2014)
#			- v1.5	table data dumper added (Pike, August 2014)
#			-       table data replaced with that of Yosemite DP5.
#			- v1.6	adjustable framebuffer size (Pike, August 2014)
#			-       askToReboot() was lost/added again.
#			-       dump now reads the correct [optional] file argument.
#			- v1.7	read LC_SYMTAB to get offset to _gPlatformInformationList i.e.
#			-       dump now works <em>with</em> and <em>without</em> nm.
#			-       typo fixed, layout changes (whitespace) and other improvements.
#			- v1.8	fixed a small error (0x0x instead of 0x) in _dumpConnectorData (Pike, August 2014)
#			- v1.9	'show' argument is now optional (Pike, August 2014)
#			-       code moved to a new function called _patchFile
#			-       done some cleanups and a few cosmetic only changes.
#			-       note added about where/what to do when the data is unchanged.
#			-       function _checkDataLength added.
#			-       moved PATCHED_PLATFORM_INFO to above FACTORY_PLATFORM_INFO (easier to make changes).
#			-       renaming script to AppleIntelFramebufferCapri.sh adds capri support.
#			- v2.0	show no longer calls _checkDataLength (Pike, August 2014)
#			-       using an unsupported platformID now shows a list with supported platformIDs.
#			-       this list also shows additional info, like: "Ivy Bridge/Haswell (Mobile) GT[1/2/3]"
#			-       don't show 'AppleIntelFramebufferAzul.sh' for 'AppleIntelFramebufferCapri.sh'
#			- v2.1	whitespace changes (Pike, August 2014)
#			-       forgotten device-id (0x0a2e) added.
#			- v2.2  fixed _getOffset for Capri (Pike, August 2014)
#			-       reset gPlatformIDs in function _showPlatformIDs to prevent duplicated entries.
#			- v2.3  read property AAPL,ig-platform-id from ioreg and use it as default target (Pike, August 2014)
#			-       helper functions _hexToMegaByte, _hexToPortName and _hexToPortNumber added.
#			- v2.4  function _showColorizedData added (Pike, August 2014)
#			-       changed _hexToMegaByte a little.
#			-       LVDS added to _hexToPortName.
#			- v2.5  _showColorizedData now also support Capri (Pike, August 2014)
#			-       cleanups and comments added.
#			-       function _printInfo added.
#			- v2.6  export data to Azul-0x0d220003.dat (Pike, August 2014)
#			-       read/import data from Azul-0x0d220003.dat
#			- v2.7  error in _getOffset for Capri support fixed (Pike, August 2014)
#			-       function _hexToPortNumber replaced by _getPortNumbers.
#			-       function _hexToPortName replaced by _getConnectorNames.
#			-       function _showColorizedData simplified, using the above new functions.
#			- v2.8  _showMenu and _doAction added (Pike, September 2014)
#			-       better/more flexible color support implemented.
#			-       setting gExtraStyling to 0 now really works.
#			-       function _confirmed added.
#			-       now using bash instead of sh (we want echo -n to work).
#			- v2.9  function _showColorizedData renamed to _showData  (Pike, September 2014)
#			-       function _showPlainTextData removed.
#			-       function _clearMenu renamed to _clearLines.
#			-       functions _invalidMenuAction, _validateMenuAction and _showModifiedData added.
#			-       functions _checkForDataFile, _setDataFilename and _setDataFilename added.
#			-       improved capri support/fixed pointers to values in gDWords array.
#			-       changed _initPortData to make it work with only two arguments.
#			-       renamed connectorTableOffset to gConnectorTableOffset.
#			-       fixed a root check error ($gPlatformID instead of $id).
#			-       fixed a typo in PATCHED_PLATFORM_INFO definition.
#			-       added a lost 'patch' keyword.
#			-       variable gDataFileSelected added (set to 1 if a data file is selected).
#			-       fixed a root user issue/now using gID (like in my other scripts).
#			-       DEBUG renamed to gDebug (like in my other scripts).
#			-       call _getConnectorTableOffset right after the filename change for capri.
#			-       Capri script now works again without nm (bytes vs characters mixup).
#			-       fixed some debug output formats.
#

gScriptVersion=2.9

#
# Used to print the name of the running script
#

gScriptName=$(echo $0 | sed -e 's/^\.\///')

#
# Setting the debug mode (default off).
#
let gDebug=0

#
# Get user id
#
let gID=$(id -u)

#
# Number of bytes in a row
#
# Note: Do NOT change this!
#
let gBytesPerRow=16

#
# Default number of rows in a framebuffer table
#
# Lion			= 7
# Mountain Lion	= 7
# Mavericks		= 8
# Yosemite		= 8
#
let gRowsInTable=8

#
# Default number of bytes in a framebuffer table
#
# Note: Do NOT change this!
#
let gDataBytes=($gBytesPerRow*$gRowsInTable)

#
# The version info of the running system i.e. '10.9.2'
#
gProductVersion="$(sw_vers -productVersion)"

#
# Giving $# a name.
#
gNumberOfArguments=$#

#
# Supported platformIDs found by _getConnectorTableData.
#
gPlatformIDs=""

#
# Default platformID (initialized by _readPlatformAAPL).
#
let gPlatformID=0

#
# Set to 1 in _checkForDataFile if a data file is selected (used in _showData).
#
let gDataFileSelected=0

#
# Change this to whatever full patch you want to use.
#
# Tip: Use a full path (/Volumes/...) when you have more partitions/drives!
#
TARGET_FILE="/System/Library/Extensions/AppleIntelFramebufferAzul.kext/Contents/MacOS/AppleIntelFramebufferAzul"

#
# Change this to 0 if you don't want additional styling (bold/underlined/colors).
#
let gExtraStyling=1

#
# LC_SYMTAB specific global varables.
#
let gSymbolTableOffset=0
let gNumberOfSymbols=0
let gStringTableOffset=0
let gStringTableSize=0

#
# For internal debugging purposes only.
#
let USE_NM=1

#
# Output styling.
#
STYLE_RESET="\e[0m"
STYLE_BOLD="\e[1m"
STYLE_UNDERLINED="\e[4m"

#
# Color definitions.
#
COLOR_BLACK="\e[1m"
COLOR_RED="\e[1;31m"
COLOR_GREEN="\e[32m"
COLOR_DARK_YELLOW="\e[33m"
COLOR_MAGENTA="\e[1;35m"
COLOR_PURPLE="\e[35m"
COLOR_CYAN="\e[36m"
COLOR_BLUE="\e[1;34m"
COLOR_ORANGE="\e[31m"
COLOR_GREY="\e[37m"
COLOR_END="\e[0m"

#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ gDebug -eq 1 ]];
    then
      printf "$1"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _PRINT_WARNING()
{
  if [[ $gExtraStyling -eq 1 ]];
    then
      printf "${STYLE_BOLD}Warning:${STYLE_RESET} $1"
    else
      printf "Warning: $1"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _PRINT_ERROR()
{
  if [[ $gExtraStyling -eq 1 ]];
    then
      printf "${STYLE_BOLD}Error:${STYLE_RESET} $1"
    else
      printf "Error: $1"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _unsetColors()
{
  STYLE_BOLD=""
  STYLE_UNDERLINED=""

  COLOR_BLACK=""
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_DARK_YELLOW=""
  COLOR_MAGENTA=""
  COLOR_PURPLE=""
  COLOR_CYAN=""
  COLOR_BLUE=""
  COLOR_ORANGE=""
  COLOR_GREY=""
  COLOR_END=""
}

#
#--------------------------------------------------------------------------------
#

function _checkDataLength()
{
  local data=$(echo "$1" | tr -d ' \a\b\f\n\r\t\v')

  _DEBUG_PRINT "Length of $2_PLATFORM_INFO: ${#data}\n"

  if [[ ${#data} -ne $gDataBytes*2+2 ]];
    then
      _PRINT_ERROR "$gPlatformID) $2_PLATFORM_INFO=\"0:... must be ${gDataBytes} bytes!\n" ${#data}
      printf      "       You may need to run: ./$gScriptName dump\n"
      printf      "       to extract the data from the binary!\n"
      printf      "       Tip: Do not add comments to the data sections!\n\n"
      exit -1
  fi
}

#
#--------------------------------------------------------------------------------
#

function _showDelayedDots()
{
  local let index=0

  while [[ $index -lt 3 ]]
  do
    let index++
    sleep 0.150
    printf "."
  done

  sleep 0.200

  if [ $# ];
    then
      printf $1
  fi
}

#
#--------------------------------------------------------------------------------
#

function _initPatchedPlatformInfo()
{
  #
  # Below you'll find the data used for the 'patch' command.
  # Here you make the necessary changes for your setup. Without 
  # changes to the uses data blob, nothing will/can be patched.
  #
  # See also: https://pikeralpha.wordpress.com/2014/08/20/yosemite-dp6-with-hd4600/

  case "$gPlatformID" in
    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c060000) PATCHED_PLATFORM_INFO="0:
                0000 060c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c160000) PATCHED_PLATFORM_INFO="0:
                0000 160c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c260000) PATCHED_PLATFORM_INFO="0:
                0000 260c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04060000) PATCHED_PLATFORM_INFO="0:
                0000 0604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04160000) PATCHED_PLATFORM_INFO="0:
                0000 1604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04260000) PATCHED_PLATFORM_INFO="0:
                0000 2604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260000) PATCHED_PLATFORM_INFO="0:
                0000 260d 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a160000) PATCHED_PLATFORM_INFO="0:
                0000 160a 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a260000) PATCHED_PLATFORM_INFO="0:
                0000 260a 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a260005) PATCHED_PLATFORM_INFO="0:
                0500 260a 0103 0303 0000 0002 0000 3001
                0000 5000 0000 0060 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 8700 0000
                0204 0900 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 0f00 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a260006) PATCHED_PLATFORM_INFO="0:
                0600 260a 0103 0303 0000 0002 0000 3001
                0000 6000 0000 0060 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 8700 0000
                0204 0900 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 0f00 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a2e0008) PATCHED_PLATFORM_INFO="0:
                0800 2e0a 0103 0303 0000 0004 0000 2002
                0000 5001 0000 0060 6c05 0000 6c05 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 0701 0000
                0204 0a00 0004 0000 0701 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0901
                0000 0000 0000 0000 8076 0400 0000 0000
                c07f 0400 0000 0000 3200 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a16000c) PATCHED_PLATFORM_INFO="0:
                0c00 160a 0103 0303 0000 0004 0000 2002
                0000 5001 0000 0060 6c05 0000 6c05 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 0701 0000
                0204 0a00 0004 0000 0701 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0901
                0000 0000 0000 0000 8076 0400 0000 0000
                c07f 0400 0000 0000 3200 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260007) PATCHED_PLATFORM_INFO="0:
                0700 260d 0103 0403 0000 0004 0000 2002
                0000 5001 0000 0060 a107 0000 a107 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0b00 0004 0000 0701 0000
                0204 0b00 0004 0000 0701 0000 0306 0300
                0008 0000 0600 0000 1e03 0000 0505 0900
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 3200 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d220003) PATCHED_PLATFORM_INFO="0:
                0300 220d 0003 0303 0000 0002 0000 3001
                0000 0000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                8700 0000 0204 0a00 0004 0000 8700 0000
                0306 0800 0004 0000 1100 0000 ff00 0000
                0100 0000 4000 0000 0200 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a2e000a) PATCHED_PLATFORM_INFO="0:
                0a00 2e0a 0003 0303 0000 0002 0000 3001
                0000 9000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                1100 0000 0105 0900 0004 0000 8700 0000
                0204 0a00 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 d600 0000 0505 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a26000a) PATCHED_PLATFORM_INFO="0:
                0a00 260a 0003 0303 0000 0002 0000 3001
                0000 9000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                1100 0000 0105 0900 0004 0000 8700 0000
                0204 0a00 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 d600 0000 0505 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a2e000d) PATCHED_PLATFORM_INFO="0:
                0d00 2e0a 0003 0202 0000 0006 0000 2002
                0000 2002 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                0701 0000 0204 0a00 0004 0000 0701 0000
                ff00 0000 0100 0000 4000 0000 0000 0000
                0000 0000 0000 0000 8e04 0000 0005 0500
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a26000d) PATCHED_PLATFORM_INFO="0:
                0d00 260a 0003 0202 0000 0006 0000 2002
                0000 2002 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                0701 0000 0204 0a00 0004 0000 0701 0000
                ff00 0000 0100 0000 4000 0000 0000 0000
                0000 0000 0000 0000 8e04 0000 0005 0500
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04120004) PATCHED_PLATFORM_INFO="0:
                0400 1204 0000 0000 0000 0002 0000 0000
                0000 0000 0000 0010 0000 0000 0000 0000
                0000 0000 0000 0000 ff00 0000 0100 0000
                4000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 0000 0000 0000 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0412000b) PATCHED_PLATFORM_INFO="0:
                0b00 1204 0000 0000 0000 0002 0000 0000
                0000 0000 0000 0010 0000 0000 0000 0000
                0000 0000 0000 0000 ff00 0000 0100 0000
                4000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 0000 0000 0000 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260009) PATCHED_PLATFORM_INFO="0:
                0900 260d 0103 0101 0000 0004 0000 2002
                0000 5001 0000 0060 a107 0000 a107 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0900
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 3200 0000 0e00 0000"
                ;;

    *) _PRINT_ERROR "Unknown ID given or patched data missing!\n"
       exit 1
       ;;
  esac

  _checkDataLength "$PATCHED_PLATFORM_INFO" PATCHED
}

#
#--------------------------------------------------------------------------------
#

function _initFactoryPlatformInfo()
{
  #
  # Do NOT change this data. This data is to undo patched data.
  #
  # Change the data starting with 0xNNNNNNNN) PATCHED_PLATFORM_INFO="0:
  #
  # 1.) Run the following command to extract data from the kext
  #
  #      ./AppleIntelFramebufferAzul.sh dump [TARGET_FILE]
  #
  # 2.) Paste the data into this script

  case "$gPlatformID" in
    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c060000) FACTORY_PLATFORM_INFO="0:
                0000 060c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c160000) FACTORY_PLATFORM_INFO="0:
                0000 160c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0c260000) FACTORY_PLATFORM_INFO="0:
                0000 260c 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04060000) FACTORY_PLATFORM_INFO="0:
                0000 0604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04160000) FACTORY_PLATFORM_INFO="0:
                0000 1604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04260000) FACTORY_PLATFORM_INFO="0:
                0000 2604 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260000) FACTORY_PLATFORM_INFO="0:
                0000 260d 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a160000) FACTORY_PLATFORM_INFO="0:
                0000 160a 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a260000) FACTORY_PLATFORM_INFO="0:
                0000 260a 0003 0303 0000 0004 0000 0001
                0000 f000 0000 0040 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0400 0000 0400 0000
                0204 0900 0008 0000 8200 0000 ff00 0000
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a260005) FACTORY_PLATFORM_INFO="0:
                0500 260a 0103 0303 0000 0002 0000 3001
                0000 5000 0000 0060 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 8700 0000
                0204 0900 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 0f00 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    # AppleIntelAzulController::GetGPUCapability(AGDCGPUCapability_t*)
    #
    0x0a260006) FACTORY_PLATFORM_INFO="0:
                0600 260a 0103 0303 0000 0002 0000 3001
                0000 6000 0000 0060 d90a 0000 d90a 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 8700 0000
                0204 0900 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 0f00 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    # Checked (3x) in: AppleIntelAzulController::InterruptHandler(OSObject*, IOInterruptEventSource*, int)
    #
    0x0a2e0008) FACTORY_PLATFORM_INFO="0:
                0800 2e0a 0103 0303 0000 0004 0000 2002
                0000 5001 0000 0060 6c05 0000 6c05 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 0701 0000
                0204 0a00 0004 0000 0701 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0901
                0000 0000 0000 0000 8076 0400 0000 0000
                c07f 0400 0000 0000 3200 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a16000c) FACTORY_PLATFORM_INFO="0:
                0c00 160a 0103 0303 0000 0004 0000 2002
                0000 5001 0000 0060 6c05 0000 6c05 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0900 0004 0000 0701 0000
                0204 0a00 0004 0000 0701 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0901
                0000 0000 0000 0000 8076 0400 0000 0000
                c07f 0400 0000 0000 3200 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260007) FACTORY_PLATFORM_INFO="0:
                0700 260d 0103 0403 0000 0004 0000 2002
                0000 5001 0000 0060 a107 0000 a107 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 0105 0b00 0004 0000 0701 0000
                0204 0b00 0004 0000 0701 0000 0306 0300
                0008 0000 0600 0000 1e03 0000 0505 0900
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 3200 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d220003) FACTORY_PLATFORM_INFO="0:
                0300 220d 0003 0303 0000 0002 0000 3001
                0000 0000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                8700 0000 0204 0a00 0004 0000 8700 0000
                0306 0800 0004 0000 1100 0000 ff00 0000
                0100 0000 4000 0000 0200 0000 0101 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a2e000a) FACTORY_PLATFORM_INFO="0:
                0a00 2e0a 0003 0303 0000 0002 0000 3001
                0000 9000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                1100 0000 0105 0900 0004 0000 8700 0000
                0204 0a00 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 d600 0000 0505 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a26000a) FACTORY_PLATFORM_INFO="0:
                0a00 260a 0003 0303 0000 0002 0000 3001
                0000 9000 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                1100 0000 0105 0900 0004 0000 8700 0000
                0204 0a00 0004 0000 8700 0000 ff00 0000
                0100 0000 4000 0000 d600 0000 0505 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a2e000d) FACTORY_PLATFORM_INFO="0:
                0d00 2e0a 0003 0202 0000 0006 0000 2002
                0000 2002 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                0701 0000 0204 0a00 0004 0000 0701 0000
                ff00 0000 0100 0000 4000 0000 0000 0000
                0000 0000 0000 0000 8e04 0000 0005 0500
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0a26000d) FACTORY_PLATFORM_INFO="0:
                0d00 260a 0003 0202 0000 0006 0000 2002
                0000 2002 0000 0060 9914 0000 9914 0000
                0000 0000 0000 0000 0105 0900 0004 0000
                0701 0000 0204 0a00 0004 0000 0701 0000
                ff00 0000 0100 0000 4000 0000 0000 0000
                0000 0000 0000 0000 8e04 0000 0005 0500
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0e00 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x04120004) FACTORY_PLATFORM_INFO="0:
                0400 1204 0000 0000 0000 0002 0000 0000
                0000 0000 0000 0010 0000 0000 0000 0000
                0000 0000 0000 0000 ff00 0000 0100 0000
                4000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 0000 0000 0000 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0412000b) FACTORY_PLATFORM_INFO="0:
                0b00 1204 0000 0000 0000 0002 0000 0000
                0000 0000 0000 0010 0000 0000 0000 0000
                0000 0000 0000 0000 ff00 0000 0100 0000
                4000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 0000 0000 0000 0000
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 0000 0000 0000 0000"
                ;;

    #
    # OS X 10.10 Build 14A314h (Developer Preview 5)
    #
    0x0d260009) FACTORY_PLATFORM_INFO="0:
                0900 260d 0103 0101 0000 0004 0000 2002
                0000 5001 0000 0060 a107 0000 a107 0000
                0000 0000 0000 0000 0000 0800 0200 0000
                3000 0000 ff00 0000 0100 0000 4000 0000
                ff00 0000 0100 0000 4000 0000 ff00 0000
                0100 0000 4000 0000 1e00 0000 0505 0900
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000 3200 0000 0e00 0000"
                ;;

    *) _PRINT_ERROR "Unknown ID given or factory data missing!\n"
       exit 1
       ;;
  esac

  _checkDataLength "$FACTORY_PLATFORM_INFO" FACTORY
}

#
#--------------------------------------------------------------------------------
#

function _reverseBytes()
{
  local bytes=$(echo $1 | tr -d ' ')

  if [[ ${#bytes} -eq 8 ]];
    then
      echo 0x${bytes:6:2}${bytes:4:2}${bytes:2:2}${bytes:0:2}
    else
      echo 0x${bytes:14:2}${bytes:12:2}${bytes:10:2}${bytes:8:2}${bytes:6:2}${bytes:4:2}${bytes:2:2}${bytes:0:2}
  fi
}

#
#--------------------------------------------------------------------------------
#

function _readFile()
{
  local offset=$1
  local length=$2

  echo `dd if="$TARGET_FILE" bs=1 skip=$offset count=$length 2> /dev/null | xxd -l $length -ps -c $length`
}

#
#--------------------------------------------------------------------------------
#

function _getSizeOfLoadCommands()
{
  #
  # Read first 32 bytes of target file.
  #
  local machHeaderData=$(_readFile 0 32)
  #
  # Reverse 8 bytes from character offset 40.
  #
  echo $(_reverseBytes ${machHeaderData:40:8})
}

#
#--------------------------------------------------------------------------------
#

function _initSymbolTableVariables
{
  #
  # Get size of load commands from the mach header.
  #
  let sizeOfLoadCommands=$(_getSizeOfLoadCommands)
  #
  # Raise with length of mach header
  #
  let sizeOfLoadCommands+=32
  #
  # Get loadCommand data, in postscript format, from target file.
  #
  local loadCommands=$(xxd -l $sizeOfLoadCommands -ps "$TARGET_FILE" | tr -d '\n')
  #
  #
  #
  let index=64
  #
  # Multiply size of loadComands by 2 (character format).
  #
  let sizeOfLoadCommands=($sizeOfLoadCommands*2)
  #
  # Define target command.
  #
  LC_SYMTAB=0x02000000
  #
  # Main loop, used to search for the "LC_SYMTAB" command.
  #
  while [ $index -lt $sizeOfLoadCommands ];
    do
      local command=0x${loadCommands:($index):8}

      let commandSize=$(_reverseBytes ${loadCommands:($index+8):8})
      #
      # Is this our target command?
      #
      if [ $command == $LC_SYMTAB ];
        then
          #
          # Yes it is. Init variables.
          #
          let gSymbolTableOffset=$(_reverseBytes ${loadCommands:($index+16):8})
          let gNumberOfSymbols=$(_reverseBytes ${loadCommands:($index+24):8})
          let gStringTableOffset=$(_reverseBytes ${loadCommands:($index+32):8})
          let gStringTableSize=$(_reverseBytes ${loadCommands:($index+40):8})

          return
        else
          #
          # No. Not yet. Up index (times 2 for character format).
          #
          let index+=($commandSize*2)
      fi
    done

  _PRINTF_ERROR "Failed to get LC_SYMTAB data!\n"
  exit -1
}

#
#--------------------------------------------------------------------------------
#

function _getConnectorTableOffset()
{
  local offset=0
  #
  # Check if nm (part of Xcode/command line tools) is installed.
  #
  if [[ -e /usr/bin/nm && USE_NM -eq 1 ]];
    then
      #
      # Yes. Get offset to _gPlatformInformationList
      #
      let gConnectorTableOffset=$(nm -t d -Ps __DATA __data -arch "x86_64" "$TARGET_FILE" | grep '_gPlatformInformationList' | awk '{ print $3 }')
    else
      #
      # No. Use backed in NM 'replacment'.
      #
      _initSymbolTableVariables
      #
      # Hex representation of "_gPlatformInformationList"
      #
      _gPlatformInformationList="5f67506c6174666f726d496e666f726d6174696f6e4c697374"
      #
      # Check for old dump file, remove it when found.
      #
      if [[ -e /tmp/stringTableData.txt ]];
        then
          rm /tmp/stringTableData.txt
      fi

      xxd -s $gStringTableOffset -l $gStringTableSize -ps "$TARGET_FILE" | tr -d '\n' | sed "s/${_gPlatformInformationList}[0-9a-f]*//" > /tmp/stringTableData.txt
      #
      # Stat filesize from file.
      #
      let fileSize=$(stat -f %z /tmp/stringTableData.txt)
      #
      # Check filesize (0 would be a failure).
      #
      if [[ -s /tmp/stringTableData.txt ]];
        then
          #
          # Convert number of characters to number of bytes.
          #
          let fileSize/=2
          #
          # Set offset to _gPlatformInformationList in the String Table
          #
          let offset=$gStringTableOffset+$fileSize
          #
          # Checking offset.
          #                                                                         123456789 123456789 12345
          #                                                            (underscore) _
          #
          if [[ $(xxd -s $offset -l 25 -c 25 "$TARGET_FILE" | sed -e 's/.*_//g') == "gPlatformInformationList" ]];
            then
              if [[ gDebug ]];
                then
                  printf "Offset to _gPlatformInformationList found @ 0x%x/$offset\n" $offset
              fi
              #
              # Set start position.
              #
              let start=$gSymbolTableOffset
              #
              # Set length (16-bytes per symbol) and symbolTableEnd.
              #
              let length=($gNumberOfSymbols*16)
              let symbolTableEnd=$gSymbolTableOffset+$length
              #
              # Main loop.
              #
              while [ $start -lt $symbolTableEnd ];
              do
                #
                # Read 8KB chunk from the AppleIntelFramebufferAzul/Capri binary.
                #
                if [[ gDebug ]];
                  then
                    printf "Reading 8192 bytes @ 0x%08x from $gModuleName\n" $start
                fi

                local symbolTableData=$(xxd -s $start -l 8192 -ps "$TARGET_FILE" | tr -d '\n')
                #
                # Reinit index.
                #
                let index=0
                #
                # Secondary loop (16384 characters or 8192 bytes).
                #
                while [ $index -lt 16384 ];
                do
                  let stringTableIndex=$(_reverseBytes ${symbolTableData:($index):8})
                  let currentAddress=$gStringTableOffset+$stringTableIndex
                  #
                  # Is this our target?
                  #
                  if [[ $offset -eq $currentAddress ]];
                    then
                      #
                      # Yes it is. Init gConnectorTableOffset.
                      #
                      let gConnectorTableOffset=$(_reverseBytes ${symbolTableData:($index+16):8})
                      #
                      # Convert number of characters to number of bytes.
                      #
                      let index/=2
                      let stringTableOffset=$start+$index

                      if [[ gDebug ]];
                        then
                          printf "Offset 0x%x/$gConnectorTableOffset to _gPlatformInformationList found @ 0x%x/$stringTableOffset!\n" $gConnectorTableOffset $stringTableOffset
                      fi
                      #
                      # Done.
                      #
                      return
                    else
                      #
                      # Next symbol (16 bytes/32 characters).
                      #
                      let index+=32
                  fi
                done
                #
                # Next chunk.
                #
                let start+=8192

              done
            else
              _PRINT_ERROR "Failed to obtain offset to _gPlatformInformationList!\n"
          fi
      fi
  fi
exit -1
}

#
#--------------------------------------------------------------------------------
#

function _dumpConnectorData()
{
  local offset=0 characters=0
  let characters=($gDataBytes*2)

  printf "    $1) FACTORY_PLATFORM_INFO=\"0:\n"

  while [ $offset -lt $characters ];
    do
      printf "                "
      printf "${2:offset:4} ${2:(offset+4):4} ${2:(offset+8):4} ${2:(offset+12):4} "
      printf "${2:(offset+16):4} ${2:(offset+20):4} ${2:(offset+24):4} ${2:(offset+28):4}"
      let offset+=32

      if [ $offset -eq $characters ];
        then
          printf "\"\n"
        else
          printf "\n"
      fi
	done

  printf "                ;;\n\n"
}

#
#--------------------------------------------------------------------------------
#

function _printInfo()
{
  local text=""
  local deviceID=$(echo $1 | tr '[:lower:]' '[:upper:]')

  case "0x$deviceID" in
    #
    # Ivy Bridge hardware support.
    #
    0x0162) text="Ivy Bridge GT2" ;;
    0x0166) text="Ivy Bridge Mobile GT2" ;;
    #
    # Haswell hardware support.
    #
    0x0402) text="Haswell GT1" ;;
    0x0412) text="Haswell GT2" ;;
    0x0422) text="Haswell GT3" ;;
    0x0406) text="Haswell Mobile GT1" ;;
    0x0416) text="Haswell Mobile GT2" ;;
    0x0426) text="Haswell Mobile GT3" ;;
    #
    # Software Development Vehicle devices.
    #
    0x0C06) text="Haswell SDV Mobile GT1" ;;
    0x0C16) text="Haswell SDV Mobile GT2" ;;
    0x0C26) text="Haswell SDV Mobile GT3" ;;
    #
    # CRW.
    #
    0x0D22) text="Haswell CRW GT3" ;;
    0x0D26) text="Haswell CRW Mobile GT3" ;;
    #
    # Ultra Low TDP/Ultra Low eXtreme TDP.
    #
    0x0A16) text="Haswell ULT Mobile GT2" ;;
    0x0A26) text="Haswell ULT Mobile GT3" ;;
    0x0A2E) text="Haswell ULT E GT3" ;;
  esac

  if [[ $text ]];
    then
      printf "$text"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _showPlatformIDs()
{
  #
  # Are we asked to collect platformIDs?
  #
  if [[ $# -eq 1 ]];
    then
      #
      # Yes. Collect platformIDs, but do not dump the data.
      #
      _getConnectorTableData 1
  fi

  let index=0
  #
  # Split data.
  #
  local data=($gPlatformIDs)

  printf "The supported platformIDs are:\n\n"

  for platformID in "${data[@]}"
  do
    let index++
    printf "[%2d] : ${platformID} - $(_printInfo ${platformID:2:4})\n" $index
  done

  echo ''

  if [[ $1 -eq 0 ]];
    then
      local cancelExitText='Cancel'
    else
      local cancelExitText='Exit'
  fi

  read -p "Please choose a target platform-id ($cancelExitText/1-${index}) ? " selection
  case "$selection" in
    c|C          ) if [[ $1 -ne 0 ]];
                     then
                       _invalidMenuAction $index
                       _showPlatformIDs $1
                     else
                       _clearLines $index+4
                       _showMenu
                   fi
                   ;;

    e|E          ) if [[ $1 -eq 0 ]];
                     then
                       _invalidMenuAction $index+6
                       _showPlatformIDs $1
                     else
                       printf 'Aborting script '
                       _showDelayedDots
                       _clearLines $index+5
                       echo 'Done'
                       exit -0
                   fi
                   ;;

    *[[:alpha:]]*) _invalidMenuAction $index
                   _showPlatformIDs $1
                   ;;

    [[:digit:]]* ) if [[ $selection -gt 0 && $selection -le $index ]];
                     then
                       gPlatformID="${data[$selection-1]}"
                       _clearLines $index+4
                     else
                       _invalidMenuAction $index
                       _showPlatformIDs $1
                   fi
                   ;;

    *            ) _invalidMenuAction $index
                   ;;
  esac
}

#
#--------------------------------------------------------------------------------
#
# Note: Called with one argument ("1") to skip output.
#

function _getConnectorTableData()
{
# _getConnectorTableOffset
  _DEBUG_PRINT "gConnectorTableOffset: $gConnectorTableOffset\n"

  local index platformID=0
  let index=$gConnectorTableOffset
  #
  # Reset variable to prevent duplicated entries.
  #
  gPlatformIDs=""
  #
  # Dump connector table data.
  #
  while [ "$platformID" != "0xffffffff" ];
    do
      local connectorTableData=$(_readFile $index $gDataBytes)
      local platformID=$(_reverseBytes ${connectorTableData:0:8})

      if [ "$platformID" != "0xffffffff" ];
        then
          #
          # Collect platformIDs
          #
          gPlatformIDs+="$platformID "
          #
          # Check number of arguments (zero means print data).
          #
          if [[ $# -eq 0 ]];
             then
               _dumpConnectorData $platformID $connectorTableData
          fi

          let index+=$gDataBytes
        else
          return
      fi
    done
}

#
#--------------------------------------------------------------------------------
#

function _getDataSegmentOffset()
{
  local __DATA=5f5f44415441

  __dataMatch=($(echo `xxd -l 1024 -c 16 "$TARGET_FILE" | grep __data | tr ':' ' '`))

  let __dataOffset="0x$__dataMatch"+16
  __DataMatch=$(echo `xxd -s+$__dataOffset -l 6 -ps "$TARGET_FILE"`)

  if [[ $__DataMatch == $__DATA ]];
    then
      let __dataOffset+=16
      local data=$(echo `xxd -s+$__dataOffset -l 4 -ps "$TARGET_FILE"`)
      let dataSegmentOffset="0x${data:6:2}${data:4:2}${data:2:2}${data:0:2}"
      _DEBUG_PRINT "dataSegmentOffset: ${dataSegmentOffset}\n"

      let __dataOffset+=8
      local data=$(echo `xxd -s+$__dataOffset -l 4 -ps "$TARGET_FILE"`)
      let dataSegmentLength="0x${data:6:2}${data:4:2}${data:2:2}${data:0:2}"
      _DEBUG_PRINT "dataSegmentLength: ${dataSegmentLength}\n"
    else
      echo "Error: DATA segment address not found!"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _getOffset()
{
  local capriMatch=0

  _getDataSegmentOffset
  #
  # Do we have a given/detected platformID?
  #
  if [[ gPlatformID -eq 0 ]];
    then
      #
      # No. Show list with data files/supported platformIDs.
      #
      _checkForDataFile
  fi
  #
  # Do we have a platformID (now)?
  #
  if [[ gPlatformID -gt 0 ]];
    then
      #
      # Yes de do, but it may be unsupported so we are going to check it here.
      #
      printf "AAPL,ig-platform-id: $gPlatformID ($(_printInfo ${gPlatformID:2:4}))"

      platformIDString="${gPlatformID:8:2}${gPlatformID:6:2} ${gPlatformID:4:2}${gPlatformID:2:2}"

      _DEBUG_PRINT "platformIDString: $platformIDString\n"

      local matchingData=$(xxd -s +$dataSegmentOffset -l $dataSegmentLength "$TARGET_FILE" | grep "$platformIDString" | tr -d ':')
      local data=($matchingData);
      let fileOffset="0x${data[0]}"

      if [[ fileOffset -gt 0 ]];
        then
          if [[ gScriptType -eq CAPRI && "$platformIDString" == "${data[5]} ${data[6]}" ]];
            then
              let fileOffset+=8;
              let capriMatch=1
          fi

          if [[ capriMatch -eq 1 || "$platformIDString" == "${data[1]} ${data[2]}" ]];
            then
              printf " found @ 0x%x/$fileOffset\n" $fileOffset
              _setDataFilename
              #
              # Done (offset found in kext).
              #
              return;
          fi
        else
          printf " NOT found in kext!\n\n"
          _PRINT_ERROR 'Retrying '
          sleep 0.500
          _showDelayedDots
          #
          # Zero gPlatformID (we want it to call _checkForDataFile)
          #
          let gPlatformID=0
          #
          # Clear screen (3 lines).
          #
          _clearLines 3
          #
          # Recursive call.
          #
          _getOffset
      fi
    else
      #
      # gPlatformID is zero (happens if no data file was selected).
      #
      _showPlatformIDs 1
      #
      # Recursive call.
      #
      _getOffset
  fi
}

#
#--------------------------------------------------------------------------------
#

function _toLowerCase()
{
  echo "`echo $1 | tr '[:upper:]' '[:lower:]'`"
}

#
#--------------------------------------------------------------------------------
#

function _fileExists()
{
  if [ -e "$1" ];
    then
      echo 1 # "File exists"
    else
      _PRINT_ERROR "File does not exist!\n"
      exit -1
  fi
}

#
#--------------------------------------------------------------------------------
#

function _checkFilename()
{
  if [[ $(_fileExists "$1") -eq 1 ]];
    then
      TARGET_FILE="$1"
    else
      _PRINT_ERROR "File not found error. Check path/filename!\n"
      exit -1
  fi
}

#
#--------------------------------------------------------------------------------
#
function _patchFile()
{
  if [[ "$1" == "patch" ]];
    then
      #
      # Check factory/patched data. Must be different or we can't do anything.
      #
      if [[ $FACTORY_PLATFORM_INFO == $PATCHED_PLATFORM_INFO ]];
        then
          _PRINT_ERROR "Nothing to patch - factory/patched data is the same!\n\n"
          printf "Open $gScriptName with nano (example) and\n"
          printf "change the data labeled $gPlatformID) ${STYLE_BOLD}PATCHED${STYLE_RESET}_PLATFORM_INFO=\"0:\n\n"
          printf "Do NOT patch the data labeled $gPlatformID) ${STYLE_BOLD}FACTORY${STYLE_RESET}_PLATFORM_INFO=\"0:\n"
          printf "because the factory data is used to RESTORE data (read: undo patch)!\n"
          printf "Exiting ...\n"
          exit -1
        else
          echo "---------------------------------------------------------"
          echo $PATCHED_PLATFORM_INFO | xxd -c $gDataBytes -r | dd of="$TARGET_FILE" bs=1 seek=${fileOffset} conv=notrunc
      fi
    else
      echo "---------------------------------------------------------"
      echo $FACTORY_PLATFORM_INFO | xxd -c $gDataBytes -r | dd of="$TARGET_FILE" bs=1 seek=${fileOffset} conv=notrunc
  fi

  if ( _confirmed 'Do you want to reboot now' );
    then
      reboot now
  fi
}

#
#--------------------------------------------------------------------------------
#

function _confirmed()
{
  local answer

  read -p "$1? (y/n) " answer
  case "$answer" in
    y|Y) return 0 ;;
    n|N) return 1 ;;
    *  ) _PRINT_ERROR 'Invalid choice ... \n       Retrying '
         _showDelayedDots
         _clearLines 3
         _confirmed "$1"
         ;;
  esac
}

#
#--------------------------------------------------------------------------------
#

function _megaBytesToHex()
{
  local decimalValue="$1"
  let numberOfBytes="decimalValue <<= 20"
  echo $(printf "0x%08x" $numberOfBytes)
}

#
#--------------------------------------------------------------------------------
#

function _hexToMegaByte()
{
  local value=$(_reverseBytes $1)

  if [[ value -ge 1024 ]];
    then
      if [[ value -ge 1048576 ]];
        then
          let value="value >>= 20"
        else
          let "value >>= 10"
      fi
    else
      let value=0
  fi

  echo $value
}

#
#--------------------------------------------------------------------------------
#

function _hexToPortNumber()
{
  local portNumber=${1:0:4}
  #
  # Check for unused port.
  #
  if [[ $portNumber -ne $2 ]];
    then
      #
      # Is this AppleIntelFramebufferAzul?
      #
      if [[ $2 -eq 255 ]];
        then
          if [[ $portNumber -eq 0 ]];
            then
              let portNumber=0
            else
              let portNumber+=4
          fi
        else
          #
          # No. AppleIntelFramebufferCapri
          #
          if [[ $portNumber -eq 1 ]];
            then
              let portNumber=0
            else
              let portNumber+=3
          fi
      fi

      echo "$portNumber"
    else
      let portNumber=$2
      echo "$portNumber unused"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _savePlatformData()
{
  #
  # Skip checksum checks and confirmation?
  #
  if [[ $# -eq 1 ]];
    then
      #
      # Yes. Silently update/write to the file.
      #
      echo -n "${gDWords[@]}" | tr -d ' ' > "$gDataFile"
      cp "$gDataFile" /tmp/framebuffer.dat
    else
      #
      # step 1: echo gDWords without the trailing newlines character (bash only).
      # step 2: remove spaces.
      # step 3: call sum to get the checksum and block count.
      # step 4: print the first argument, being the checksum.
      #
      local dataCRC=$(echo -n "${gDWords[@]}" | tr -d ' ' | sum | awk '{print $1}')
      #
      # Here we basically do the same (from file) but we can skip step 2.
      #
      local fileCRC=$(cat /tmp/framebuffer.dat | sum | awk '{print $1}')
      #
      # Different checksums?
      #
      if [[ dataCRC -ne fileCRC ]];
        then
          #
          # Yes. Ask user to confirm the action.
          #
          if ( _confirmed 'Do you want to save your changes' );
            then
              #
              # Here the actual writing takes place, without the trailing newline character.
              #
              echo -n "${gDWords[@]}" | tr -d ' ' > "$gDataFile"
              cp "$gDataFile" /tmp/framebuffer.dat
          fi

          _clearLines 1
      fi
  fi
}

#
#--------------------------------------------------------------------------------
#

function _updatePlatformData()
{
  local data index=0
  #
  # Loop through all (56 for Azul) dwords.
  #
  for dword in "${gDWords[@]}"
  do
    data[index++]=$dword
  done

  PATCHED_PLATFORM_INFO="0: ${data[@]}"
}

#
#--------------------------------------------------------------------------------
#

function _getPortName()
{
  local text=''

  case "$1" in
    01000000) text='VGA' ;;
    02000000) text='LVDS' ;;
    04000000) text='eDP' ;;
    00020000) text='DVI' ;;
    00040000) text='DisplayPort' ;;
    00080000) text='HDMI' ;;
    *       ) text='Unknown' ;;
  esac

  echo "${COLOR_ORNGE}$text${COLOR_END}"
}

#
#--------------------------------------------------------------------------------
#

function _clearLines()
{
  let lines=$1

  if [[ ! lines ]];
    then
      let lines=1
  fi

  for ((line=0; line<$lines; line++));
  do
    printf "\e[A\e[K"
  done
}

#
#--------------------------------------------------------------------------------
#

function _invalidMenuAction()
{
  _PRINT_ERROR "Invalid choice!\n       Retrying "
  _showDelayedDots
  _clearLines $1+6
}

#
#--------------------------------------------------------------------------------
#

function _validateMenuAction()
{
  local text=$1
  local items=$2
  local selected=$3
  local action=$4

  echo ''
  read -p "$text (Cancel/1-$items) ? " choice
  case $choice in
    c|C          ) _clearLines $items+4

                   if [[ $action -eq 0 ]];
                     then
                       return
                     else
                       _showMenu
                   fi
                   ;;

    *[[:alpha:]]*) _invalidMenuAction $items
                   #
                   # Is action a function?
                   #
                   if [[ $action =~ '_' ]];
                     then
                       #
                       # Yes. Call target function.
                       #
                       $action
                     else
                       #
                       # No. Call _doAction with target action.
                       #
                       _doAction $action
                   fi
                   ;;

    [[:digit:]]* ) if [[ $choice -eq 0 || $choice -eq $selected || $choice -gt $items ]];
                     then
                       _invalidMenuAction $items
                       _doAction $action
                     else
                       _clearLines $items+4
                       return $choice
                   fi
                   ;;

    *            ) _invalidMenuAction $items
                   _doAction $action
                   ;;
  esac
}

#
#--------------------------------------------------------------------------------
#

function _showModifiedData()
{
  if [[ $1 -eq 1 ]];
    then
      _clearLines $gRowsInTable+1
      echo "Source file: $gDataFile"
    else
      _clearLines $gRowsInTable+2
  fi

  _showData 1
}

#
#--------------------------------------------------------------------------------
#

function _patchPorts
{
  local action framebufferCount
  local portData=($gPortData)
  local portWords=(0000 0105 0204 0306)

  echo "${#portData[2]}"

  let action=0
  let activeFramebuffers=$1

  if [[ $2 -eq 1 ]];
    then
      let action=1
      echo 'Increase number of frame buffers.'
    else
      let action=-1
      echo 'Decrease number of frame buffers.'
  fi

  exit -1
}

#
#--------------------------------------------------------------------------------
#

function _doAction()
{
  local index=0 items=0 action=$1

  case "$action" in
    1  ) _showPlatformIDs 0
         local targetID=$(_reverseBytes "${gPlatformID:2:8}")
         gDWords[0]="${targetID:2:4}"
         gDWords[1]="${targetID:6:4}"
         _setDataFilename
         #
         # Argument '1' used to skip the checksum checks and confirmation.
         #
         _savePlatformData 1

         _clearLines 2
         #
         # Argument '1' used to update the file name.
         #
         _showModifiedData 1
         ;;

    2  ) printf "Change BIOS-allocated memory to:\n\n"
         local stolenMemory=$(_hexToMegaByte "${gDWords[4]}${gDWords[5]}")
         let index=0
         let selected=0

         if [[ $gScriptType -eq CAPRI ]];
           then
             # Ivy Bridge
             local values=(32 64 96 128 160 192 224 256 288 320 352 384 416 448 480 512 1024)
           else
             # Sandy Bridge and Haswell
             local values=(32 64 96 128 160 192 224 256 288 320 352 384 416 448 480 512)
         fi

         for value in "${values[@]}"
         do
           let index++

           if [[ $value == $stolenMemory ]];
             then
               let selected=$index
               printf "[    ] %4s MB (current value)\n"  $value
             else
               printf "[ %2d ] %4s MB\n" $index $value
           fi
         done

         _validateMenuAction "Please choose the amount of memory" $index $selected $action

         if (( $? > 0 ));
           then
             local value=$(_megaBytesToHex "${values[$choice-1]}")
             gDWords[4]=${value:8:2}${value:6:2}
             gDWords[5]=${value:4:2}${value:2:2}
             _showModifiedData
         fi
         ;;

    3  ) printf "Change frame buffer memory to:\n\n"
         #
         # Values taken from the AppleIntelFramebufferAzul.kext binary
         #
         local value currentValue
         local fbMemoryValues=(00000001 00003001 00008001 00002002)
         let index=0
         let selected=0

         for value in "${fbMemoryValues[@]}"
         do
           let index++

           if [[ $value == "${gDWords[6]}${gDWords[7]}" ]];
             then
               let selected=$index
               printf "[   ] %d MB (current)\n" $(_hexToMegaByte $value)
             else
               printf "[ $index ] %d MB\n" $(_hexToMegaByte $value)
           fi
         done

         _validateMenuAction "Please choose the amount of memory you want" 4 $selected $action

         if (( $? > 0 ));
           then
             value=${fbMemoryValues[choice-1]}
             gDWords[6]=${value:0:4}
             gDWords[7]=${value:4:4}
             _showModifiedData
         fi
         ;;

    4  ) printf "Change cursor bytes to:\n\n"
         #
         # Values taken from the AppleIntelFramebufferAzul.kext binary
         #
         local value currentValue
         local cursorBytes=(00000000 00005000 00006000 00009000 0000f000 00005001 00002002)
         local wordCombos=('0200 0000 0101 0000' '0f00 0000 0101 0000' '0f00 0000 0101 0000' \
                           'd600 0000 0505 0000' '0400 000 00000 0700' '1e00 0000 0505 0900' \
                           '8e04 0000 0005 0500')

         let index=0
         let selected=0

         for value in "${cursorBytes[@]}"
         do
           let index++

           if [[ $value == "${gDWords[8]}${gDWords[9]}" ]];
             then
               let selected=$index
               printf "[   ] %2d MB (current)\n" $(_hexToMegaByte $value)
             else
               printf "[ $index ] %2d MB\n" $(_hexToMegaByte $value)
           fi
         done

         _validateMenuAction "Please choose the amount of cursor bytes" 7 $selected $action

         if (( $? > 0 ));
           then
             value=${cursorBytes[$choice-1]}
             gDWords[8]=${value:0:4}
             gDWords[9]=${value:4:4}
             #
             # Update ditto words.
             #
             local words=(${wordCombos[$choice-1]})
             gDWords[44]=${words[0]}
             gDWords[45]=${words[1]}
             gDWords[46]=${words[2]}
             gDWords[47]=${words[3]}
             _showModifiedData
         fi
         ;;

    5  ) printf "Change Video Random Access Memory to:\n\n"
         local value vramIndex

         if [[ $gScriptType -eq CAPRI ]];
           then
             let vramIndex=8
           else
             let vramIndex=10
         fi

         local vram="${gDWords[vramIndex]}${gDWords[vramIndex+1]}"
         #
         # Values taken from the AppleIntelFramebufferAzul/Capri.kext binaries.
         #
         local vramValues=(00000010 00000018 00000030 00000020 00000040 00000060)

         let index=0
         let selected=0

         for value in "${vramValues[@]}"
         do
           let index++

           if [[ $value == $vram ]];
             then
               let selected=$index
               printf "[   ] %4d MB (current)\n" $(_hexToMegaByte $value)
             else
               printf "[ $index ] %4d MB\n" $(_hexToMegaByte $value)
           fi
         done

         _validateMenuAction "Please choose the amount of VRAM" 6 $selected $action

         if (( $? > 0 ));
           then
             value=${vramValues[choice-1]}
              gDWords[vramIndex]=${value:0:4}
              gDWords[vramIndex+1]=${value:4:4}
             _showModifiedData
         fi
         ;;

    6  ) printf "Change backlight frequency to:\n\n"
         local value bclIndex

         if [[ $gScriptType -eq CAPRI ]];
           then
             let bclIndex=10
           else
             let bclIndex=12
         fi

         local frequency="${gDWords[bclIndex]}${gDWords[bclIndex+1]}"
         #
         # Values taken from the AppleIntelFramebufferAzul/Capri.kext binaries.
         #
         local bclFrequency=(6c050000 10070000 a1070000 d90a0000 99140000)

         let index=0
         let selected=0

         for value in "${bclFrequency[@]}"
         do
           let index++

           if [[ $value == $frequency ]];
             then
               let selected=$index
               printf "[   ] %4d Hz (current)\n" $(_reverseBytes $value)
             else
               printf "[ %d ] %4d Hz\n" $index $(_reverseBytes $value)
           fi
         done

         _validateMenuAction "Please choose a backlight frequency" 5 $selected $action

         if (( $? > 0 ));
           then
             frequency=${bclFrequency[choice-1]}
             gDWords[bclIndex]=${frequency:0:4}
             gDWords[bclIndex+1]=${frequency:4:4}
             #
             # Update the curve value (Apple is uses the same value).
             #
             gDWords[bclIndex+2]=${gDWords[bclIndex]}
             gDWords[bclIndex+3]=${gDWords[bclIndex+1]}
             _showModifiedData
         fi
         ;;

    7  ) printf "The backlight frequency and maximum backlight PWM (Pulse Width Modulation)\n"
         printf "are synchronised in this version. At least until I figured out what to do!\n"
         sleep 5
         _clearLines 2
         _showMenu
         ;;

    8  ) printf "Choose the port you like to change:\n\n"
         let index=0
         let selected=0

         for port in "${gPortNumbers[@]}"
         do
           printf "[ %d ] port ${gPortNumbers[index]} (${gConnectorNames[index++]} connector)\n" $index
         done

         _validateMenuAction "Please choose the connector" 4 0 $action

         if (( $? > 0 ));
           then
             local portData=(${gPortData[choice-1]})
         fi

         printf "Change connector type for port ${gPortNumbers[choice-1]} to:\n\n"

         local connectorValues=(01000000 02000000 04000000 00020000 00040000 00080000)
         local connector=${portData[3]}
         let index=0

         for value in "${connectorValues[@]}"
         do
           local connectorName="${COLOR_ORANGE}"$(_getPortName $value)"${COLOR_END}"

           if [[ $connector == "0x${connectorValues[index++]}" ]];
             then
               let selected=$index
               printf "[   ] $connectorName connector (current)\n"
             else
               printf "[ $index ] $connectorName connector\n"
           fi
         done

         _validateMenuAction "Please choose a connector type" 6 $selected $action

         if (( $? > 0 ));
           then
             local connector=${connectorValues[$choice-1]}
             let connectorIndex=${portData[2]}
             gDWords[connectorIndex]=${connector:0:4}
             gDWords[connectorIndex+1]=${connector:4:4}
             _showModifiedData
         fi
         ;;

    9  ) printf "Change number of framebuffers to:\n\n"
         local numberOfFramebuffers
         local words=(One Two Three Four)
         let numberOfFramebuffers=${gDWords[3]:0:2}
         let index=0

         for value in "${words[@]}"
         do
           if [[ index -eq 0 ]];
             then
               # Singular form.
               local text="$value active frame buffer"
             else
               # Plural form.
               local text="$value active frame buffers"
           fi

           let index++

           if [[ numberOfFramebuffers -eq index ]];
             then
               let selected=$index
               printf "[   ] $text (current)\n"
             else
               printf "[ $index ] $text\n"
           fi
         done

         _validateMenuAction "Please choose the number of frame buffers" 4 $selected $action

         if (( $? > 0 ));
           then
             gDWords[3]="0${choice}${gDWords[3]:2:2}"

             if (( numberOfFramebuffers > choice-1 ));
               then
                 _patchPorts -1
               else
                 _patchPorts 1
             fi

             _showModifiedData
         fi
         ;;

    p|P) if ( _confirmed 'Are you sure that you want to patch the kext with this data' );
           then
             _updatePlatformData
             _patchFile "patch"
           else
             _clearLines $items+1
             _showMenu
         fi
         ;;

    g|G) echo "Base64 representation of framebuffer $gDataFile:"
         echo '--------------------------------------------------------------------------------'
         base64 -b 80 "$gDataFile"
         echo ' '
         exit 0
         ;;

    u|U) if ( _confirmed 'Are you sure that you want to restore the factory data' );
           then
             _initFactoryPlatformInfo
             _patchFile "restore"
           else
             _clearLines $items+1
             _showMenu
         fi
         ;;
  esac
}

#
#--------------------------------------------------------------------------------
#

function _showMenu()
{
  printf "What would you like to do next?\n\n"
  printf "[ 1 ] Change the ${COLOR_BLACK}platform-id${COLOR_END}\n"
  printf "[ 2 ] Change the amount of ${COLOR_RED}BIOS-allocated memory${COLOR_END}\n"
  printf "[ 3 ] Change the amount of ${COLOR_BLUE}frame buffer memory${COLOR_END}\n"
  printf "[ 4 ] Change the amount of ${COLOR_GREEN}cursor bytes${COLOR_END}\n"
  printf "[ 5 ] Change the amount of ${COLOR_MAGENTA}VRAM${COLOR_END}\n"
  printf "[ 6 ] Change the ${COLOR_CYAN}backlight frequency${COLOR_END}\n"
  printf "[ 7 ] Change the ${COLOR_PURPLE}maximum backlight PWM${COLOR_END} (Pulse Width Modulation)\n"
  printf "[ 8 ] Change the ${COLOR_ORANGE}connector type${COLOR_END}\n"
  printf "[ 9 ] Change number of frame buffers\n"
  printf "[ G ] Generate Base64 data\n"
  printf "[ P ] Patch "

  printf "$gModuleName.kext\n"
  printf "[ U ] Undo frame buffer changes\n\n"

  read -p "Please choose the action to perform (Exit/1-9/G/P/U) ? " choice
  case "$(_toLowerCase $choice)" in
    [1-9gpu]) _clearLines 16
              _doAction $choice
              ;;

    e|E     ) _clearLines 16
              _savePlatformData
              echo 'Done'
              exit 0
              ;;

    *       ) _invalidMenuAction 12
              _showMenu
              ;;
  esac
}

#
#--------------------------------------------------------------------------------
#

function _initPortData()
{
  local portIndex=($1 $1+6 $1+12 $1+18)
  local connectorIndex=($1+2 $1+8 $1+14 $1+20)
  local unusedPort i=0 port=255 index=0

  for portIndex in "${portIndex[@]}"
  do
    let port=0x${gDWords[portIndex]:0:2}

    if [[ port -eq $2 ]];
      then
        let unusedPort=1
      else
        let unusedPort=0

        if [[ $2 -eq 255 ]];
          then
            if [[ port -ne 0 ]];
              then
                let port+=4
            fi
          else
            if [[ port -eq 1 ]];
              then
                let port=0
              else
                let port+=3
            fi
        fi
    fi

    let index=${connectorIndex[i]}
    local connector=0x${gDWords[index]}${gDWords[index+1]}

    case $connector in
      0x01000000) connectorName='VGA' ;;
      0x02000000) connectorName='LVDS' ;;
      0x04000000) connectorName='eDP' ;;
      0x00020000) connectorName='DVI' ;;
      0x00040000) connectorName='DisplayPort' ;;
      0x00080000) connectorName='HDMI' ;;
      *         ) connectorName='Unknown' ;;
    esac

    gPortData[i]="${portIndex[i]} $port ${connectorIndex[i]} $connector $connectorName"

    if [[ unusedPort -eq 1 ]];
      then
        port="unused"
    fi

    gPortNumbers[i]="${COLOR_BLUE}$port${COLOR_END}"
    gConnectorNames[i++]="${COLOR_ORANGE}$connectorName${COLOR_END}"
  done
}

#
#--------------------------------------------------------------------------------
#

function _getDWords()
{
  local i index
  #
  # Do we have a matching data file or a filename?
  #
# if [[ ! -e /tmp/framebuffer.dat || $# -eq 0 ]];
  if [[ $# -eq 0 ]];
    then
      #
      # No. Extract data from kext and create the file.
      #
      xxd -s $fileOffset -l $gDataBytes -ps "$TARGET_FILE" | tr -d '\n' > /tmp/framebuffer.dat
      cp /tmp/framebuffer.dat $gDataFile
    else
      if [[ -e $gDataFile ]];
        then
          cp $gDataFile /tmp/framebuffer.dat
      fi
  fi

  let i=0
  let index=0
  let dwords=(gDataBytes/2)
  local asci=$(cat $gDataFile)

  while [[ index -lt dwords ]]
  do
    gDWords[index++]=${asci:i:4}
    let i+=4
  done
}

#
#--------------------------------------------------------------------------------
#

function _showData()
{
  local offset=$fileOffset

  if [[ $# -eq 0 ]];
    then
      if [[ -e $gDataFile && gDataFileSelected -eq 1 ]];
        then
          printf "Source file: $gDataFile\n"
          _getDWords 1
        else
          printf "Source file: $TARGET_FILE\n"
          _getDWords
      fi
  fi

  echo "--------------------------------------------------------------------------"
  printf "%08x: ${COLOR_BLACK}${gDWords[0]} ${gDWords[1]}${COLOR_END} ${gDWords[2]} " $offset
  printf "${gDWords[3]} ${COLOR_RED}${gDWords[4]} ${gDWords[5]}${COLOR_END} ${COLOR_BLUE}${gDWords[6]} ${gDWords[7]}${COLOR_END} ("

  local stolenMemory=$(_hexToMegaByte "${gDWords[4]}${gDWords[5]}")
  local framebufferMemory=$(_hexToMegaByte "${gDWords[6]}${gDWords[7]}")

  printf "${COLOR_RED}%d MB${COLOR_END} BIOS-allocated memory, ${COLOR_BLUE}%d MB${COLOR_END} frame buffer memory)\n" $stolenMemory $framebufferMemory
  #
  # Is this AppleIntelFramebuffeAzul?
  #
  if [[ "$TARGET_FILE" =~ "AppleIntelFramebufferAzul" ]];
    then
      #
      # 20 is the index (offset) to the first port (dword) and 255 is used to check for unused ports.
      #
      _initPortData 20 255

      let offset+=16
      printf "%08x: ${COLOR_GREEN}${gDWords[8]} ${gDWords[9]}${COLOR_END} ${COLOR_MAGENTA}${gDWords[10]} ${gDWords[11]}${COLOR_END} " $offset
      printf "${COLOR_CYAN}${gDWords[12]} ${gDWords[13]}${COLOR_END} ${COLOR_PURPLE}${gDWords[14]} ${gDWords[15]}${COLOR_END} ("

      local cursorBytes=$(_hexToMegaByte "${gDWords[8]}${gDWords[9]}")
      local vram=$(_hexToMegaByte "${gDWords[10]}${gDWords[11]}")
      local backlightFrequency=$(_reverseBytes "${gDWords[12]}${gDWords[13]}")
      local backlightMax=$(_reverseBytes "${gDWords[14]}${gDWords[15]}")

      printf "${COLOR_GREEN}%s MB${COLOR_END} cursor bytes, ${COLOR_MAGENTA}%d MB${COLOR_END} VRAM, BCL " $cursorBytes $vram
      printf "freq. ${COLOR_CYAN}%d${COLOR_END} Hz, max. BCL PWM ${COLOR_PURPLE}%d${COLOR_END} Hz)\n" $backlightFrequency $backlightMax

      let offset+=16
      printf "%08x: ${gDWords[16]} ${gDWords[17]} ${gDWords[18]} ${gDWords[19]} " $offset
      printf "${COLOR_BLUE}${gDWords[20]:0:2}${COLOR_END}${gDWords[20]:2:2} ${gDWords[21]} ${COLOR_ORANGE}${gDWords[22]} "
      printf "${gDWords[23]}${COLOR_END} (port ${gPortNumbers[0]}, ${gConnectorNames[0]} connector)\n"

      let offset+=16
      printf "%08x: ${gDWords[24]} ${gDWords[25]} ${COLOR_BLUE}${gDWords[26]:0:2}${COLOR_END}" $offset
      printf "${gDWords[26]:2:2} ${gDWords[27]} ${COLOR_ORANGE}${gDWords[28]} ${gDWords[29]}${COLOR_END} ${gDWords[30]} ${gDWords[31]} ("
      printf "port ${gPortNumbers[1]}, ${gConnectorNames[1]} connector)\n"

      let offset+=16
      printf "%08x: ${COLOR_BLUE}${gDWords[32]:0:2}${COLOR_END}${gDWords[32]:2:2} ${gDWords[33]} " $offset
      printf "${COLOR_ORANGE}${gDWords[34]} ${gDWords[35]}${COLOR_END} ${gDWords[36]} ${gDWords[37]} ${COLOR_BLUE}${gDWords[38]:0:2}${COLOR_END}"
      printf "${gDWords[38]:2:2} ${gDWords[39]} (port ${gPortNumbers[2]}, ${gConnectorNames[2]} connector / port ${gPortNumbers[3]})\n"

      let offset+=16
      printf "%08x: ${COLOR_ORANGE}${gDWords[40]} ${gDWords[41]}${COLOR_END} ${gDWords[42]} ${gDWords[43]} " $offset
      printf "${COLOR_GREY}${gDWords[44]} ${gDWords[45]}${COLOR_END} ${gDWords[46]} ${gDWords[47]} (${gConnectorNames[3]} connector)\n"

      let offset+=16
      printf "%08x: ${gDWords[48]} ${gDWords[49]} ${gDWords[50]} ${gDWords[51]} ${gDWords[52]} ${gDWords[53]} ${gDWords[54]} ${gDWords[55]}\n\n" $offset
    else
      #
      # No. AppleIntelFramebuffeCapri
      #
      # 24 is the index (offset) to the first port (dword) and 0 is used to check for unused ports.
      #
      _initPortData 24 0

      let offset+=16
      printf "%08x: ${COLOR_MAGENTA}${gDWords[8]} ${gDWords[9]}${COLOR_END} ${COLOR_CYAN}${gDWords[10]} ${gDWords[11]}"  $offset
      printf "${COLOR_END} ${COLOR_PURPLE}${gDWords[12]} ${gDWords[13]}${COLOR_END} ${gDWords[14]} ${gDWords[15]} ("

      local vram=$(_hexToMegaByte "${gDWords[8]}${gDWords[9]}")
      local backlightFrequency=$(_reverseBytes "${gDWords[10]}${gDWords[11]}")
      local backlightMax=$(_reverseBytes "${gDWords[12]}${gDWords[13]}")
      printf "${COLOR_MAGENTA}%d MB${COLOR_END} VRAM, ${COLOR_CYAN}%d Hz${COLOR_END} " $vram $backlightFrequency
      printf "backlight frequency, ${COLOR_PURPLE}%d${COLOR_END} Max backlight)\n" $backlightMax

      let offset+=16
      printf "%08x: ${gDWords[16]} ${gDWords[17]} ${gDWords[18]} ${gDWords[19]} " $offset
      printf "${gDWords[20]} ${gDWords[21]} ${gDWords[22]} ${gDWords[23]}\n"

      let offset+=16
      printf "%08x: ${COLOR_BLUE}${gDWords[24]:0:2}${COLOR_END}${gDWords[24]:2:2} " $offset
      printf "${gDWords[25]} ${COLOR_ORANGE}${gDWords[26]} "
      printf "${gDWords[27]}${COLOR_END} ${gDWords[28]} ${gDWords[29]} "
      printf "${COLOR_BLUE}${gDWords[30]:0:2}${COLOR_END}${gDWords[30]:2:2} ${gDWords[31]} ("
      printf "port ${COLOR_BLUE}${gPortNumbers[0]}${COLOR_END}, ${gConnectorNames[0]} connector / "
      printf "port ${COLOR_BLUE}${gPortNumbers[1]}${COLOR_END}, ...)\n"

      let offset+=16
      printf "%08x: ${COLOR_ORANGE}${gDWords[32]} ${gDWords[33]}${COLOR_END} ${gDWords[34]} ${gDWords[35]} " $offset
      printf "${COLOR_BLUE}${gDWords[36]:0:2}${COLOR_END}${gDWords[36]:2:2} "
      printf "${gDWords[37]} ${COLOR_ORANGE}${gDWords[38]} ${gDWords[39]}${COLOR_END} ("
      printf "${COLOR_ORANGE}${gConnectorNames[1]}${COLOR_END} connector / port "
      printf "${COLOR_BLUE}${gPortNumbers[2]}${COLOR_END}, ${COLOR_ORANGE}${gConnectorNames[2]}${COLOR_END} connector)\n"

      let offset+=16
      printf "%08x: ${gDWords[40]} ${gDWords[41]} ${COLOR_BLUE}${gDWords[42]:0:2}" $offset
      printf "${COLOR_END}${gDWords[42]:2:2} ${gDWords[43]} "
      printf "${COLOR_ORANGE}${gDWords[44]} ${gDWords[45]}${COLOR_END} ${gDWords[46]} ${gDWords[47]} ("
      printf "port ${COLOR_BLUE}${gPortNumbers[3]}${COLOR_END}, ${COLOR_ORANGE}${gConnectorNames[3]}${COLOR_END} connector)\n"

      let s=47

      for i in {1..6}
      do
        let offset+=16
        printf "%08x: " $offset

        for x in {1..8}
        do
          printf "${gDWords[s+x]} "
        done

        let s+=8
        printf "\n"
      done

      let offset+=16
      printf "%08x: ${gDWords[++s]} ${gDWords[++s]} ${gDWords[++s]} ${gDWords[++s]}\n\n" $offset
  fi

  _showMenu
}

#
#--------------------------------------------------------------------------------
#

function _readPlatformID()
{
  #
  # Get AAPL,XXX-platform-id from ioreg.
  #
  local result=$(/usr/sbin/ioreg -p IODeviceTree -c IOPCIDevice -k $gTargetProperty | grep $gTargetProperty | awk '{print $5}' | sed -e 's/[<>]//g')
  #
  # Property found?
  #
  if [[ $result ]];
    then
      #
      # Yes. Use it.
      #
      gPlatformID=$(_reverseBytes $result)
  fi
}

#
#--------------------------------------------------------------------------------
#

function _checkForDataFile()
{
  local target files filename index=0

  case $gScriptType in
    SNB  ) target='Snb' ;;
    CAPRI) target='Capri' ;;
    AZUL ) target='Azul' ;;
  esac

  local files=(`ls $target-0x*.dat 2> /dev/null`)

  if [[ ${#files[@]} -gt 0 ]];
    then
      if [[ ${#files[@]} -gt 1 ]];
        then
          printf "The following data files are available:\n\n"

          for filename in "${files[@]}"
          do
            let index++
            printf "[ $index ] $filename\n"
          done

          let index++
          printf "[ $index ] Show list with platformIDs\n"

          _validateMenuAction "Please choose a data file" $index 0 _checkForDataFile

          case "$choice" in
            c|C         ) echo 'Done'
                          exit
                          ;;

            n|N         ) let gDataFileSelected=0
                          ;;

            [[:digit:]]*) if (( choice > 0 && choice < index ));
                            then
                              let gDataFileSelected=1
                              filename="${files[$choice-1]}"
                              #
                              # Strip 'Snb-', 'Capri-' or 'Azul-' and '.dat'.
                              #
                              gPlatformID=$(echo $filename | sed -e "s/$target-//" -e "s/\.dat//")
                            else
                              if [[ choice -ne index ]];
                                then
                                  #
                                  # Invalid menu action, retrying.
                                  #
                                  _checkForDataFile
                              fi
                          fi

                          ;;
          esac
        else
          #
          # Single data file found.
          #
          filename="${files[0]}"

          printf "The following data file was found:\n\n"
          printf "[ 1 ] $filename\n\n"

          read -p "Do you want to use it (y/n) ? " choice
            case "$choice" in
              1|y|Y) let gDataFileSelected=1
                     #
                     # Strip 'Snb-', 'Capri-' or 'Azul-' and '.dat'.
                     #
                     gPlatformID=$(echo $filename | sed -e "s/$target-//" -e "s/\.dat//")
                     _clearLines 5
                     ;;

              n|N  ) let gDataFileSelected=0
                     _clearLines 5
                     ;;

              *    ) _invalidMenuAction 1
                     _checkForDataFile
                     ;;
          esac
      fi
  fi
}

#
#--------------------------------------------------------------------------------
#

function _initScriptGlobals()
{
  let UNKNOWN=0
  let SNB=1
  let CAPRI=2
  let AZUL=3
  #
  # Init script type (global variable).
  #
  case "$gScriptName"  in
    *'Azul'* ) gScriptType=AZUL ;;
    *'Capri'*) gScriptType=CAPRI ;;
    *'Sandy'*) gScriptType=SNB ;;
    *        ) gScriptType=UNKNOWN ;;
  esac
  #
  # Check script type to select the target platform-id property and modulename.
  #
  case $gScriptType in
    SNB  ) gModuleName='AppleIntelSNBGraphicsFB'
           gTargetProperty="AAPL,snb-platform-id"
           ;;
    CAPRI) gModuleName='AppleIntelFramebufferCapri'
           gTargetProperty="AAPL,ig-platform-id"
           ;;
    AZUL ) gModuleName='AppleIntelFramebufferAzul'
           gTargetProperty="AAPL,ig-platform-id"
           ;;
  esac
}

#
#--------------------------------------------------------------------------------
#

function _setDataFilename()
{
  #
  # Set filename (global variable).
  #
  case $gScriptType in
    SNB  ) gDataFile="Snb-${gPlatformID}.dat" ;;
    CAPRI) gDataFile="Capri-${gPlatformID}.dat" ;;
    AZUL ) gDataFile="Azul-${gPlatformID}.dat" ;;
    *    ) gDataFile="Unknown-${gPlatformID}.dat" ;;
  esac
}

#
#--------------------------------------------------------------------------------
# Modified copy of function in freqVectorsEdit.sh
#

function _readPreferences()
{
  #
  # Is PlistBuddy installed?
  #
  if [ ! -f /usr/libexec/PlistBuddy ];
    then
      #
      # No. Download it.
      #
      printf 'PlistBuddy not found ... Downloading PlistBuddy '
      _showDelayedDots "\n"
      curl https://raw.github.com/Piker-Alpha/freqVectorsEdit.sh/master/Tools/PlistBuddy -o /usr/libexec/PlistBuddy --create-dirs
      chmod +x /usr/libexec/PlistBuddy
      printf 'Done.'
  fi
  #
  # The actual pref read bits should be added here (still unused).
  #
}

#
#--------------------------------------------------------------------------------
#

function _main()
{
  clear
  printf "\n$gScriptName v$gScriptVersion Copyright (c) 2012-$(date "+%Y") by Pike R. Alpha\n"
  echo '--------------------------------------------------------------------------'
  #
  # Do we want colored data?
  #
  if [[ $gExtraStyling -ne 1 ]];
    then
      #
      # Nope.
      #
      _unsetColors
  fi

  _readPreferences
  #
  # Is there a temporarily data file?
  #
  if [[ -e /tmp/framebuffer.dat ]];
    then
      #
      # Yes. Remove it (fresh start).
      #
      rm /tmp/framebuffer.dat
  fi

  if [[ $(_fileExists "$TARGET_FILE") -eq 1 ]];
    then
      #
      # Check script name and change target (kext) filename.
      #
      if [[ $gScriptType -eq CAPRI ]];
        then
          TARGET_FILE=$(echo "$TARGET_FILE" | sed -e 's/Azul/Capri/g')
      fi
      #
      # Get offset (used in _getConnectorTableData as start address).
      #
      _getConnectorTableOffset
      #
      # Check filename (adds backward compatibility).
      #
      if [[ "$TARGET_FILE" =~ "AppleIntelFramebufferCapri" ]];
        then
          let gDataBytes=($gBytesPerRow*125)/10
          let gRowsInTable=13
        else
          #
          # Check OS version and re-initialise gRowsInTable.
          #
          case "$(echo $gProductVersion | sed -e 's/^10\.//' -e 's/\.[0-9]*//')" in
            7|8 ) # Lion and Mountain Lion
                  let gRowsInTable=7
                  ;;
            9|10) # Mavericks and Yosemite
                  let gRowsInTable=8
                  ;;
          esac
          #
          # Override the default number of bytes (at top of script).
          #
          let gDataBytes=($gBytesPerRow*$gRowsInTable)
      fi
      #
      # Are we asked to dump the factory data?
      #
      if [[ $action == "dump" ]];
        then
          #
          # Yes.
          #
          echo "---------------------------------------------------------"
          #
          # Dump the factory data.
          #
          _getConnectorTableData
          #
          # And done (no error).
          #
          return
      fi

      _getOffset
      #
      # Figure out the 'action' to perform.
      #
      case "$action" in
        patch|replace) _initPatchedPlatformInfo
                       _patchFile "patch"
                       ;;
        restore|undo ) _initFactoryPlatformInfo
                       _patchFile "restore"
                       ;;
        show|*       ) _showData
                       ;;
      esac
    else
      _PRINT_ERROR "File not found error. Check path/filename in this script!\n"
  fi
}

#
#--------------------------------------------------------------------------------
#

function _exitWithUsageInfo()
{
  echo "Usage: [sudo] $0 AAPL,ig-platform-id [dump|show|patch|replace|undo|restore] [TARGET_FILE]"
  exit 1
}

#==================================== START =====================================

#
# Are we root?
#
if [[ gID -ne 0 ]];
  then
    #
    # No, ask for password and run script as root (with elevated privileges).
    #
    clear
    printf "This script ${STYLE_UNDERLINED}must${STYLE_RESET} be run as root!\n" 1>&2
    sudo "$0" "$@"
  else
    #
    # Set script type from script name.
    #
    _initScriptGlobals
    #
    # Select action based on (number of) arguments.
    #
    case "$gNumberOfArguments" in
      0) _readPlatformID
         action=""
         ;;

      1) if [[ $(_toLowerCase $1) == '-h' ]];
           then
             _exitWithUsageInfo
         fi

         if [[ $(_toLowerCase $1) == 'dump' ]];
           then
             action='dump'
           else
             action='show'

             if [[ $(_toLowerCase $1) == 'show' ]];
               then
                 _readPlatformID
               else
                 gPlatformID=$(_toLowerCase $1)
             fi
         fi
         ;;

      2) if [[ $(_toLowerCase $1) == 'dump' ]];
           then
             action='dump'
             _checkFilename "$2"
         fi

         if [[ $(_toLowerCase $2) == 'show' ]];
           then
             action='show'
             gPlatformID=$(_toLowerCase $1)
         fi
         ;;

      3) action=$(_toLowerCase $2)

         if [[ $action == 'patch' || action == 'replace' || $action == 'undo' || action == 'restore' ]];
           then
             _checkFilename "$3"
             gPlatformID=$(_toLowerCase $1)
         fi
         ;;

      *) _exitWithUsageInfo
         ;;
    esac

    _main
fi
