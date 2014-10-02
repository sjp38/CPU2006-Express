#!/bin/bash

# detect os architecture, os distribution, and os version
# displays bits, either 64 or 32
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
# if ARM, set to 32 bit
if [[ $ARCH == *'arm'* ]]; then
  ARCH='32'
fi

# will display make, type, and model number
# example: Intel Atom C2750
# example: Intel Xeon E5-1650 0
CPU=$(grep 'model name' /proc/cpuinfo | uniq | sed 's/model name\s*:\s//g' | sed 's/\s@\s*.*//g' | sed 's/([^)]*)//g' | sed 's/CPU\s*//g')

# if CPU is empty
if [ -z "$CPU" ]; then
  # this is mainly for ARM systems
  CPU=$(grep 'Processor' /proc/cpuinfo | uniq | sed 's/Processor\s*:\s//g' | sed 's/\s@\s*.*//g' | sed 's/([^)]*)//g' | sed 's/CPU\s*//g')
fi

# get OS and version
# example:
# OS: Ubuntu
# VER: 14.04
if [ -f /etc/lsb-release ]; then
  . /etc/lsb-release
  OS=$DISTRIB_ID
  VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  OS='Debian'  # XXX or Ubuntu??
  VER=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
  OS='Redhat'
  VER=$(cat /etc/redhat-release)
else
  OS=$(uname -s)
  VER=$(uname -r)
fi


# Virtual cores / logical cores
LOGICAL_CORES=`cat /proc/cpuinfo | grep processor | wc -l`
# Amount of RAM needed to run all copies of SPEC
REQUIRED_RAM=`expr $LOGICAL_CORES \* 2`
# Get RAM in KB
RAM_KB=`cat /proc/meminfo | grep "MemTotal:      " | sed "s/MemTotal:      //g" | tr -d ' ' | sed "s/kB//g"`
# Convert RAM to GB
RAM_GB=`expr $RAM_KB / 1024 / 1024`
# if more RAM than required
if [[ $RAM_GB > $REQUIRED_RAM ]]; then
  COPIES=$LOGICAL_CORES
else
  COPIES=`expr $RAM_GB / 2`
fi

MARCH=`gcc -march=native -Q --help=target | grep march`

if [[ $CPU == *'Intel'* ]]; then
  PROCESSOR_OPTION='1'
  GCC_CONFIG='lnx-x86_64-gcc.cfg'
  if [[ $MARCH == *'corei7-avx2'* ]]; then
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx2 --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx2 --rate --reportable fp'
    else
    INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx2 --rate --copies '$COPIES' --reportable int'
    FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx2 --rate --copies '$COPIES' --reportable fp'
    fi
  elif [[ $MARCH == *'corei7-avx'* ]]; then
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx --rate --reportable fp'
    else
    INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx --rate --copies '$COPIES' --reportable int'
    FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7-avx --rate --copies '$COPIES' --reportable fp'
    fi
  elif [[ $MARCH == *'corei7'* ]]; then
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --reportable fp'
    fi
  else
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable fp'
    fi
  fi
elif [[ $CPU == *'ARM'* ]]; then
  PROCESSOR_OPTION='3'
  GCC_CONFIG='lnx-arm-gcc.cfg'
  if [[ $MARCH == *'a15'* ]] || [[ $MARCH == *'armv7-a'* ]]; then
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --copies '$COPIES' --reportable fp'
    fi
  else
    PROCESSOR_OPTION='3'
    GCC_CONFIG='lnx-arm-gcc.cfg'
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine a15_neon_hard --rate --copies '$COPIES' --reportable fp'
    fi
  fi
else
  PROCESSOR_OPTION='0'
  GCC_CONFIG='Example-linux64-amd64-gcc43+'
  if [ $COPIES -le 0 ]; then
    INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable int'
    FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable fp'
  else
    INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --copies '$COPIES' --reportable int'
    FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --copies '$COPIES'--reportable fp'
  fi
fi


echo 
echo "*************************** System Information **************************"
echo "CPU:                $CPU"
echo "Architecture:       $ARCH bit"
echo "OS:                 $OS"
echo "Version:            $VER"
echo "Logical cores:      $LOGICAL_CORES"
echo "Total RAM:          $RAM_GB GB"
echo "Usable SPEC copies: $COPIES"
echo "GCC config file:    $GCC_CONFIG"
echo "GCC INT command:    $INT_COMMAND"
echo "GCC FP command:     $FP_COMMAND"
echo 
echo "******************************* Warnings ********************************"
if [[ $RAM_GB > $REQUIRED_RAM ]]; then
  echo "None"
else
  echo "The number of copies has been changed from $LOGICAL_CORES to $COPIES because there isn't"
  echo "enough RAM to support the number of CPUs on this machine. Please add more"
  echo "RAM to this machine to run the optimal amount of copies."
fi
echo "*************************************************************************"


echo "Is this right? Push [ENTER] to continue."
read

echo "*************************************************************************"



