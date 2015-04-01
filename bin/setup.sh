#!/bin/bash

##############################################################################
#  setup.sh - This script handles the installation of needed prerequisites and
#  SPEC CPU2006
#
##############################################################################
#
#  Last Updated:
#     4/1/2015
#
#  Authors/Contributors:
#     Ryan Spoone (github.com/ryanspoone)
#
##############################################################################


############################################################
# Install prerequisites if needed
############################################################
function prerequisites {
  # If apt-get is installed
  if hash apt-get &>/dev/null; then
    sudo -E apt-get update -y
    sudo -E apt-get upgrade -y
    sudo -E apt-get install build-essential unzip numactl gawk automake -y
    sudo -E apt-get build-dep gcc -y
    sudo -E apt-get install gcc g++ gfortran -y
  # If yum is installed
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
  # If not supported package manager or no package manager
  else
    echo
    echo "*************************************************************************"
    echo "We couldn't find the appropriate package manager for your system. Please"
    echo "try manually installing the following and rerun this program:"
    echo
    echo "gcc"
    echo "g++"
    echo "gfortran"
    echo "numactl"
    echo "automake"
    echo "*************************************************************************"
    echo
    exit
  fi
}


############################################################
# Rebuilding and installing SPEC CPU2006
############################################################
function rebuildSPECCPU {
  rm -rf src
  setup
}


############################################################
# Manually building and installing SPEC CPU2006
############################################################
function buildSPECCPU {
  export FORCE_UNSAFE_CONFIGURE=1
  cd tools/src

  # get the latest versions of config.guess and config.sub
  wget -O config.guess 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
  chmod 775 config.guess
  wget -O config.sub 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
  chmod 775 config.sub

  # Update the config.guess files
  while IFS= read -d $'\0' -r guess_file ; do
    printf 'Updating config.guess file: %s\n' "$guess_file"
    cp config.guess "$guess_file"
  done < <(find . -iname 'config.guess' -print0)

  # Update the config.sub files
  while IFS= read -d $'\0' -r sub_file ; do
    printf 'Updating config.sub file: %s\n' "$sub_file"
    cp config.sub "$sub_file"
  done < <(find . -iname 'config.sub' -print0)

  # Remove build errors
  find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} + | awk '{print $1;}' | sed 's/:_GL_WARN_ON_USE//g' | while read -r gl_warn_file; do
    printf 'Fixing _GL_WARN_ON_USE errors: %s\n' "$gl_warn_file"
    sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' "$gl_warn_file"
  done

  echo "Patching..."
  sed -i 's/tmpfile, O_RDWR|O_CREAT|O_TRUNC/tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666/g' specinvoke/unix.c
  sed -i "s/\$startsh/\$startsh -x/g" perl-5.12.3/makedepend.SH
  sed -i "s/\$startsh -x/&\nset -x/" perl-5.12.3/makedepend.SH

  PERLFLAGS=-Uplibpth=
  for i in $(gcc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' "\\n" | grep -v /gcc); do
    PERLFLAGS="$PERLFLAGS -Aplibpth=$i"
  done
  export PERLFLAGS
  if [[ $CPU == *'Power'* || $CPU == *'power'* || $CPU == *'POWER'* || $CPU == *'ppc'* ]]; then
    export CFLAGS="-O2 -mcpu=$MARCH"
  else
    export CFLAGS="-O2 -march=$MARCH"
  fi
  ./buildtools
  cd ../..
  
  # export clean up
  unset CFLAGS
  unset PERLFLAGS
  unset FORCE_UNSAFE_CONFIGURE
}


############################################################
# Setup function to build and install SPEC CPU2006 if needed
############################################################
function setup {
  # If SPECCPU is not extracted
  if [ ! -d "src" ]; then
    echo "Extracting SPECCPU..."
    mkdir src
    for file in ./cpu2006-*tar*; do
      if [ -e "$file" ]; then
        tar xfv "$file" -C src
      else
        echo
        echo -n "Could not find your CPU2006 tar archive. Where is it? "
        read SPECCPU_TAR
        echo
        tar xfv "$SPECCPU_TAR" -C src
      fi
    done
    cd src
    # install
    if [[ $CPU == *'Intel'* ]]; then
      ./install.sh <<< "yes"
    else
      buildSPECCPU
    fi
    source shrc
    cp ../config/*.cfg "$SPEC"/config/
  # If SPEC CPU2006 is extracted
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
}
