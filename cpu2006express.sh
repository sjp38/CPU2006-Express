#!/bin/bash

##############################################################################
#  cpu2006express.sh - This utility performs SPEC CPU2006 benchmarking using
#  GCC. Capabilities include in installing prerequisites, building and
#  installing SPEC CPU2006, and running reportable integer and floating-point
#  runs.

#
#  Required file tree:
#
#  |-- config
#  |   |-- linux32-arm32-gcc.cfg
#  |   |-- linux32-intel32-gcc.cfg
#  |   |-- linux64-arm64-gcc.cfg
#  |   |-- linux64-intel64-gcc.cfg
#  |   `-- linux64-powerpc-gcc.cfg
#  |
#  |-- bin
#  |   |-- setup.sh
#  |   |-- spinner.sh
#  |   `-- user_input.sh
#  |
#  |-- cpu2006-*.tar* (You provide this file)
#  |
#  `-- cpu2006express.sh
#
#
#  Usage: cpu2006express.sh [OPTIONS]...
#
#  Option          GNU long option         Meaning
#   -h             --help                  Show this message
#   -r             --rebuild               Force SPEC CPU2006 rebuild and installation
#   -o             --onecopy               Do a single copy run
#   -i             --int                   Run integer
#   -f             --fp                    Run floating-point
#   -c             --complete              Do a complete run (int and fp) with defaults
#   -p             --prereq                Install prerequisites
#   -q             --quiet                 Show less detailed information
#
##############################################################################
#
#  Last Updated:
#     4/15/2015
#
#  Authors/Contributors:
#     Ryan Spoone (github.com/ryanspoone)
#     Tyler Stachecki (github.com/tj90241)
#     Matthew Nicely (github.com/manicely6005)
#
##############################################################################

############################################################
# Import sources
############################################################

source "$(pwd)/bin/spinner.sh"
source "$(pwd)/bin/user_input.sh"
source "$(pwd)/bin/setup.sh"

############################################################
# Argument switch variables
############################################################
VERBOSE=true
REBUILD=false
NOPREREQ=true
INT=false
FP=false
NOCOPY=false

############################################################
# Flag parsing
############################################################
if [[ "$#" -gt 0 ]]; then
  while [ "$1" ]; do
    ARG="$1"
    if [[ "$ARG" == "-q" || "$ARG" == "--quiet" ]]; then
      VERBOSE=false
      shift
    elif [[ "$ARG" == "-o" || "$ARG" == "--onecopy" ]]; then
      NOCOPY=true
      shift
    elif [[ "$ARG" == "-c" || "$ARG" == "--complete" ]]; then
      INT=true
      FP=true
      NOPREREQ=false
      shift
    elif [[ "$ARG" == "-r" || "$ARG" == "--rebuild" ]]; then
      REBUILD=true
      shift
    elif [[ "$ARG" == "-p" || "$ARG" == "--prereq" ]]; then
      NOPREREQ=false
      shift
    elif [[ "$ARG" == "-i" || "$ARG" == "--int" ]]; then
      INT=true
      shift
    elif [[ "$ARG" == "-f" || "$ARG" == "--fp" ]]; then
      FP=true
      shift
    elif [[ "$ARG" == "-h" || "$ARG" == "--help" ]]; then
      echo "Usage: cpu2006express.sh [OPTIONS]..."
      echo
      echo "Option          GNU long option         Meaning"
      echo " -h             --help                  Show this message"
      echo " -r             --rebuild               Force SPEC CPU2006 rebuild and installation"
      echo " -o             --onecopy               Do a single copy run"
      echo " -i             --int                   Run integer"
      echo " -f             --fp                    Run floating-point"
      echo " -c             --complete              Do a complete run (int and fp) with defaults"
      echo " -p             --prereq                Install prerequisites"
      echo " -q             --quiet                 Show less detailed information"
      exit
    else
      echo "cpu2006express: invalid operand ‘$ARG’"
      echo "Try 'cpu2006express --help' for more information."
      exit
    fi
  done
else
  echo
  echo "Usage: cpu2006express.sh [OPTIONS]..."
  echo "Try 'cpu2006express --help' for more information."
  echo
  exit
fi

############################################################
# Double check if user really meant no int and fp runs
############################################################
if [[ $INT == false  && $FP == false ]]; then
  echo -n "You picked no runs. Is this correct (y/n)? "
  read NORUN
  if [[ "$NORUN" == *"n"* ]]; then
    echo -n "Would you like an integer run (y/n)?"
    read INT_ANS
    if [[ "$INT_ANS" == *"y"* ]]; then
      INT=true
    fi
    echo -n "Would you like an floating-point run (y/n)?"
    read FP_ANS
    if [[ "$FP_ANS" == *"y"* ]]; then
      FP=true
    fi
  fi
fi

