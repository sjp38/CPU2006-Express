ARM README
==========

Contents
--------

+ [Setup](#setup)
+ [Patching for ARM](#patches)
+ [Final Script](#create-script)
+ [Side Notes](#notes)
+ [Common Errors](#errors)
+ [Project Main Page](/)



Setup
-----


Building the toolset:

SPEC does not include ARM binaries, as such they will need to be built.

```bash
cd SPECCPU
```

```bash
cd tools/src
```


If root, set the environment variable as follows:

```bash
export FORCE_UNSAFE_CONFIGURE=1
```

Patches
-------


First apply this patch to fix the problem in the tools sources. All other systems where builds were done silently ignored the problem but on my build system it is strict. This patch should fix it:

```bash
vi specinvoke/unix.c
```


Before:
```c
                fprintf (stderr, "Can't create zero-length temporary filename\n ");
                specinvoke_exit (1, si);
              }
              infd = open(tmpfile, O_RDWR|O_CREAT|O_TRUNC);
              if (infd < 0) {
                fprintf (stderr, "Can't create %s for stdin: %s(%d)\n",
                         tmpfile, STRERROR(errno), errno);
```

After:
```c
                fprintf (stderr, "Can't create zero-length temporary filename\n ");
                specinvoke_exit (1, si);
              }
              infd = open(tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
              if (infd < 0) {
                fprintf (stderr, "Can't create %s for stdin: %s(%d)\n",
                         tmpfile, STRERROR(errno), errno);
```

Then this patch:

```bash
vi perl-5.12.3/makedepend.SH
```


Before:
```bash
 echo "Extracting makedepend (with variable substitutions)"
 rm -f makedepend
 $spitshell >makedepend <<!GROK!THIS!
 $startsh
 # makedepend.SH
 #
 MAKE=$make
```


After:
```bash
 echo "Extracting makedepend (with variable substitutions)"
 rm -f makedepend
 $spitshell >makedepend <<!GROK!THIS!
 $startsh -x
 set -x
 # makedepend.SH
 #
 MAKE=$make
```


Create script
-------------


The problem in a nutshell is that standard libraries aren't in standard locations, so this tells Perl's Configure to look in the same places that GCC already knows to look.


```bash
vi setup.sh
```


```bash
#!/bin/bash
PERLFLAGS=-Uplibpth=
for i in `gcc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' '\n' | grep -v /gcc`; do
PERLFLAGS="$PERLFLAGS -Aplibpth=$i"
done
export PERLFLAGS
echo $PERLFLAGS
export CFLAGS="-O2 -march=native -mtune=native"
echo $CFLAGS
./buildtools
```


Now build the tools:


```bash
chmod +x setup.sh
```

```bash
./setup.sh
```


Notes:
------


I had build issues is I forgot to set the current system time / date


Errors:
-------


`_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");`

I fixed this error by deleting this line in all files that contained it.

To find the files:

```bash
find ./ -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} +
```

To remove the line:

```bash
sed 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' tar-1.25/gnu/stdio.in.h > tar-1.25/gnu/stdio.in.h.tmp; mv tar-1.25/gnu/stdio.in.h.tmp tar-1.25/gnu/stdio.in.h
sed 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' specsum/gnulib/stdio.in.h > specsum/gnulib/stdio.in.h.tmp; mv specsum/gnulib/stdio.in.h.tmp specsum/gnulib/stdio.in.h
sed 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' tar-1.25/gnu/stdio.h > tar-1.25/gnu/stdio.h.tmp; mv tar-1.25/gnu/stdio.h.tmp tar-1.25/gnu/stdio.h
sed 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' tar-1.25/mingw/stdio.h > tar-1.25/mingw/stdio.h.tmp; mv tar-1.25/mingw/stdio.h.tmp tar-1.25/mingw/stdio.h
sed 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' specsum/win32/stdio.h > specsum/win32/stdio.h.tmp; mv specsum/win32/stdio.h.tmp specsum/win32/stdio.h
```