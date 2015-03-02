#!/bin/bash

##############################################################################
#  speccpu2006.sh - This harness performs SPEC CPU2006 benchmarking using
#  GCC. Unless changed by user flags, a full run will commence resulting in
#  install prerequites, building and installing SPEC CPU2006, then running
#  reportable integer and floating-point runs.
#
#  Required file tree:
#
#  |-- config
#  |   |-- linux64-intel64-gcc.cfg
#  |   |-- linux64-arm64-gcc.cfg
#  |   |-- linux32-intel32-gcc.cfg
#  |   `-- linux32-arm32-gcc.cfg
#  |
#  |-- arm
#  |   |-- config.sub
#  |   `-- config.guess
#  |
#  |-- speccpu2006.sh
#  |
#  |-- spinner.sh
#  |
#  `-- cpu2006-*.tar*
#
#
#  Usage: speccpu2006.sh [OPTIONS]...
#
#  Option          GNU long option         Meaning
#   -h             --help                  Show this message
#   -r             --noreportable          Don't do a reportable run
#   -o             --onecopy               Do a single copy run
#   -i             --noint                 Don't run integer
#   -f             --nofp                  Don't run floating-point
#   -c             --nocheck               Don't check system information before running
#   -p             --noprereq              Don't install prerequisites
#   -s             --silent                Show less detailed information
#
##############################################################################
#
#  Last Updated:
#     2/26/2015
#
#  Authors/Contributors:
#     Ryan Spoone (https://github.com/ryanspoone)
#     Tyler Stachecki (https://github.com/tj90241)
#
##############################################################################

############################################################
# Import sources
############################################################

source "$(pwd)/spinner.sh"

############################################################
# Argument switch variables
############################################################

VERBOSE=true
CHECK=true
NOPREREQ=false
INT=true
FP=true
REPORTABLE='--reportable'
NOCOPY=false

############################################################
# Argument parsing
############################################################

if [[ "$#" -gt 0 ]]; then
  while [ "$1" ]; do
    ARG="$1"
    if [[ "$ARG" == "-s" || "$ARG" == "--silent" ]]; then
      VERBOSE=false
      shift
    elif [[ "$ARG" == "-r" || "$ARG" == "--noreportable" ]]; then
      REPORTABLE=''
      shift
    elif [[ "$ARG" == "-o" || "$ARG" == "--onecopy" ]]; then
      NOCOPY=true
      shift
    elif [[ "$ARG" == "-c" || "$ARG" == "--nocheck" ]]; then
      CHECK=false
      shift
    elif [[ "$ARG" == "-p" || "$ARG" == "--noprereq" ]]; then
      NOPREREQ=true
      shift
    elif [[ "$ARG" == "-i" || "$ARG" == "--noint" ]]; then
      INT=false
      shift
    elif [[ "$ARG" == "-f" || "$ARG" == "--nofp" ]]; then
      FP=false
      shift
    elif [[ "$ARG" == "-h" || "$ARG" == "--help" ]]; then
      echo "Usage: speccpu2006.sh [OPTIONS]..."
      echo
      echo "Option          GNU long option         Meaning"
      echo " -h             --help                  Show this message"
      echo " -r             --noreportable          Don't do a reportable run"
      echo " -o             --onecopy               Do a single copy run"
      echo " -i             --noint                 Don't run integer"
      echo " -f             --nofp                  Don't run floating-point"
      echo " -c             --nocheck               Don't check system information before running"
      echo " -p             --noprereq              Don't install prerequisites"
      echo " -s             --silent                Show less detailed information"
      exit
    else
      echo "speccpu2006: invalid operand ‘$ARG’"
      echo "Try 'speccpu2006 --help' for more information."
      exit
    fi
  done
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
# Example: Intel Atom C2750
# Example: Intel Xeon E5-1650 0
############################################################

CPU=$(grep 'model name' /proc/cpuinfo | uniq | sed 's/model name\s*:\s//g' | sed 's/\s@\s*.*//g' | sed 's/([^)]*)//g' | sed 's/CPU\s*//g')

############################################################
# If CPU is empty
# This is mainly for ARM systems
# Example: AArch64 Processor rev 0
############################################################

