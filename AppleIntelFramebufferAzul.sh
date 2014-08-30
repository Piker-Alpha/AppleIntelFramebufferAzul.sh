#!/bin/sh

#
# This script is a stripped/rewrite of AppleIntelSNBGraphicsFB.sh 
#
# Version 0.9 - Copyright (c) 2012 by † RevoGirl
# Version 2.5 - Copyright (c) 2013 by Pike R. Alpha <PikeRAlpha@yahoo.com>
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
#			- v2.3  read property AAPL,ig-platform-id from ioreg and use it as default target.
#			-       helper functions _hexToMegaByte, _hexToPortName and _hexToPortNumber added.
#			- v2.4  function _showColorizedData added.
#           -       changed _hexToMegaByte a little.
#           -       LVDS added to _hexToPortName.
#			- v2.5  _showColorizedData now also support Capri.
#			-       cleanups and comments added.
#			-       function _printInfo added.
#

gScriptVersion=2.5

#
# Used to print the name of the running script
#

gScriptName=$(echo $0 | sed -e 's/^\.\///')

#
# Setting the debug mode (default off).
#
let DEBUG=0

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
let gCurrentPlatformID=0

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
STYLE_RESET="[0m"
STYLE_BOLD="[1m"
STYLE_UNDERLINED="[4m"


#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ $DEBUG -eq 1 ]];
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