# install prereqs
echo "Checking if prerequisites need to be installed and installing if necessary..."
export http_proxy=https://proxy-us.intel.com:911
export https_proxy=https://proxy-us.intel.com:911

# if apt-get is installed
if hash apt-get; then
  sudo apt-get install build-essential -y
  sudo apt-get install numactl -y
  # double check
  sudo apt-get install gcc -y
  sudo apt-get install g++ -y
  sudo apt-get install gfortran -y
  wait
else
  sudo yum install gcc -y
  sudo yum install g++ -y
  sudo yum install gfortran -y
  sudo yum install numactl -y
  wait
fi

echo "*************************************************************************"

# install cpu2006 if needed
echo "Checking if CPU2006 needs to be installed and installing if necessary..."

if [ ! -d "SPECCPU" ]; then
  # if SPECCPU is not extracted
  echo "Extracting SPECCPU..."
  tar xf SPECCPU.tar
  wait
  cd SPECCPU
  echo "Extracting cpu2006..."
  tar xf cpu2006-1.2.tar.xz
  wait
  if [ '$PROCESSOR_OPTION' != '3' ]; then
    ./install.sh <<< "yes"
    wait
    source shrc
    wait
    echo "Extracting ICC files..."
    tar xf 'cpu2006.1.2.ic14.0.linux64.for.intel.16jan2014.tar.xz'
    wait
    source numa-detection.sh
    wait
    ulimit -s unlimited
    wait 
    rm -rf topo.txt
    specperl nhmtopology.pl
    wait
    DEVICE=`cat topo.txt`
    cp ../config/*.cfg $SPEC/config/
  else
    # for ARM
    if [[ $OS == *'Ubuntu'* ]]; then
      apt-get install ntp
    fi
    cd tools/src
    # allow root configure
    export FORCE_UNSAFE_CONFIGURE=1
    # patch files
    cp ../../../arm/unix.c specinvoke/unix.c
    cp ../../../arm/makedepend.SH perl-5.12.3/makedepend.SH
    # build script
    cp ../../../arm/setup.sh ./
    chmod +x setup.sh
    # fix build errors
    cp ../../../arm/tar_gnu/stdio.in.h tar-1.25/gnu/stdio.in.h
    wait
    cp ../../../arm/specsum_gnulib/stdio.in.h specsum/gnulib/stdio.in.h
    wait
    cp ../../../arm/tar_gnu/stdio.h tar-1.25/gnu/stdio.h
    wait
    cp ../../../arm/tar_mingw/stdio.h tar-1.25/mingw/stdio.h
    wait
    cp ../../../arm/specsum_win32/stdio.h specsum/win32/stdio.h
    wait
    # should display nothing
    ./setup.sh
    wait
  fi
else
  # if SPECCPU is extracted
  if [ '$PROCESSOR_OPTION' != '3' ]; then
    cd SPECCPU
    source shrc
    source numa-detection.sh
    wait
    ulimit -s unlimited
    wait 
    rm -rf topo.txt
    specperl nhmtopology.pl
    wait
    DEVICE=`cat topo.txt`
  else
    cd SPECCPU
    source shrc
  fi
fi

wait

echo "*************************************************************************"

# check if in SPECCPU directory  
if [ ! -d "SPECCPU" ]; then
  # if in
  source shrc
else
  # if not in
  cd SPECCPU
  source shrc
fi

# GCC

eval $INT_COMMAND
wait

# try/catch
GCC_FULL_INT_FILE=`ls -t $SPEC/result/*.html | head -1`; 
GCC_FULL_INT_OUT=`cat $GCC_FULL_INT_FILE | grep -o -P '(?<=base:).*(?=\")'`;
$GCC_FULL_INT_OUT 2>/dev/null

if (( $? == 0 )); then
    echo "RESULTS: base:"$GCC_FULL_INT_OUT
else
    GCC_FULL_INT_LOG=`ls -t $SPEC/result/*.log | head -1`
    echo "There was an error and no results were made. Please check the log file for more info: "$GCC_FULL_INT_LOG
fi 

echo "Running all the benchmarks in fp with reportable..."

echo "*************************************************************************"

eval $FP_COMMAND
wait

# try/catch
GCC_FULL_FP_FILE=`ls -t $SPEC/result/*.html | head -1`; 
GCC_FULL_FP_OUT=`cat $GCC_FULL_FP_FILE | grep -o -P '(?<=base:).*(?=\")'`;
$GCC_FULL_FP_OUT 2>/dev/null

if (( $? == 0 )); then
    echo "RESULTS: base:"$GCC_FULL_FP_OUT
else
    GCC_FULL_FP_LOG=`ls -t $SPEC/result/*.log | head -1`
    echo "There was an error and no results were made. Please check the log file for more info: "$GCC_FULL_FP_LOG
fi

wait
echo "*************************************************************************"
# display results directory and files within, in addition to the commands used.
cd $SPEC/result
echo "Results directory: "
pwd
echo "All files in directory:"
ls
echo "All commands issued:"
grep runspec: *log
echo "*************************************************************************"
echo