if [ -z "$CPU" ]; then
  CPU=$(grep 'Processor' /proc/cpuinfo | uniq | sed 's/Processor\s*:\s//g' | sed 's/\s@\s*.*//g' | sed 's/([^)]*)//g' | sed 's/CPU\s*//g')
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
# GCC Version
############################################################

GCC_VER=$(gcc --version | sed -rn 's/gcc\s\(.*\)\s([0-9]*\.[0-9]*\.[0-9]*)/\1/p')
GCC_VER_NO_DOTS=$(echo "$GCC_VER" | sed -e 's/\.//g')
GCC_VER_SHORT=${GCC_VER_NO_DOTS:0:2}
if [ -z "$GCC_VER" ]; then
  echo "Cannot determine GCC version."
fi

############################################################
# Detect os architecture, os distribution, and os version
# Displays bits, either 64 or 32
############################################################

ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/' | sed 's/[^0-9]*//g')

############################################################
# If it is an ARM system
############################################################

if [[ $ARCH == *'arm'* ]]; then
  ############################################################
  # Get the ARM version number
  ############################################################
  ARM_V=$(echo "$ARCH" | sed 's/armv//g' | head -c1)
  ############################################################
  # If ARMv8 or greater, set to 62 bit
  ############################################################
  if [ "$ARM_V" -ge '8' ]; then
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

REQUIRED_RAM=$(expr "$LOGICAL_CORES" \* 2)

############################################################
# Get RAM in KB
############################################################

RAM_KB=$(grep "MemTotal:      " /proc/meminfo | sed "s/MemTotal:      //g" | tr -d ' ' | sed "s/kB//g")

############################################################
# Convert RAM to GB
# 1000 instead of 1024 due to manufacturer math
############################################################

RAM_GB=$(expr "$RAM_KB" / 1000 / 1000)

############################################################
# Set number of copies the hardware can handle
############################################################

if [[ $NOCOPY == false ]]; then
  if [[ $RAM_GB > $REQUIRED_RAM ]]; then
    COPIES=$LOGICAL_CORES
  else
    COPIES=$(expr "$RAM_GB" / 2)
  fi
else
  COPIES='1'
fi

############################################################
# The name of the target machine architecture
############################################################

MARCH=$(gcc -march=native -Q --help=target 2> /dev/null | grep march)

