#!/bin/sh

#
# This script is a stripped/rewrite of AppleIntelSNBGraphicsFB.sh 
#
# Version 0.9 - Copyright (c) 2012 by † RevoGirl
# Version 1.5 - Copyright (c) 2013 by Pike R. Alpha <PikeRAlpha@yahoo.com>
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
#

gScriptVersion=1.6

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


#--------------------------------------------------------------------------------

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

    *) echo "Error: Unknown ID given – factory data missing!"
       exit 1
       ;;
  esac
}

#--------------------------------------------------------------------------------

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

    *) echo "Error: Unknown ID given – patched data missing!"
       exit 1
       ;;
  esac
}


#--------------------------------------------------------------------------------

function _readFile()
{
  local offset=$1
  local length=$2

  echo `dd if="$TARGET_FILE" bs=1 skip=$offset count=$length 2> /dev/null | xxd -l $length -ps -c $length`
}


#--------------------------------------------------------------------------------

function _getConnectorTableOffset()
{
  local architecture="x86_64"

  #
  # Check if nm (part of Xcode/command line tools) is installed.
  #
  if [[ -e /usr/bin/nm  ]];
    then
      #
      # Yes. Get offset to _gPlatformInformationList
      #
      echo `nm -t d -Ps __DATA __data -arch $architecture "$TARGET_FILE" | grep '_gPlatformInformationList' | awk '{ print $3 }'`
    else
      #
      # No nm found. Error out.
      #
      # TODO: Read symbol table to get the offset to _gPlatformInformationList
      #
      _PRINT_ERROR "This options requires nm, install command line tools (Xcode)"

      exit -1
  fi
}


#--------------------------------------------------------------------------------

function _dumpConnectorData()
{
  local let offset=0
  let characters=($gDataBytes*2)

  printf "    0x$1) FACTORY_PLATFORM_INFO=\"0:\n"

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


#--------------------------------------------------------------------------------

function _getConnectorTableData()
{
  let connectorTableOffset=$(_getConnectorTableOffset)

  _DEBUG_PRINT "connectorTableOffset: $connectorTableOffset\n"

  local platformID=0
  local let index=$connectorTableOffset

  #
  # Dump connector table data.
  #
  while [ "$platformID" != "ffffffff" ];
    do
      local connectorTableData=$(_readFile $index $gDataBytes)

      local platformID=${connectorTableData:6:2}${connectorTableData:4:2}${connectorTableData:2:2}${connectorTableData:0:2}

      if [ "$platformID" != "ffffffff" ];
        then
          _dumpConnectorData $platformID $connectorTableData

          let index+=$gDataBytes
        else
          return
      fi
    done

}


#--------------------------------------------------------------------------------

function _getDataSegmentOffset()
{
  __dataMatch=($(echo `xxd -l 1024 -c 16 "$TARGET_FILE" | grep __data | tr ':' ' '`))
  let __dataOffset="0x$__dataMatch"+16

  __DataMatch=$(echo `xxd -s+$__dataOffset -l 6 -ps "$TARGET_FILE"`)

  if [[ $__DataMatch == 5f5f44415441 ]];
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


#--------------------------------------------------------------------------------

function _getOffset()
{
  _getDataSegmentOffset

  platformIDString="${id:8:2}${id:6:2} ${id:4:2}${id:2:2}"

  printf "platformIDString: $platformIDString\n"

  matchingData=$(xxd -s +$dataSegmentOffset -l $dataSegmentLength "$TARGET_FILE" | grep "$platformIDString" | tr ':' ' ')

  data=($matchingData);
  let fileOffset="0x${data[0]}"

  targetID="${id:8:2}${id:6:2}${id:4:2}${id:2:2}"

  let end=$fileOffset+0x10

  while [ $fileOffset -lt $end ];
    do
      bytes=$(xxd -s +$fileOffset -l 4 -ps "$TARGET_FILE")

      if [ $bytes == $targetID ];
        then
          echo "\nAAPL,ig-platform-id: $id located @ $fileOffset"
          return;
        else
          let fileOffset+=1
      fi
    done

  if [[ $fileOffset -eq $end ]];
    then
      _PRINT_ERROR "AAPL,ig-platform-id: $id NOT found! Aborting ...\n\n"
      exit 1
  fi
}


#--------------------------------------------------------------------------------

function _toLowerCase()
{
  echo "`echo $1 | tr '[:upper:]' '[:lower:]'`"
}


#--------------------------------------------------------------------------------

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


#--------------------------------------------------------------------------------

function _askToReboot()
{
  read -p "\nDo you want to reboot now? (y/n) " rebootChoice
  case "$rebootChoice" in
    y/Y ) reboot now
          ;;
  esac
}


#--------------------------------------------------------------------------------

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