function _checkDataLength()
{
  local data=$(echo "$1" | tr -d ' \a\b\f\n\r\t\v')

  _DEBUG_PRINT "Length of $2_PLATFORM_INFO: ${#data}\n"

  if [[ ${#data} -ne $gDataBytes*2+2 ]];
    then
      _PRINT_ERROR "$id) $2_PLATFORM_INFO=\"0:... must be ${gDataBytes} bytes!\n" ${#data}
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

  case "$id" in
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

  case "$id" in
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
  if [[ ${#1} -eq 8 ]];
    then
      echo 0x${1:6:2}${1:4:2}${1:2:2}${1:0:2}
    else
      echo 0x${1:14:2}${1:12:2}${1:10:2}${1:8:2}${1:6:2}${1:4:2}${1:2:2}${1:0:2}
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
  #
  # Check if nm (part of Xcode/command line tools) is installed.
  #
  if [[ -e /usr/bin/nm && $USE_NM -eq 1 ]];
    then
      #
      # Yes. Get offset to _gPlatformInformationList
      #
      let connectorTableOffset=$(nm -t d -Ps __DATA __data -arch "x86_64" "$TARGET_FILE" | grep '_gPlatformInformationList' | awk '{ print $3 }')
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
                # Read 8KB chunk from the AppleIntelFramebufferAzul binary.
                #
                _DEBUG_PRINT "Reading 8192 bytes @ 0x%08x from AppleIntelFramebufferAzul\n" $start
                local symbolTableData=$(xxd -s $start -l 8192 -ps "$TARGET_FILE" | tr -d '\n')
                #
                # Reinit index.
                #
                let index=0
                #
                # Secondary loop.
                #
                while [ $index -lt 8192 ];
                do
                  let stringTableIndex=$(_reverseBytes ${symbolTableData:($index):8})
                  let currentAddress=$gStringTableOffset+$stringTableIndex
                  #
                  # Is this our target?
                  #
                  if [[ $offset -eq $currentAddress ]];
                    then
                      #
                      # Yes it is. Init connectorTableOffset.
                      #
                      let connectorTableOffset=$(_reverseBytes ${symbolTableData:($index+16):8})
                      #
                      # Convert number of characters to number of bytes.
                      #
                      let index/=2
                      let stringTableOffset=$start+$index

                      _DEBUG_PRINT "Offset $connectorTableOffset to _gPlatformInformationList found @ 0x%08x/$stringTableOffset!\n" $stringTableOffset
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
}


#
#--------------------------------------------------------------------------------
#

function _dumpConnectorData()
{
  local let offset=0
  let characters=($gDataBytes*2)

  printf "    $1) FACTORY_PLATFORM_INFO=\"0:\n"

  while [ $offset -lt $characters ];
    do
      printf "                "
      printf "${2:$offset:4} ${2:($offset+4):4} ${2:($offset+8):4} ${2:($offset+12):4} "
      printf "${2:($offset+16):4} ${2:($offset+20):4} ${2:($offset+24):4} ${2:($offset+28):4}"
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
  # Is this a recursive call?
  #
  if [[ $# -eq 0 ]];
    then
      _getConnectorTableData 1
    else
      clear
  fi

  let index=0
  #
  # Split data.
  #
  local data=($gPlatformIDs)

  printf "The supported platformIDs are:\n------------------------------\n\n"

  for platformID in ${data[@]}
  do
    let index++
    printf "[%2d] : ${platformID} - $(_printInfo ${platformID:2:4})\n" $index
  done

  echo ''

  read -p "Please choose a target platformID (0/1-${index}) ? " selection

  if [[ $selection -eq 0 ]];
    then
      printf "Aborting "
      _showDelayedDots "\n\n"
      exit -0
    else
      if [[ $selection -gt 0 && $selection -le $index ]];
        then
          id="${data[$selection-1]}"
          echo ''
          #
          # Reset variable to prevent duplicated entries.
          #
          gPlatformIDs=""
          _getOffset
        else
          echo ''
          _PRINT_ERROR "Invalid selection!\nRetrying "
          _showDelayedDots
          #
          # Argument '1' signals a recursive call.
          #
          _showPlatformIDs 1
      fi
  fi
}


#
#--------------------------------------------------------------------------------
#
# Note: Called with one argument ("1") to skip output.
#

function _getConnectorTableData()
{
  _getConnectorTableOffset
  _DEBUG_PRINT "connectorTableOffset: $connectorTableOffset\n"

  local platformID=0
  local let index=$connectorTableOffset

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
      data=$(echo `xxd -s+$__dataOffset -l 4 -ps "$TARGET_FILE"`)
      let dataSegmentOffset="0x${data:6:2}${data:4:2}${data:2:2}${data:0:2}"
      _DEBUG_PRINT "dataSegmentOffset: ${dataSegmentOffset}\n"

      let __dataOffset+=8
      data=$(echo `xxd -s+$__dataOffset -l 4 -ps "$TARGET_FILE"`)
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
  _getDataSegmentOffset
  #
  # Not used: too slow without nm.
  #
  # _getConnectorTableOffset
  platformIDString="${id:8:2}${id:6:2} ${id:4:2}${id:2:2}"

  _DEBUG_PRINT "platformIDString: $platformIDString\n"

  matchingData=$(xxd -s +$dataSegmentOffset -l $dataSegmentLength "$TARGET_FILE" | grep "$platformIDString" | tr -d ':')
  #
  # Not used: too slow without nm.
  #
  # matchingData=$(xxd -s $connectorTableOffset -l 4096 "$TARGET_FILE" | grep "$platformIDString" | tr -d ':')

  data=($matchingData);
  let fileOffset="0x${data[0]}"

  if [[ "$platformIDString" == "${data[1]} ${data[2]}" || "$platformIDString" == "${data[5]} ${data[6]}" ]];
    then
      printf "AAPL,ig-platform-id: $id ("
      printf "$(_printInfo ${id:2:4})"
      printf ") found @ 0x%x/$fileOffset\n" $fileOffset
      #
      # Done.
      #
      return;
    else
      _PRINT_ERROR "AAPL,ig-platform-id: $id NOT found!\n\n"
      #
      # Show list with platform IDs.
      #
      _showPlatformIDs
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
          printf "change the data labeled $id) ${STYLE_BOLD}PATCHED${STYLE_RESET}_PLATFORM_INFO=\"0:\n\n"
          printf "Do NOT patch the data labeled $id) ${STYLE_BOLD}FACTORY${STYLE_RESET}_PLATFORM_INFO=\"0:\n"
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

  read -p "Do you want to reboot now? (y/n) " rebootChoice
  case "$rebootChoice" in
    y|Y) reboot now
         ;;
  esac
}


#
#--------------------------------------------------------------------------------
#

function _showPlainTextData()
{
  xxd -s +$fileOffset -l $gDataBytes -c 16 "$TARGET_FILE"
}


#
#--------------------------------------------------------------------------------
#

function _hexToMegaByte()
{
  local value=$(_reverseBytes $1)

  if [[ $value -ge 1024 ]];
    then
      if [[ $value -ge 1048576 ]];
        then
#         let value=($value/1024/1024)
          let value="value >>= 20"
        else
#         let value=($value/1024)
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
  local  portNumber=${1:0:4}
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

function _hexToPortName()
{
  local text=''

  case "$1" in
    0x01000000) text='VGA' ;;
    0x02000000) text='LVDS' ;;
    0x04000000) text='eDP' ;;
    0x00020000) text='DVI' ;;
    0x00040000) text='DisplayPort' ;;
    0x00080000) text='HDMI' ;;
    *         ) text='Unknown' ;;
  esac

  echo "\e[31m$text\e[0m"
}


#
#--------------------------------------------------------------------------------
#

function _showColorizedData()
{
  local data=($(xxd -s +$fileOffset -l $gDataBytes -c 16 "$TARGET_FILE" | sed -e 's/\. \.//g'))

  printf "${data[0]} \e[1m${data[1]} ${data[2]}\e[0m ${data[3]} "
  printf "${data[4]} \e[1;31m${data[5]} ${data[6]}\e[0m \e[1;34m${data[7]} ${data[8]}\e[0m ("

  local stolenMemory=$(_hexToMegaByte "${data[5]}${data[6]}")
  local framebufferMemory=$(_hexToMegaByte "${data[7]}${data[8]}")

  printf "\e[1;31m%d MB\e[0m BIOS-allocated memory, \e[1;34m%d MB\e[0m framebuffer)\n" $stolenMemory $framebufferMemory

  #
  # Is this AppleIntelFramebuffeAzul?
  #
  if [[ "$TARGET_FILE" =~ "AppleIntelFramebufferAzul" ]];
    then
      printf "${data[10]} \e[32m${data[11]} ${data[12]}\e[0m \e[1;35m${data[13]} ${data[14]}\e[0m "
      printf "\e[36m${data[15]} ${data[16]}\e[0m \e[0;35m${data[17]} ${data[18]}\e[0m ("

      local cursorBytes=$(_hexToMegaByte "${data[11]}${data[12]}")
      local vram=$(_hexToMegaByte "${data[13]}${data[14]}")
      local backlightFrequency=$(_reverseBytes "${data[15]}${data[16]}")
      local backlightMax=$(_reverseBytes "${data[17]}${data[18]}")

      printf "\e[32m%s MB\e[0m cursor bytes, \e[1;35m%d MB\e[0m VRAM, backlight frequency " $cursorBytes $vram
      printf "\e[36m%d Hz\e[0m, \e[0;35m%d\e[0m Max backlight)\n"  $backlightFrequency $backlightMax
      printf "${data[20]} ${data[21]} ${data[22]} ${data[23]} ${data[24]} "
      printf "\e[1;34m${data[25]:0:2}\e[0m${data[25]:2:2} ${data[26]} \e[31m${data[27]} ${data[28]}\e[0m ("

      local portNumber=$(_hexToPortNumber "0x${data[25]}" 0xff)
      local portName=$(_hexToPortName "0x${data[27]}${data[28]}")

      printf "port \e[1;34m$portNumber\e[0m, $portName connector)\n"
      printf "${data[30]} ${data[31]} ${data[32]} \e[1;34m${data[33]:0:2}\e[0m"
      printf "${data[33]:2:2} ${data[34]}\e[31m ${data[35]} ${data[36]}\e[0m ${data[37]} ${data[38]} ("

      local portNumber=$(_hexToPortNumber "0x${data[33]}" 0xff)
      local portName=$(_hexToPortName "0x${data[35]}${data[36]}")

      printf "port \e[1;34m$portNumber\e[0m, $portName connector)\n"
      printf "${data[40]} \e[1;34m${data[41]:0:2}\e[0m${data[41]:2:2} ${data[42]} "
      printf "\e[31m${data[43]} ${data[44]}\e[0m ${data[45]} ${data[46]} "
      printf "\e[1;34m${data[47]:0:2}\e[0m${data[47]:2:2} ${data[48]} ("

      local portNumber=$(_hexToPortNumber "0x${data[41]}" 0xff)
      local portNumber2=$(_hexToPortNumber "0x${data[47]}" 0xff)
      local portName=$(_hexToPortName "0x${data[43]}${data[44]}")

      printf "port \e[1;34m$portNumber\e[0m, $portName connector / port \e[1;34m$portNumber2\e[0m)\n"
      printf "${data[50]} \e[31m${data[51]} ${data[52]}\e[0m ${data[53]} ${data[54]} "
      printf "\e[4;33m${data[55]} ${data[56]}\e[0m ${data[57]} ${data[58]} ("

      local portName=$(_hexToPortName "0x${data[51]}${data[52]}")

      printf "$portName connector)\n"
      printf "${data[60]} ${data[61]} ${data[62]} ${data[63]} ${data[64]} ${data[65]} ${data[66]} ${data[67]} ${data[68]}\n\n"
    else
      #
      # No. AppleIntelFramebuffeCapri
      #
      printf "${data[10]} \e[1;35m${data[11]} ${data[12]}\e[0m \e[1;36m${data[13]} ${data[14]}\e[0m "
      printf "\e[35m${data[15]} ${data[16]}\e[0m ${data[17]} ${data[18]} ("

      local vram=$(_hexToMegaByte "${data[11]}${data[12]}")
      local backlightFrequency=$(_reverseBytes "${data[13]}${data[14]}")
      local backlightMax=$(_reverseBytes "${data[15]}${data[16]}")

      printf "\e[1;35m%d MB\e[0m VRAM, \e[1;36m%d Hz\e[0m backlight frequency, \e[0;35m%d\e[0m Max backlight)\n" $vram $backlightFrequency $backlightMax
      printf "${data[20]} ${data[21]} ${data[22]} ${data[23]} ${data[24]} ${data[25]} ${data[26]} ${data[27]} ${data[28]}\n"
      printf "${data[30]} \e[1;34m${data[31]:0:2}\e[0m${data[31]:2:2} ${data[32]} \e[31m${data[33]} "
      printf "${data[34]}\e[0m ${data[35]} ${data[36]} \e[1;34m${data[37]:0:2}\e[0m${data[37]:2:2} ${data[38]} ("

      local portNumber=$(_hexToPortNumber "0x${data[31]}" 0)
      local portName=$(_hexToPortName "0x${data[33]}${data[34]}")
      local portNumber2=$(_hexToPortNumber "0x${data[37]}" 0)

      printf "port \e[1;34m$portNumber\e[0m, $portName connector / port \e[1;34m$portNumber2\e[0m, ...)\n"
      printf "${data[40]} \e[31m${data[41]} ${data[42]}\e[0m ${data[43]} ${data[44]} "
      printf "\e[1;34m${data[45]:0:2}\e[0m${data[45]:2:2} ${data[46]} \e[31m${data[47]} ${data[48]}\e[0m ("

      local portName=$(_hexToPortName "0x${data[41]}${data[42]}")
      local portNumber=$(_hexToPortNumber "0x${data[45]}" 0)
      local portName2=$(_hexToPortName "0x${data[47]}${data[48]}")

      printf "\e[31m$portName\e[0m connector / port \e[1;34m$portNumber\e[0m, \e[31m$portName2\e[0m connector)\n"
      printf "${data[50]} ${data[51]} ${data[52]} \e[1;34m${data[53]:0:2}\e[0m${data[53]:2:2} ${data[54]} "
      printf "\e[31m${data[55]} ${data[56]}\e[0m ${data[57]} ${data[58]} ("

      local portNumber=$(_hexToPortNumber "0x${data[53]}" 0)
      local portName=$(_hexToPortName "0x${data[55]}${data[56]}")

      printf "port \e[1;34m$portNumber\e[0m, \e[31m$portName\e[0m connector)\n"
      printf "${data[60]} ${data[61]} ${data[62]} ${data[63]} ${data[64]} ${data[65]} ${data[66]} ${data[67]} ${data[68]}\n"
      printf "${data[70]} ${data[71]} ${data[72]} ${data[73]} ${data[74]} ${data[75]} ${data[76]} ${data[77]} ${data[78]}\n"
      printf "${data[80]} ${data[81]} ${data[82]} ${data[83]} ${data[84]} ${data[85]} ${data[86]} ${data[87]} ${data[88]}\n"

      printf "${data[90]} ${data[91]} ${data[92]} ${data[93]} ${data[94]} ${data[95]} ${data[96]} ${data[97]} ${data[98]}\n"
      printf "${data[100]} ${data[101]} ${data[102]} ${data[103]} ${data[104]} ${data[105]} ${data[106]} ${data[107]} ${data[108]}\n"
      printf "${data[110]} ${data[111]} ${data[112]} ${data[113]} ${data[114]} ${data[115]} ${data[116]} ${data[117]} ${data[118]}\n"
      printf "${data[120]} ${data[121]} ${data[122]} ${data[123]} ${data[124]}\n\n"
  fi
}


#
#--------------------------------------------------------------------------------
#

function _readPlatformID()
{
  #
  # Check script name to select target property.
  #
  if [[ "$gScriptName" =~ "SNB" ]];
    then
      local targetProperty="AAPL,snb-platform-id"
    else
      local targetProperty="AAPL,ig-platform-id"
  fi

  _DEBUG_PRINT $targetProperty

  local result=$(/usr/sbin/ioreg -p IODeviceTree -c IOPCIDevice -k $targetProperty | grep $targetProperty | awk '{print $5}' | sed -e 's/[<>]//g')

  if [[ $result ]];
    then
      gCurrentPlatformID=$(_reverseBytes $result)
  fi
}

#
#--------------------------------------------------------------------------------
#

function _main()
{
  clear
  printf "\n$gScriptName v$gScriptVersion Copyright (c) 2012-$(date "+%Y") by Pike R. Alpha\n"
  echo  "--------------------------------------------------------------------------"

  if [[ $(_fileExists "$TARGET_FILE") -eq 1 ]];
    then
      #
      # Check script name add change target filename.
      #
      if [[ "$gScriptName" =~ "AppleIntelFramebufferCapri.sh" ]];
        then
          TARGET_FILE=$(echo "$TARGET_FILE" | sed -e 's/Azul/Capri/g')
      fi
      #
      # Check filename (adds backward compatibility).
      #
      if [[ "$TARGET_FILE" =~ "AppleIntelFramebufferCapri" ]];
        then
          let gDataBytes=($gBytesPerRow*125)/10
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

      echo "Reading file: $TARGET_FILE\n"
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
        show|*       ) echo "--------------------------------------------------------------------------\n"

                       if [[ $gExtraStyling -eq 1 ]];
                         then
                           _showColorizedData
                         else
                           _showPlainTextData
                       fi
                       ;;
      esac
    else
      _PRINT_ERROR "File not found error. Check path/filename in this script!\n"
  fi
}


#==================================== START =====================================

#
# Check number of arguments.
#
if [ $gNumberOfArguments -eq 0 ];
  then
    _readPlatformID

    if [[ $gCurrentPlatformID -eq 0 ]];
      then
        echo "Usage: sudo $0 AAPL,ig-platform-id [dump|show|patch|replace|undo|restore] [TARGET_FILE]"
        exit 1
      else
        id=$gCurrentPlatformID
        action="show"
        _main
    fi
  else
    id=$(_toLowerCase $1)

    if [ "$id" == "dump" ];
      then
        action=$id

        if [ $gNumberOfArguments -eq 2 ];
          then
            _checkFilename "$2"
        fi
      else
        action=$(_toLowerCase $2)

        if [ $gNumberOfArguments -eq 3 ];
          then
            _checkFilename "$3"
        fi
    fi

    if [[ $action == "patch" || $action == "replace" ]];
      then
        #
        # Are we root?
        #
        if [[ $(id -u) -ne 0 ]];
          then
            #
            # No, ask for password and run script as root (with elevated privileges).
            #
            clear
            echo "This script ${STYLE_UNDERLINED}must${STYLE_RESET} be run as root!" 1>&2
            sudo "$0" "$@"
          else
            _main
        fi
      else
        _main
    fi
fi