if [[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]; then
  MARCH='armv8-a'
fi

if [[ $MARCH == *'broadwell'* ]]; then
  CPU='Intel'
fi

############################################################
# Name of the target machine processor
############################################################

MCPU=$(gcc -mcpu=native -Q --help=target 2> /dev/null | grep mcpu)

# for ARM64
if [[ $MCPU == *'CPU'* ]] && ([[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]); then
  MCPU='generic'
fi

############################################################
# Floating-point ABI to use
############################################################

FPABI=$(gcc -march=native -Q --help=target 2> /dev/null | grep mfloat-abi)

############################################################
# Generating code that executes Thumb state
############################################################

MTHUMB=$(gcc -march=native -Q --help=target 2> /dev/null | grep "\-mthumb ")

############################################################
# Config file Intel Processors
############################################################

if [[ $CPU == *'Intel'* ]]; then
  # 32 bit
  if [[ $ARCH == *'32'* ]]; then
    GCC_CONFIG='linux32-intel32-gcc'
  # 64 bit
  else
    GCC_CONFIG='linux64-intel64-gcc'
  fi
############################################################
# Config file ARM processors
############################################################
elif [[ $CPU == *'ARM'* ]] || [[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]; then
  if [[ $ARCH == *'32'* ]]; then
    GCC_CONFIG='linux32-arm32-gcc'
  else
    GCC_CONFIG='linux64-arm64-gcc'
  fi
############################################################
# Unknown CPU
############################################################
else
  echo "Unable to determine which config file to use. This script only currently supports ARM and Intel processors."
  function proc_arch {
    echo -n "Which brand of processor is it? "
    read processor
    echo -n "64 or 32 bit? "
    read architecture
    if [[ $processor == *'Intel'* || $processor == *'intel'* || $processor == *'INTEL'* ]]; then
      if [[ $architecture == *'64'* ]]; then
        GCC_CONFIG='linux64-intel64-gcc'
      else
        GCC_CONFIG='linux32-intel32-gcc'
      fi
    elif [[ $processor == *'Arm'* || $processor == *'arm'* || $processor == *'ARM'* ]]; then
      if [[ $architecture == *'64'* ]]; then
        GCC_CONFIG='linux64-arm64-gcc'
      else
        GCC_CONFIG='linux32-arm32-gcc'
      fi
    else
      echo "That's a wrong option. Please try again."
      echo
      proc_arch
    fi
  }
  proc_arch
fi

############################################################
# Get user to input their machine information
############################################################
function getMachine {
  echo
  echo "*************************************************************************"
  echo "We cannot determine your machine architecture."
  echo "*************************************************************************"
  echo "Your Intel options are:"
  if [[ $GCC_VER_SHORT -ge '49' ]]; then
    echo "**************************** GCC 4.9 or more ****************************"
    echo '"core2" - Intel Core 2 CPU with 64-bit extensions, MMX, SSE, SSE2, SSE3'
    echo 'and SSSE3 instruction set support. '
    echo "*************************************************************************"
    echo '"nehalem" - Intel Nehalem CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1, SSE4.2 and POPCNT instruction set support.'
    echo "*************************************************************************"
    echo '"westmere" - Intel Westmere CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES and PCLMUL instruction set'
    echo 'support. '
    echo "*************************************************************************"
    echo '"sandybridge" - Intel Sandy Bridge CPU with 64-bit extensions, MMX, SSE, '
    echo 'SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES and PCLMUL instruction'
    echo 'set support. '
    echo "*************************************************************************"
    echo '"ivybridge" - Intel Ivy Bridge CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES, PCLMUL, FSGSBASE, RDRND'
    echo 'and F16C instruction set support. '
    echo "*************************************************************************"
    echo '"haswell" - Intel Haswell CPU with 64-bit extensions, MOVBE, MMX, SSE, '
    echo 'SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, '
    echo 'FSGSBASE, RDRND, FMA, BMI, BMI2 and F16C instruction set support. '
    echo "*************************************************************************"
    echo '"broadwell" - Intel Broadwell CPU with 64-bit extensions, MOVBE, MMX,'
    echo 'SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, '
    echo 'FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX and PREFETCHW '
    echo 'instruction set support. '
    echo "*************************************************************************"
    echo '"bonnell" - Intel Bonnell CPU with 64-bit extensions, MOVBE, MMX, SSE,'
    echo 'SSE2, SSE3 and SSSE3 instruction set support. '
    echo "*************************************************************************"
    echo '"silvermont" - Intel Silvermont CPU with 64-bit extensions, MOVBE, MMX,'
    echo 'SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES, PCLMUL and RDRND'
    echo 'instruction set support. '
  else
    echo "**************************** GCC 4.8 or less ****************************"
    echo '"core2" - Intel Core 2 CPU with 64-bit extensions, MMX, SSE, SSE2, SSE3 '
    echo 'and SSSE3 instruction set support. '
    echo "*************************************************************************"
    echo '"corei7" - Intel Core i7 CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1 and SSE4.2 instruction set support. '
    echo "*************************************************************************"
    echo '"corei7-avx" - Intel Core i7 CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES and PCLMUL instruction set support.'
    echo "*************************************************************************"
    echo '"core-avx-i" - Intel Core CPU with 64-bit extensions, MMX, SSE, SSE2,'
    echo 'SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES, PCLMUL, FSGSBASE, RDRND and F16C'
    echo 'instruction set support. '
    echo "*************************************************************************"
    echo '"core-avx2" - Intel Core CPU with 64-bit extensions, MOVBE, MMX, SSE,'
    echo 'SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2, AES, PCLMUL, FSGSBASE,'
    echo 'RDRND, FMA, BMI, BMI2 and F16C instruction set support. '
    echo "*************************************************************************"
    echo '"atom" - Intel Atom CPU with 64-bit extensions, MOVBE, MMX, SSE, SSE2,'
    echo 'SSE3 and SSSE3 instruction set support. '
  fi
  echo "*************************************************************************"
  echo "Your ARM options are:"
  echo "*************************************************************************"
  echo 'a15_neon_hard - ARM CPU with 32-bit extensions, NEON, hard floating-point'
  echo 'ABI'
  echo "*************************************************************************"
  echo 'a15_thumb_neon - ARM CPU with 32-bit extensions, NEON, Thumb state'
  echo "*************************************************************************"
  echo 'a15_neon_soft - ARM CPU with 32-bit extensions, NEON, soft floating-point'
  echo 'ABI'
  echo "*************************************************************************"
  echo 'a9_neon_hard - ARM CPU with 32-bit extensions, NEON, hard floating-point'
  echo 'ABI'
  echo "*************************************************************************"
  echo 'a9_thumb_neon  - ARM CPU with 32-bit extensions, NEON, Thumb state'
  echo "*************************************************************************"
  echo 'a9_neon_soft - ARM CPU with 32-bit extensions, NEON, soft floating-point'
  echo 'ABI'
  echo "*************************************************************************"
  echo 'v8_a53 - ARM CPU with 64-bit extensions, Cortex-A53'
  echo "*************************************************************************"
  echo 'v8_a57 - ARM CPU with 64-bit extensions, Cortex-A57'
  echo "*************************************************************************"
  echo 'v8 - ARM CPU with 64-bit extensions'
  echo "*************************************************************************"
  echo -n "Please input your option: "
  read mtype
  if [[ $mtype == *'core-avx2'* ]]; then
    MACHINE='core-avx2'
  elif [[ $mtype == *'core-avx-i'* ]]; then
    MACHINE='core-avx-i'
  elif [[ $mtype == *'corei7-avx'* ]]; then
    MACHINE='corei7-avx'
  elif [[ $mtype == *'corei7'* ]]; then
    MACHINE='corei7'
  elif [[ $mtype == *'atom'* ]]; then
    MACHINE='atom'
  elif [[ $mtype == *'core2'* ]]; then
    MACHINE='core2'
  elif [[ $mtype == *'broadwell'* ]]; then
    MACHINE='broadwell'
  elif [[ $mtype == *'nehalem'* ]]; then
    MACHINE='nehalem'
  elif [[ $mtype == *'westmere'* ]]; then
    MACHINE='westmere'
  elif [[ $mtype == *'sandybridge'* ]]; then
    MACHINE='sandybridge'
  elif [[ $mtype == *'ivybridge'* ]]; then
    MACHINE='ivybridge'
  elif [[ $mtype == *'haswell'* ]]; then
    MACHINE='haswell'
  elif [[ $mtype == *'bonnell'* ]]; then
    MACHINE='bonnell'
  elif [[ $mtype == *'silvermont'* ]]; then
    MACHINE='silvermont'
  elif [[ $mtype == *'a15_neon_hard'* ]]; then
    MACHINE='a15_neon_hard'
  elif [[ $mtype == *'a15_thumb_neon'* ]]; then
    MACHINE='a15_thumb_neon'
  elif [[ $mtype == *'a15_neon_soft'* ]]; then
    MACHINE='a15_neon_soft'
  elif [[ $mtype == *'a9_neon_hard'* ]]; then
    MACHINE='a9_neon_hard'
  elif [[ $mtype == *'a9_thumb_neon'* ]]; then
    MACHINE='a9_thumb_neon'
  elif [[ $mtype == *'a9_neon_soft'* ]]; then
    MACHINE='a9_neon_soft'
  elif [[ $mtype == *'v8_a53'* ]]; then
    MACHINE='v8_a53'
  elif [[ $mtype == *'v8_a57'* ]]; then
    MACHINE='v8_a57'
  elif [[ $mtype == *'v8'* ]]; then
    MACHINE='v8'
  else
    echo "That's a wrong option. Please try again."
    echo
    getMachine
  fi
}

############################################################
# Config file machine architecture set for Intel
############################################################

if [[ $MARCH == *'core-avx2'* ]]; then
  MACHINE='core-avx2'
elif [[ $MARCH == *'core-avx-i'* ]]; then
  MACHINE='core-avx-i'
elif [[ $MARCH == *'corei7-avx'* ]]; then
  MACHINE='corei7-avx'
elif [[ $MARCH == *'corei7'* ]]; then
  MACHINE='corei7'
elif [[ $MARCH == *'atom'* ]]; then
  MACHINE='atom'
elif [[ $MARCH == *'core2'* ]]; then
  MACHINE='core2'
elif [[ $MARCH == *'broadwell'* ]]; then
  MACHINE='broadwell'
elif [[ $MARCH == *'nehalem'* ]]; then
  MACHINE='nehalem'
elif [[ $MARCH == *'westmere'* ]]; then
  MACHINE='westmere'
elif [[ $MARCH == *'sandybridge'* ]]; then
  MACHINE='sandybridge'
elif [[ $MARCH == *'ivybridge'* ]]; then
  MACHINE='ivybridge'
elif [[ $MARCH == *'haswell'* ]]; then
  MACHINE='haswell'
elif [[ $MARCH == *'bonnell'* ]]; then
  MACHINE='bonnell'
elif [[ $MARCH == *'silvermont'* ]]; then
  MACHINE='silvermont'
elif [[ $MARCH == *'armv7-a'* ]]; then
  ############################################################
  # Config file machine architecture set for ARM 32
  ############################################################
  if [[ $MCPU == *'a15'* ]]; then
    if [[ $FPABI == *'hard'* ]]; then
      MACHINE='a15_neon_hard'
    else
      if [[ $MTHUMB == *'enabled'* ]]; then
        MACHINE='a15_thumb_neon'
      else
        MACHINE='a15_neon_soft'
      fi
    fi
  elif [[ $MCPU == *'a9'* ]]; then
    if [[ $FPABI == *'hard'* ]]; then
      MACHINE='a9_neon_hard'
    else
      if [[ $MTHUMB == *'enabled'* ]]; then
        MACHINE='a9_thumb_neon'
      else
        MACHINE='a9_neon_soft'
      fi
    fi
  elif [[ $MCPU == *'marvell'* ]]; then
    MACHINE='marvell'
  else
    getMachine
  fi
elif [[ $MARCH == *'armv8-a'* ]]; then
  ############################################################
  # Config file machine architecture set for ARM 64
  ############################################################
  if [[ $MCPU == *'a53'* ]]; then
    MACHINE='v8_a53'
  elif [[ $MCPU == *'a57'* ]]; then
    MACHINE='v8_a57'
  else
    MACHINE='v8'
  fi
else
  ############################################################
  # Unknown machine architecture
  ############################################################
  getMachine
fi

############################################################
# Setting the CPU2006 run commands
############################################################

INT_COMMAND="runspec --config $GCC_CONFIG --machine $MACHINE --rate --copies $COPIES $REPORTABLE int"
FP_COMMAND="runspec --config $GCC_CONFIG --machine $MACHINE --rate --copies $COPIES $REPORTABLE fp"

############################################################
# Display system information and warnings
############################################################

echo
echo "*************************** System Information **************************"
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
echo "******************************* Warnings ********************************"
if [[ $RAM_GB -ge $REQUIRED_RAM ]]; then
  echo
  echo "                                  None"
  echo
else
  echo
  echo "The number of copies has been changed from $LOGICAL_CORES to $COPIES"
  echo "because there isn'tenough RAM to support the number of CPUs on this machine."
  echo "Please add more RAM to this machine to run the optimal amount of copies."
  echo
fi
echo "*************************************************************************"

############################################################
# Require user input before continuing with the rest of the
# automation
############################################################

if [[ $CHECK == true ]]; then
  echo
  echo "            Is this right? Push [ENTER] to continue."
  read
  echo "*************************************************************************"
  echo
fi


############################################################
# Install prerequisites if needed
############################################################

function prerequisites {

  ############################################################
  # If apt-get is installed
  ############################################################
  if hash apt-get &>/dev/null; then
    sudo -E apt-get update -y
    sudo -E apt-get upgrade -y
    sudo -E apt-get install build-essential -y
    sudo -E apt-get install unzip -y
    sudo -E apt-get install numactl -y
    # double check
    sudo -E apt-get build-dep gcc -y
    sudo -E apt-get install gcc -y
    sudo -E apt-get install g++ -y
    sudo -E apt-get install gfortran -y
    sudo -E apt-get install automake -y
    ############################################################
    # ARM
    ############################################################

    if [[ $CPU == *'ARM'* ]]; then
      echo "Installing..."
      sudo -E apt-get install gcc-4.8-arm-linux-gnueabi -y
    fi

    ############################################################
    # ARMv8
    ############################################################

    if [[ $MARCH == *'armv8-a'* ]]; then
      ############################################################
      # Update to 4.9
      ############################################################
      sudo -E add-apt-repository ppa:ubuntu-toolchain-r/test -y
      sudo -E apt-get update -y
      sudo -E apt-get install gcc-4.9 -y
      sudo -E apt-get install g++-4.9 -y
      sudo -E apt-get install gfortran-4.9 -y
      ############################################################
      # Remove the previous gcc version from the default
      # applications list (if already exists)
      ############################################################
      sudo update-alternatives --remove-all gcc
      sudo update-alternatives --remove-all g++
      sudo update-alternatives --remove-all gfortran
      ############################################################
      # Make GCC 4.9 the default compiler on the system
      ############################################################
      sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 20
      sudo update-alternatives --config gcc
      sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 20
      sudo update-alternatives --config g++
      sudo update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-4.9 20
      sudo update-alternatives --config gfortran
    fi
    return 0

  ############################################################
  # If yum is installed
  ############################################################

  elif hash yum &>/dev/null; then
    sudo -E yum check-update -y
    sudo -E yum update -y
    sudo -E yum groupinstall "Development Tools" "Development Libraries" -y
    sudo -E yum install unzip -y
    sudo -E yum-builddep gcc -y
    sudo -E yum install gcc -y
    sudo -E yum install g++ -y
    sudo -E yum install gfortran -y
    sudo -E yum install numactl -y
    sudo -E yum install automake -y

    ############################################################
    # ARM
    ############################################################

    if [[ $CPU == *'ARM'* ]] || [[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]; then
      sudo -E yum install gcc-4.8-arm-linux-gnueabi -y

      ############################################################
      # ARMv8
      ############################################################

      if [[ $MARCH == *'armv8-a'* ]]; then
        sudo -E yum-builddep gcc-4.8-arm-linux-gnueabihf-base -y
        sudo -E yum-builddep binutils-aarch64-linux-gnu -y
      fi
    fi
    return 0

  ############################################################
  # If not supported package manager or no package manager
  ############################################################

  else
    echo
    echo "*************************************************************************"
    echo "We couldn't find the appropriate package manager for your system. Please"
    echo "try manually installing the following and rerun this script:"
    echo
    echo "gcc"
    echo "g++"
    echo "gfortran"
    echo "numactl"
    echo "automake"
    echo "*************************************************************************"
    echo
    sleep 10
    return 1
  fi
}

############################################################
# Run prerequisites installation
############################################################

if [[ $NOPREREQ == false ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner "Checking if prerequisites need to be installed and installing if necessary..."
    $(prerequisites &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo "Checking if prerequisites need to be installed and installing if necessary..."
    prerequisites
    echo
  fi
fi

echo "*************************************************************************"


############################################################
# Setup function to build and install SPEC CPU2006 if needed
############################################################

function setup {
  ############################################################
  # If SPECCPU is not extracted
  ############################################################
  if [ ! -d "SPECCPU" ]; then
    echo "Extracting SPECCPU..."
    ############################################################
    # Extract the core SPEC CPU2006 file
    ############################################################
    if [ -f "cpu2006-"*"tar"* ]; then
      echo "Extracting cpu2006..."
      tar xfv cpu2006-*tar* SPECCPU/
      cd SPECCPU
    else
      echo -n "Could not find the file with SPEC CPU2006. Where is it? "
      read SPECCPU_TAR
      tar xfv "$SPECCPU_TAR" SPECCPU/
      cd SPECCPU
    fi
    ############################################################
    # For ARM
    ############################################################
    if [[ $CPU == *'ARM'* ]] || [[ $CPU == *'AArch'* ]] || [[ $CPU == *'APM X-Gene Mustang'* ]]; then
      echo "Building for ARM..."
      export FORCE_UNSAFE_CONFIGURE=1
      cd tools/src
      ############################################################
      # Patching for ARM build
      ############################################################
      echo "Patching..."
      sed -i 's/tmpfile, O_RDWR|O_CREAT|O_TRUNC/tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666/g' specinvoke/unix.c
      sed -i 's/$startsh/$startsh -x/g' perl-5.12.3/makedepend.SH
      sed -i 's/$startsh -x/&\nset -x/' perl-5.12.3/makedepend.SH
      touch setup.sh
      ############################################################
      # Write multi-line setup file
      ############################################################
      cat > setup.sh <<EOL
#!/bin/bash
PERLFLAGS=-Uplibpth=
for i in \`gcc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' '\\n' | grep -v /gcc\`; do
PERLFLAGS="\$PERLFLAGS -Aplibpth=\$i"
done
export PERLFLAGS
echo $PERLFLAGS
export CFLAGS="-O2 -march=native"
echo $CFLAGS
./buildtools
EOL
      ############################################################
      # Change architecture tuning
      ############################################################
      sed -i 's/march=native/march='$MARCH'/g' setup.sh

      chmod +x setup.sh

      ############################################################
      # Update the config.guess files
      ############################################################
      chmod 775 ../../../arm/config.guess
      while IFS= read -d $'\0' -r guess_file ; do
        printf 'Updating config.guess file: %s\n' "$guess_file"
        cp ../../../arm/config.guess "$guess_file"
      done < <(find . -iname 'config.guess' -print0)

      ############################################################
      # Update the config.sub files
      ############################################################
      chmod 775 ../../../arm/config.sub
      while IFS= read -d $'\0' -r sub_file ; do
        printf 'Updating config.sub file: %s\n' "$sub_file"
        cp ../../../arm/config.sub "$sub_file"
      done < <(find . -iname 'config.sub' -print0)

      ############################################################
      # Fix ARM build errors
      ############################################################
      find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} + | awk '{print $1;}' | sed 's/:_GL_WARN_ON_USE//g' | while read -r gl_warn_file; do
        printf 'Fixing _GL_WARN_ON_USE errors: %s\n' "$gl_warn_file"
        sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' "$gl_warn_file"
      done

      ############################################################
      # Build SPEC CPU2006
      ############################################################
      ./setup.sh
      cd ../..
      source shrc
      cp ../config/*.cfg "$SPEC"/config/
    ############################################################
    # If Intel
    ############################################################
    else
      ./install.sh <<< "yes"
      source shrc
      cp ../config/*.cfg "$SPEC"/config/
    fi
  ############################################################
  # If SPECCPU is extracted
  ############################################################
  else
    SPECCPU_PATH=$(find . -iname "shrc" | head -1)
    if [ -z "$SPECCPU_PATH" ]; then
      echo "Cannot find SPEC CPU2006 directory. Exiting now..."
      exit
    fi
    SPECCPU_DIR=$(dirname "$SPECCPU_PATH")
    cd "$SPECCPU_DIR"
    source shrc
  fi
  return 0
}

############################################################
# Run setup
############################################################

if [[ $VERBOSE == false ]]; then
  echo
  start_spinner "Checking if CPU2006 needs to be installed and installing if necessary..."
  $(setup &) > /dev/null 2>&1
  stop_spinner $?
  echo
else
  echo
  echo "Checking if CPU2006 needs to be installed and installing if necessary..."
  setup
  echo
fi
echo "*************************************************************************"


############################################################
# Run int
############################################################

if [[ $INT == true ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner "Running all the int benchmarks..."
    $($INT_COMMAND &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo "Running all the int benchmarks..."
    $INT_COMMAND
    echo
  fi
  echo "*************************************************************************"
fi

############################################################
# Run fp
############################################################

if [[ $FP == true ]]; then
  if [[ $VERBOSE == false ]]; then
    echo
    start_spinner "Running all the fp benchmarks..."
    $($FP_COMMAND &) > /dev/null 2>&1
    stop_spinner $?
    echo
  else
    echo
    echo "Running all the fp benchmarks..."
    $FP_COMMAND
    echo
  fi
  echo "*************************************************************************"
fi

############################################################
# Display results directory and files within, in addition to
# the commands used.
############################################################

cd "$SPEC"/result
echo
echo "Results directory: "
echo
pwd
echo
echo "*************************************************************************"
echo
echo "All files in directory:"
echo
ls
echo
echo "*************************************************************************"
echo
echo "All commands issued:"
echo
grep runspec: ./*log
echo
echo "*************************************************************************"
echo
