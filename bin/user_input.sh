#!/bin/bash

##############################################################################
#  user_input.sh - This script performs user input required for auto-detection
#  value failures.
#
##############################################################################
#
#  Last Updated:
#     3/31/2015
#
#  Authors/Contributors:
#     Ryan Spoone (ryan.spoone@intel.com)
#
##############################################################################


export KNOWN_MARCH=(
  "core2"
  "nehalem"
  "westmere"
  "sandybridge"
  "ivybridge"
  "haswell"
  "broadwell"
  "bonnell"
  "silvermont"
  "corei7"
  "corei7-avx"
  "core-avx-i"
  "core-avx2"
  "atom"
  "native"
  "armv8-a"
  "armv7-a"
  "power8"
  "power7"
  "powerpc"
  "powerpc64"
  "rs64"
)
export KNOWN_MTUNE=(
  "core2"
  "nehalem"
  "westmere"
  "sandybridge"
  "ivybridge"
  "haswell"
  "broadwell"
  "bonnell"
  "silvermont"
  "corei7"
  "corei7-avx"
  "core-avx-i"
  "core-avx2"
  "atom"
  "armv7-a"
  "cortex-a9"
  "cortex-a15"
  "marvell-pj4"
  "generic"
  "xgene1"
  "thunderx"
  "cortex-a72"
  "cortex-a57"
  "cortex-a53"
  "power8"
  "power7"
  "powerpc"
  "powerpc64"
  "rs64"
)


############################################################
# Function to remove leading and trailing whitespace
############################################################
function trim {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}


############################################################
# Function to check if a variable resides in an array
############################################################
function containsElement() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

############################################################
# Function get the processor and architecture of an unknown
# chipset
############################################################
function proc_arch {
  echo -n "Which brand of processor is it? "
  read processor
  echo -n "64 or 32-bit? "
  read architecture
  if [[ $processor == *"Intel"* || $processor == *"intel"* || $processor == *"INTEL"* ]]; then
    if [[ $architecture == *"64"* ]]; then
      export GCC_CONFIG="linux64-intel64-gcc"
    else
      export GCC_CONFIG="linux32-intel32-gcc"
    fi
  elif [[ $processor == *"Arm"* || $processor == *"arm"* || $processor == *"ARM"* ]]; then
    if [[ $architecture == *"64"* ]]; then
      export GCC_CONFIG="linux64-arm64-gcc"
    else
      export GCC_CONFIG="linux32-arm32-gcc"
    fi
  elif [[ $processor == *"Power"* || $processor == *"power"* || $processor == *"POWER"* || $CPU == *'ppc'* ]]; then
    export GCC_CONFIG="linux64-powerpc-gcc"
  else
    echo
    echo "That's a wrong option. Please try again."
    echo "Currently, only PowerPC, ARM, and Intel are supported."
    echo
    proc_arch
  fi
}

function machineInput {
  echo -n "Please input your option: "
  read mtype
  mtype=$(trim "$mtype")
  if [[ $(containsElement "${KNOWN_MARCH[@]}" "$mtype") == "y" ]]; then
    export MACHINE=$mtype
  else
    if [[ $(containsElement "${KNOWN_MTUNE[@]}" "$mtype") == "y" ]]; then
      export MACHINE=$mtype
    else
      echo
      echo "That's a wrong option. Please try again."
      echo
      getMachine
    fi
  fi
}

