Benchmarking
============

This harness performs SPEC CPU2006 benchmarking using GCC on Intel and ARM systems. Unless changed by user flags, a full run will commence resulting in install prerequites, building and installing SPEC CPU2006, then running reportable integer and floating-point runs.


Contents:
---------

+ [Download](#download)
+ [Usage](#usage)
+ [Required File Tree](#required-file-tree)
+ [Troubleshooting](#troubleshooting)
+ [Optimizing GCC Process](#process-for-optimizing-gcc)
+ [Runspec Errors](#runspec-errors)
+ [Building SPEC CPU2006 on ARM](arm/README.md)




Download:
=========

To download these files, first install git:

```bash
yum install git
```


Or if you are using a Debian-based distribution:

```bash
apt-get install git git-core
```


Clone this repository:

```bash
git clone https://github.com/ryanspoone/CPU2006-Express.git
```

Change directories and run this script:

```bash
cd CPU2006-Express/
chmod +x speccpu2006.sh
./speccpu2006.sh
```


Usage:
======

Change to directory where files are, then start benchmarking by issuing the following
command:


For a full run:

```bash
./speccpu2006.sh
```

Customized run:

```bash
./speccpu2006.sh [OPTIONS]...
```

Where the options are:

```
 Option          GNU long option         Meaning
  -h             --help                  Show this message
  -r             --noreportable          Don't do a reportable run
  -o             --onecopy               Do a single copy run
  -i             --noint                 Don't run integer
  -f             --nofp                  Don't run floating-point
  -c             --nocheck               Don't check system information before running
  -p             --noprereq              Don't install prerequisites
  -s             --silent                Show less detailed information
```


Required file tree:
==================
```
 |-- config
 |   |-- linux64-intel64-gcc.cfg
 |   |-- linux64-arm64-gcc.cfg
 |   |-- linux32-intel32-gcc.cfg
 |   `-- linux32-arm32-gcc.cfg
 |
 |-- arm
 |   |-- config.sub
 |   `-- config.guess
 |
 |-- speccpu2006.sh
 |
 |-- spinner.sh
 |
 `-- cpu2006-*.tar*
```


TODO:
-----

1. Add ICC support
2. Add AMD and PowerPC support
3. Add other package manager support
4. Add flag file for reportable


Troubleshooting:
================

If you are getting a `Permission denied` response, make sure you're running as root.
If you are still getting the message, try using the following command:

```bash
chmod +x speccpu2006.sh
```


Process for optimizing GCC:
===========================

1. Get GCC capable flags: `gcc -march=native -Q --help=target` or `echo "int main {return 0;}" | gcc [OPTIONS] -x c -v -Q -`
2. For Intel processors, go to [ARK](http://ark.intel.com/) to get CPU information and put hw_* values in the configuration file. Otherwise, search for hardware information on the Web.
3. Check [SPEC CPU2006](http://www.spec.org/cgi-bin/osgresults?conf=rint2006) for submitted results.
4. Trial and error.


Runspec Errors:
===============

`/usr/bin/ld: cannot find -lm` and/or `/usr/bin/ld: cannot find -lc`

+ RHEL: remove `-static` from the compiler flags in the config file.



-------------

`copy 0 non-zero return code` or other build errors.

Change the portability options for that benchmark. Here are some options:

+ -DSPEC_CPU_LP64
    + This macro specifies that the target system uses the LP64 data model; specifically, that integers are 32 bits, while longs and pointers are 64 bits.
+ -DSPEC_CPU_Linux
    + This macro indicates that the benchmark is being compiled on a system running Linux.
+ -DSPEC_CPU_Linux_X64
    + This macro indicates that the benchmark is being compiled on an AMD64-compatible system running the Linux operating system.
+ -DSPEC_CPU_Linux_IA32
    + This macro indicates that the benchmark is being compiled on an Intel IA32-compatible system running the Linux operating system.

Some more helpful portability flags are located here: http://www.spec.org/auto/cpu2006/flags/400.perlbench.flags.html
