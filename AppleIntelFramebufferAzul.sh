#!/bin/sh

#
# This script is a stripped/rewrite of AppleIntelSNBGraphicsFB.sh 
#
# Version 0.9 - Copyright (c) 2012 by † RevoGirl
# Version 1.8 - Copyright (c) 2013 by Pike R. Alpha <PikeRAlpha@yahoo.com>
#
#
# Updates:
#			- v1.0 no longer requires/calls nm (Pike, August 2013)
#			- v1.1 no longer requires/calls otool (Pike, August 2013)
#			- v1.2 cleanups (Pike, August 2013)
#			- v1.3 support for optional filename added (Pike, October 2013)
#			- v1.4 asks to reboot (Pike, June 2014)
#			- v1.5 table data dumper added (Pike, August 2014)
#			-      table data replaced with that of Yosemite DP5 (Pike, August 2014)
#			- v1.6 adjustable framebuffer size (Pike, August 2014)
#			-      askToReboot() was lost/added again (Pike, August 2014)
#			-      dump now reads the correct [optional] file argument (Pike, August 2014)
#			- v1.7 read LC_SYMTAB to get offset to _gPlatformInformationList i.e.
#			-      dump now works <em>with</em> and <em>without</em> nm (Pike, August 2014)
#			-      typo fixed, layout changes (whitespace) and other improvements (Pike, August 2014)
#			- v1.8 fixed a small error (0x0x instead of 0x) in _dumpConnectorData (Pike, August 2014)
#

gScriptVersion=1.8

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
# Number of rows in a framebuffer table
#
# Lion          = 7
# Mountain Lion = 7
# Mavericks     = 8
# Yosemite      = 8
#
let gRowsInTable=8

#
# Number of bytes in a framebuffer table
#
# Note: Do NOT change this!
#
let gDataBytes=($gBytesPerRow*$gRowsInTable)

#
# Giving $# a name.
#
gNumberOfArguments=$#

#
# Change this to whatever full patch you want to use.
#
# Tip: Use a full path (/Volumes/...) when you have more partitions/drives!
#
TARGET_FILE="/System/Library/Extensions/AppleIntelFramebufferAzul.kext/Contents/MacOS/AppleIntelFramebufferAzul"

#
# Change this to 0 if you don't want additional styling (bold/underlined).
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

function _initFactoryPlatformInfo()
{
  #
  # Do NOT change this data. It is used to restore the factory data!
  #
  # 1.) Run the following command to extract data from the kext
  #
  #      ./AppleIntelFramebufferAzul.sh dump
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
}


#
#--------------------------------------------------------------------------------
#

function _initPatchedPlatformInfo()
{
  #
  # Change the target platform info (used by "patch" and "replace")
  #

  case "$id" in
    0x0c060000) PATCHED_PLATFORM_INFO="0:
                0000 060C 0003 0303 0000 0004 0000 0001
                0000 F000 0000 0040 9914 0000 9914 0000
                0000 0000 0000 0000 0000 1000 0200 0000
                3000 0000 0105 1200 0400 0000 0400 0000
                0204 1200 0008 0000 8200 0000 FF00 0100
                0100 0000 4000 0000 0400 0000 0000 0700
                0400 0000 0000 0000 0000 0000 0000 0000
                0000 0000 0000 0000"
                ;;

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
          _dumpConnectorData $platformID $connectorTableData

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

  if [ "$platformIDString" == "${data[1]} ${data[2]}" ];
    then
      echo "\nAAPL,ig-platform-id: $id located @ $fileOffset"
      #
      # Done.
      #
      return;
    else
      _PRINT_ERROR "AAPL,ig-platform-id: $id NOT found! Aborting ...\n\n"
      exit 1
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

function _askToReboot()
{
  read -p "Do you want to reboot now? (y/n) " rebootChoice
  case "$rebootChoice" in
    y|Y ) reboot now
          ;;
  esac
}


#
#--------------------------------------------------------------------------------
#

function _main()
{
  clear
  printf "\nAIFBAzul.sh v$gScriptVersion Copyright (c) 2012-$(date "+%Y") by Pike R. Alpha\n"
  echo  "---------------------------------------------------------"
  echo  "Reading file: $TARGET_FILE"

  if [[ -f "$TARGET_FILE" ]];
    then
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

      _initFactoryPlatformInfo
      _initPatchedPlatformInfo
      _getOffset

      if [[ $action == "show" ]];
        then
          echo "---------------------------------------------------------"
          xxd -s +$fileOffset -l 128 -c 16 "$TARGET_FILE"
          echo ""
      fi

      if [[ $action == "patch" || $action == "replace" ]];
        then
          echo "---------------------------------------------------------"
          #
          # Check factory/patched data (must be different, or we won't restore anything)
          #
          if [[ $FACTORY_PLATFORM_INFO == $PATCHED_PLATFORM_INFO ]];
            then
              echo "\nWarning: Nothing to patch - factory/patched data is the same!\n"
            else
              echo $PATCHED_PLATFORM_INFO | xxd -c 128 -r | dd of="$TARGET_FILE" bs=1 seek=${fileOffset} conv=notrunc
              _askToReboot
          fi
      fi

      if [[ $action == "restore" || $action == "undo" ]];
        then
          echo "---------------------------------------------------------"
          #
          # Check factory/patched data (must be different, or we won't restore anything)
          #
          # TODO: We should check the binary against the factory data!
          #
          if [[ $FACTORY_PLATFORM_INFO == $PATCHED_PLATFORM_INFO ]];
            then
              echo "\nWarning: Nothing to patch - factory/patched data is the same!\n"
            else
              echo $FACTORY_PLATFORM_INFO | xxd -c 128 -r | dd of="$TARGET_FILE" bs=1 seek=${fileOffset} conv=notrunc
              _askToReboot
          fi
      fi
    else
      echo "\nError: File not found (check path in script)!\n"
  fi
}


#==================================== START =====================================

#
# Check number of arguments.
#
if [ $gNumberOfArguments -eq 0 ];
  then
    echo "Usage: sudo $0 AAPL,ig-platform-id [dump|show|patch|replace|undo|restore] [TARGET_FILE]"
    exit 1
  else
    id=$(_toLowerCase $1)

    if [ "$id" == "dump" ];
      then
        action=$(_toLowerCase $1)

        if [ $gNumberOfArguments -eq 2 ];
          then
            if [[ $(_fileExists "$2") -eq 1 ]];
              then
                TARGET_FILE="$2"
            fi
        fi
      else
        action=$(_toLowerCase $2)

        if [ $gNumberOfArguments -eq 3 ];
          then
            if [[ -f "$3" ]]; then
              TARGET_FILE="$3"
            fi
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