############################################################
# Get user to input their machine information
############################################################
function getMachine {
  PS3="Please enter manufacturer choice: "
  options=("Intel" "ARM" "PowerPC")
  select opt in "${options[@]}"
  do
    case $opt in
      "Intel")
        echo
        echo "*************************************************************************"
        echo "************************ Your Intel options are: ************************"
        echo "*************************************************************************"
        echo
        if [[ $GCC_VER_SHORT -ge "49" ]]; then
          echo "**************************** GCC 4.9 or more ****************************"
          echo "'core2' - Intel Core 2 CPU with $ARCH-bit extensions, MMX, SSE, SSE2, SSE3"
          echo "and SSSE3 instruction set support."
          echo "*************************************************************************"
          echo "'nehalem' - Intel Nehalem CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1, SSE4.2 and POPCNT instruction set support."
          echo "*************************************************************************"
          echo "'westmere' - Intel Westmere CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES and PCLMUL instruction set"
          echo "support."
          echo "*************************************************************************"
          echo "'sandybridge' - Intel Sandy Bridge CPU with $ARCH-bit extensions, MMX, SSE, "
          echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES and PCLMUL instruction"
          echo "set support."
          echo "*************************************************************************"
          echo "'ivybridge' - Intel Ivy Bridge CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES, PCLMUL, FSGSBASE, RDRND"
          echo "and F16C instruction set support."
          echo "*************************************************************************"
          echo "'haswell' - Intel Haswell CPU with $ARCH-bit extensions, MOVBE, MMX, SSE, "
          echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, "
          echo "FSGSBASE, RDRND, FMA, BMI, BMI2 and F16C instruction set support."
          echo "*************************************************************************"
          echo "'broadwell' - Intel Broadwell CPU with $ARCH-bit extensions, MOVBE, MMX,"
          echo "SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, "
          echo "FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX and PREFETCHW "
          echo "instruction set support."
          echo "*************************************************************************"
          echo "'bonnell' - Intel Bonnell CPU with $ARCH-bit extensions, MOVBE, MMX, SSE,"
          echo "SSE2, SSE3 and SSSE3 instruction set support."
          echo "*************************************************************************"
          echo "'silvermont' - Intel Silvermont CPU with $ARCH-bit extensions, MOVBE, MMX,"
          echo "SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES, PCLMUL and RDRND"
          echo "instruction set support."
        else
          echo "**************************** GCC 4.8 or less ****************************"
          echo "'core2' - Intel Core 2 CPU with $ARCH-bit extensions, MMX, SSE, SSE2, SSE3"
          echo "and SSSE3 instruction set support."
          echo "*************************************************************************"
          echo "'corei7' - Intel Core i7 CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1 and SSE4.2 instruction set support."
          echo "*************************************************************************"
          echo "'corei7-avx' - Intel Core i7 CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES and PCLMUL instruction set support."
          echo "*************************************************************************"
          echo "'core-avx-i' - Intel Core CPU with $ARCH-bit extensions, MMX, SSE, SSE2,"
          echo "SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES, PCLMUL, FSGSBASE, RDRND and F16C"
          echo "instruction set support."
          echo "*************************************************************************"
          echo "'core-avx2' - Intel Core CPU with $ARCH-bit extensions, MOVBE, MMX, SSE,"
          echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2, AES, PCLMUL, FSGSBASE,"
          echo "RDRND, FMA, BMI, BMI2 and F16C instruction set support."
        fi
        echo "*************************************************************************"
        echo "'atom' - Intel Atom CPU with $ARCH-bit extensions, MOVBE, MMX, SSE, SSE2,"
        echo "SSE3 and SSSE3 instruction set support."
        echo "*************************************************************************"
        echo "'native' - System native Intel CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo
        machineInput
        break
        ;;
      "ARM")
        echo
        echo "*************************************************************************"
        echo "************************* Your ARM options are: *************************"
        echo "*************************************************************************"
        echo
        echo "*************************************************************************"
        echo "'cortex-a9'  - ARM Cortex-A9 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'cortex-a15' - ARM Cortex-A9 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'marvell-pj4' - ARM Marvell-PJ4 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'xgene1' - ARM X-Gene1 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'thunderx' - ARM ThunderX CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'cortex-a72' - ARM Cortex-A72 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'cortex-a57' - ARM Cortex-A57 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'cortex-a53' - ARM Cortex-A53 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'generic' - Generic ARM CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo
        machineInput
        break
        ;;
      "PowerPC")
        echo
        echo "*************************************************************************"
        echo "*********************** Your PowerPC options are: ***********************"
        echo "*************************************************************************"
        echo
        echo "*************************************************************************"
        echo "'power8'  - Power 8 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'power7'  - Power 7 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo "'powerpc' - PowerPC CPU with 32-bit extensions."
        echo "*************************************************************************"
        echo "'powerpc64' - PowerPC CPU with 64-bit extensions."
        echo "*************************************************************************"
        echo "'rs64' - RS 64 CPU with $ARCH-bit extensions."
        echo "*************************************************************************"
        echo
        machineInput
        break
        ;;
      *) echo "That's a wrong option. Please try again.";;
    esac
  done
}
