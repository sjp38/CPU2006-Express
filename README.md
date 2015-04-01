Benchmarking
============

This harness performs SPEC CPU2006 benchmarking using GCC. Capabilities include in installing prerequisites, building and installing SPEC CPU2006, and running reportable integer and floating-point runs.


Contents:
---------

+ [Download](#download)
+ [Usage](#usage)
+ [Required File Tree](#required-file-tree)
+ [Troubleshooting](#troubleshooting)
+ [Optimizing GCC Process](#process-for-optimizing-gcc)
+ [Runspec Errors](#runspec-errors)


Download:
=========

To download these files, first install git:

```bash
yum install git
```


Or if you are using a Debian-based distribution:

```bash
apt-get install git
```


Clone this repository:

```bash
git clone https://github.com/ryanspoone/cpu2006-express.git
```

Change directories and run this script:

```bash
cd cpu2006-express/
chmod +x cpu2006express.sh
./cpu2006express.sh
```


Usage:
======

Change to directory where files are, then start benchmarking by issuing the following
command:


For a full run:

```bash
./cpu2006express.sh
```

Customized run:

```bash
./cpu2006express.sh [OPTIONS]
```

Where the options are:

```
Option          GNU long option         Meaning
   -h             --help                  Show this message
   -r             --rebuild               Force SPEC CPU2006 rebuild and installation
   -o             --onecopy               Do a single copy run
   -i             --int                   Run integer
   -f             --fp                    Run floating-point
   -c             --complete              Do a complete run (int and fp) with defaults
   -p             --prereq                Install prerequisites
   -q             --quiet                 Show less detailed information
```


Required file tree:
==================
```
 |-- config
 |   |-- linux32-arm32-gcc.cfg
 |   |-- linux32-intel32-gcc.cfg
 |   |-- linux64-arm64-gcc.cfg
 |   |-- linux64-intel64-gcc.cfg
 |   `-- linux64-powerpc-gcc.cfg
 |
 |-- src
 |   |-- setup.sh
 |   |-- spinner.sh
 |   `-- user_input.sh
 |
 `-- cpu2006express.sh
```


TODO:
-----

1. Add ICC support
2. Add flags

Process for optimizing GCC:
===========================

1. Get GCC capable flags: `gcc -march=native -Q --help=target` or `echo "int main {return 0;}" | gcc [OPTIONS] -x c -v -Q -`
2. Go to [ARK](http://ark.intel.com/) to get CPU information and fill in hw_* information.
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