############################################################
# Set environment stack size
############################################################
ulimit -s unlimited

############################################################
# Will display make, type, and model number
# Example: GenuineIntel
############################################################
CPU=$(grep 'vendor_id' /proc/cpuinfo | uniq | sed 's/vendor_id\s*:\s//g')

############################################################
# If CPU is still empty
# This is mainly for Intel systems
# Example: Intel Atom C2750
# Example: Intel Xeon E5-1650 0
############################################################
if [ -z "$CPU" ]; then
  CPU=$(grep 'model name' /proc/cpuinfo | uniq | sed 's/model name\s*:\s//g')
fi

############################################################
# If CPU is empty
# This is mainly for ARM systems
# Example: AArch64 Processor rev 0
############################################################
if [ -z "$CPU" ]; then
  CPU=$(grep 'Processor' /proc/cpuinfo | uniq | sed 's/Processor\s*:\s//g')
fi

############################################################
# If CPU is still empty
# This is mainly for PowerPC systems
# Example: POWER8 (raw), altivec supported
############################################################
if [ -z "$CPU" ]; then
  CPU=$(grep 'cpu' /proc/cpuinfo | uniq | sed 's/cpu\s*:\s//g')
fi

############################################################
# Get OS and version
# Example OS: Ubuntu
# Example VER: 14.04
############################################################
if [ -f /etc/lsb-release ]; then
  . /etc/lsb-release
  OS=$DISTRIB_ID
  VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  OS='Debian'
  VER=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
  OS='Redhat'
  VER=$(cat /etc/redhat-release)
else
  OS=$(uname -s)
  VER=$(uname -r)
fi

