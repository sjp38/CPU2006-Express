#!/bin/bash

# detect os architecture, os distribution, and os version
# displays bits, either 64 or 32
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

# if it is an ARM system
if [[ $ARCH == *'arm'* ]]; then
  # get the arm version number
  ARM_V=$(echo $ARCH | sed 's/armv//g' | head -c1)
  # if ARMv8 or greater, set to 62 bit
  if [ $ARM_V -ge '8' ]; then
    ARCH='64'
  else
    ARCH='32'
  fi
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
  OS='Debian'
  VER=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
  OS='Redhat'
  VER=$(cat /etc/redhat-release)
else
  OS=$(uname -s)
  VER=$(uname -r)
fi


# Virtual cores / logical cores
LOGICAL_CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
# Amount of RAM needed to run all copies of SPEC
REQUIRED_RAM=$(expr $LOGICAL_CORES \* 2)
# Get RAM in KB
RAM_KB=$(cat /proc/meminfo | grep "MemTotal:      " | sed "s/MemTotal:      //g" | tr -d ' ' | sed "s/kB//g")
# Convert RAM to GB
RAM_GB=$(expr $RAM_KB / 1000 / 1000)
# if more RAM than required
if [[ $RAM_GB > $REQUIRED_RAM ]]; then
  COPIES=$LOGICAL_CORES
else
  COPIES=$(expr $RAM_GB / 2)
fi

MARCH=$(gcc -march=native -Q --help=target | grep march)
if [[ $CPU == *'AArch'* ]]; then
  MARCH='armv8-a'
fi

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
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine corei7 --rate --copies '$COPIES' --reportable fp'
    fi
  else
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine native --rate --copies '$COPIES' --reportable fp'
    fi
  fi
elif [[ $CPU == *'ARM'* ]] || [[ $CPU == *'AArch'* ]]; then
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
  elif [[ $MARCH == *'armv8-a'* ]]; then
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine v8 --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine v8 --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine v8 --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine v8 --rate --copies '$COPIES' --reportable fp'
    fi
  else
    if [ $COPIES -le 0 ]; then
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine generic --rate --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine generic --rate --reportable fp'
    else
      INT_COMMAND='runspec --config '$GCC_CONFIG' --machine generic --rate --copies '$COPIES' --reportable int'
      FP_COMMAND='runspec --config '$GCC_CONFIG' --machine generic --rate --copies '$COPIES' --reportable fp'
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
if [[ $RAM_GB -ge $REQUIRED_RAM ]]; then
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

echo "*************************************************************************"

# install cpu2006 if needed
echo "Checking if CPU2006 needs to be installed and installing if necessary..."

if [ ! -d "SPECCPU" ]; then
  # install prereqs
  echo "Checking if prerequisites need to be installed and installing if necessary..."
  # add proxies here
  # example:
  # export http_proxy=http://proxy-us.ryanspoone.com:88

  # if apt-get is installed
  if hash apt-get; then
    sudo -E apt-get update -y
    sudo -E apt-get upgrade -y
    sudo -E apt-get install build-essential -y
    sudo -E apt-get install numactl -y
    # double check
    sudo -E apt-get install gcc -y
    sudo -E apt-get install g++ -y
    sudo -E apt-get install gfortran -y
    sudo -E apt-get install automake -y
    # arm
    if [ '$PROCESSOR_OPTION' == '3' ]; then
      sudo -E apt-get install gcc-4.8-arm-linux-gnueabi
      if [[ $MARCH == *'armv8-a'* ]]; then
        sudo -E apt-get build-dep gcc-4.8-arm-linux-gnueabihf-base
        sudo -E apt-get build-dep binutils-aarch64-linux-gnu
      fi
    fi
    wait
  else
    sudo -E yum check-update -y
    sudo -E yum update -y
    sudo -E yum install gcc -y
    sudo -E yum install g++ -y
    sudo -E yum install gfortran -y
    sudo -E yum install numactl -y
    sudo -E yum install automake -y
    if [ '$PROCESSOR_OPTION' == '3' ]; then
      sudo -E yum install gcc-4.8-arm-linux-gnueabi
      if [[ $MARCH == *'armv8-a'* ]]; then
        sudo -E yum-builddep gcc-4.8-arm-linux-gnueabihf-base
        sudo -E yum-builddep binutils-aarch64-linux-gnu
      fi
    fi
  fi
  # if SPECCPU is not extracted
  echo "Extracting SPECCPU..."
  tar xf SPECCPU.tar
  wait
  cd SPECCPU
  echo "Extracting cpu2006..."
  tar xf cpu2006-*.tar.xz
  wait
  if [ "$PROCESSOR_OPTION" == "3" ]; then
    # for ARM
    echo "Building for ARM..."
    export FORCE_UNSAFE_CONFIGURE=1
    cd tools/src
    echo "Patching..."
    sed -i 's/tmpfile, O_RDWR|O_CREAT|O_TRUNC/tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666/g' specinvoke/unix.c
    sed -i 's/$startsh/$startsh -x/g' perl-5.12.3/makedepend.SH
    sed -i 's/$startsh -x/&\nset -x/' perl-5.12.3/makedepend.SH
    touch setup.sh
    # write multi-line setup file
    cat >setup.sh <<EOL
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

    # change architecture tuning
    sed -i 's/march=native/march='$MARCH'/g' setup.sh

    chmod +x setup.sh

    # update the config.guess files
    chmod 775 ../../../arm/config.guess
    while IFS= read -d $'\0' -r guess_file ; do
      printf 'Updating config.guess file: %s\n' "$guess_file"
      cp ../../../arm/config.guess $guess_file
    done < <(find . -iname 'config.guess' -print0)
    wait

    # fix errors
    find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} + | awk '{print $1;}' | sed 's/:_GL_WARN_ON_USE//g' | while read -r gl_warn_file; do 
      printf 'Fixing _GL_WARN_ON_USE errors: %s\n' "$gl_warn_file"
      sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' $gl_warn_file
    done

    # build
    ./setup.sh
    wait
    cd ../..
    source shrc
    cp ../config/*.cfg $SPEC/config/
  else
    ./install.sh <<< "yes"
    wait
    source shrc
    wait
    cp ../config/*.cfg $SPEC/config/
  fi
else
  # if SPECCPU is extracted
  cd SPECCPU
  source shrc
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
GCC_FULL_INT_FILE=$(ls -t $SPEC/result/*.html | head -1)
GCC_FULL_INT_OUT=$(cat $GCC_FULL_INT_FILE | grep -o -P '(?<=base:).*(?=\")')
$GCC_FULL_INT_OUT 2>/dev/null

if (( $? == 0 )); then
    echo "RESULTS: base:"$GCC_FULL_INT_OUT
else
    GCC_FULL_INT_LOG=$(ls -t $SPEC/result/*.log | head -1)
    echo "There was an error and no results were made. Please check the log file for more info: "$GCC_FULL_INT_LOG
fi 

echo "Running all the benchmarks in fp with reportable..."

echo "*************************************************************************"

eval $FP_COMMAND
wait

# try/catch
GCC_FULL_FP_FILE=$(ls -t $SPEC/result/*.html | head -1)
GCC_FULL_FP_OUT=$(cat $GCC_FULL_FP_FILE | grep -o -P '(?<=base:).*(?=\")')
$GCC_FULL_FP_OUT 2>/dev/null

if (( $? == 0 )); then
    echo "RESULTS: base:"$GCC_FULL_FP_OUT
else
    GCC_FULL_FP_LOG=$(ls -t $SPEC/result/*.log | head -1)
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