############################################################
# GCC version
############################################################
GCC_VER=$(gcc --version | sed -rn 's/gcc\s\(.*\)\s([0-9]*\.[0-9]*\.[0-9]*)/\1/p')
GCC_VER_NO_DOTS=${GCC_VER//\./}
export GCC_VER_SHORT=${GCC_VER_NO_DOTS:0:2}
if [ -z "$GCC_VER" ]; then
  echo "Cannot determine GCC version."
fi

############################################################
# Detect os architecture, os distribution, and os version
# Displays bits, either 64 or 32
############################################################
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

############################################################
# If it is an ARM system
############################################################
if [[ $ARCH == *'aarch64'* || $ARCH == *'arm'* ]]; then
  # Get the ARM version number
  ARM_V=$(echo "$ARCH" | sed 's/armv//g' | sed 's/[^0-9]*//g')
  # If ARMv8 or greater, set to 62 bit
  if [ "$ARM_V" -ge '8' || $ARCH == *'aarch64'* ]; then
    ARCH='64'
  else
    ARCH='32'
  fi
fi

############################################################
# Virtual cores / logical cores / threads
############################################################
LOGICAL_CORES=$(grep -c processor /proc/cpuinfo)

############################################################
# The amount of RAM needed to run all copies of SPEC
############################################################
REQUIRED_RAM=$((LOGICAL_CORES * 2))

############################################################
# Get RAM in KB
############################################################
RAM_KB=$(grep "MemTotal:      " /proc/meminfo | sed "s/MemTotal:      //g" | tr -d ' ' | sed "s/kB//g")

############################################################
# Convert RAM to GB
############################################################
RAM_GB=$((RAM_KB / 1000 / 1000))

############################################################
# Set number of copies the hardware can handle
############################################################
if [[ $NOCOPY == false ]]; then
  if [[ $RAM_GB > $REQUIRED_RAM ]]; then
    COPIES=$LOGICAL_CORES
  else
    COPIES=$((RAM_GB / 2))
  fi
else
  COPIES='1'
fi

############################################################
# The name of the target machine architecture
############################################################
if [[ $CPU == *'Power'* || $CPU == *'power'* || $CPU == *'POWER'* || $CPU == *'ppc'* ]]; then
  MARCH=$(gcc -mcpu=native -Q --help=target 2> /dev/null | grep '\-mcpu=' | head -n 1 | sed "s/-mcpu=//g" | tr -d " \t\n\r")
  MTUNE=$(gcc -mcpu="$MARCH" -mtune=native -Q --help=target 2> /dev/null | grep '\-mtune=' | head -n 1 | sed "s/-mtune=//g" | tr -d " \t\n\r")
else
  MARCH=$(gcc -march=native -Q --help=target 2> /dev/null | grep '\-march=' | head -n 1 | sed "s/-march=//g" | tr -d " \t\n\r")
  MTUNE=$(gcc -march="$MARCH" -mtune=native -Q --help=target 2> /dev/null | grep '\-mtune=' | head -n 1 | sed "s/-mtune=//g" | tr -d " \t\n\r")
fi

############################################################
# Select the proper config file
############################################################
if [[ $CPU == *'Intel'* ]]; then
  if [[ $ARCH == *'32'* ]]; then
    GCC_CONFIG='linux32-intel32-gcc'
  else
    GCC_CONFIG='linux64-intel64-gcc'
  fi
elif [[ $CPU == *'ARM'* ]] || [[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]; then
  if [[ $ARCH == *'32'* ]]; then
    GCC_CONFIG='linux32-arm32-gcc'
  else
    GCC_CONFIG='linux64-arm64-gcc'
  fi
elif [[ $CPU == *'Power'* || $CPU == *'power'* || $CPU == *'POWER'* || $CPU == *'ppc'* ]]; then
    export GCC_CONFIG='linux64-powerpc-gcc'
else
  echo
  echo 'Unable to determine which config file to use.'
  echo
  proc_arch
fi

############################################################
# Select the proper machine flag for the config file
############################################################
if [[ $(containsElement "${KNOWN_MTUNE[@]}" "$MTUNE") == 'y' ]]; then
    export MACHINE=$MTUNE
else
  if [[ $(containsElement "${KNOWN_MARCH[@]}" "$MARCH") == 'y' ]]; then
    export MACHINE=$MARCH
  else
    echo
    echo 'We cannot determine your machine architecture.'
    echo
    getMachine
  fi
fi

############################################################
# Setting the CPU2006 run commands
############################################################
INT_COMMAND="runspec --config $GCC_CONFIG --machine $MACHINE --rate --copies $COPIES --reportable int"
FP_COMMAND="runspec --config $GCC_CONFIG --machine $MACHINE --rate --copies $COPIES --reportable fp"

############################################################
# Display system information and warnings
############################################################
echo
echo '*************************** System Information **************************'
echo
echo "CPU:                $CPU"
echo "Architecture:       $ARCH bit"
echo "OS:                 $OS $VER"
echo "GCC Version:        $GCC_VER"
echo "Logical cores:      $LOGICAL_CORES"
echo "Total RAM:          $RAM_GB GB"
echo "Copies:             $COPIES"
echo "GCC config file:    $GCC_CONFIG"
echo "GCC INT command:    $INT_COMMAND"
echo "GCC FP command:     $FP_COMMAND"
echo
echo '******************************* Warnings ********************************'
if [[ $RAM_GB -ge $REQUIRED_RAM ]]; then
  echo
  echo '                                  None'
  echo
else
  echo
  echo "The number of copies has been changed from $LOGICAL_CORES to $COPIES"
  echo "because there isn't enough RAM to support the number of CPUs on this machine."
  echo 'Please add more RAM to this machine to run the optimal amount of copies.'
  echo
fi
echo '*************************************************************************'
echo
echo 'Please exit now if this information is not correct. Otherwise, resuming'
echo 'in 20 seconds...'
echo
echo '*************************************************************************'
echo
sleep 20


############################################################
################# Install Prerequisites ####################
############################################################
if [[ $NOPREREQ == false ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner 'Checking if prerequisites need to be installed and installing if necessary...'
    $(prerequisites &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo 'Checking if prerequisites need to be installed and installing if necessary...'
    prerequisites
    echo
  fi
fi
echo '*************************************************************************'


############################################################
######################## Run setup #########################
############################################################
if [[ $REBUILD == false ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner 'Checking if CPU2006 needs to be installed and installing if necessary...'
    $(setup &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo 'Checking if CPU2006 needs to be installed and installing if necessary...'
    setup
    echo
  fi
else
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner 'Rebuilding CPU2006...'
    $(rebuildSPECCPU &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo 'Rebuilding CPU2006...'
    rebuildSPECCPU
    echo
  fi
fi
echo '*************************************************************************'


############################################################
########################## Run int #########################
############################################################
if [[ $INT == true ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner 'Running all the int benchmarks...'
    $($INT_COMMAND &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo 'Running all the int benchmarks...'
    $INT_COMMAND
    echo
  fi
  echo '*************************************************************************'
fi


############################################################
########################## Run fp ##########################
############################################################
if [[ $FP == true ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner 'Running all the fp benchmarks...'
    $($FP_COMMAND &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo 'Running all the fp benchmarks...'
    $FP_COMMAND
    echo
  fi
  echo '*************************************************************************'
fi

############################################################
# Display results directory and files within, in addition to
# the commands used.
############################################################
cd "$SPEC/result"
echo
echo 'Results directory:'
echo
pwd
echo
echo '*************************************************************************'
echo
echo 'All files in directory:'
echo
ls
echo
echo '*************************************************************************'
echo
echo 'All commands issued:'
echo
grep runspec: ./*log
echo
echo '*************************************************************************'
echo

############################################################
# Clean up exports
############################################################
unset MACHINE
unset GCC_VER_SHORT
unset KNOWN_MARCH
unset KNOWN_MTUNE
