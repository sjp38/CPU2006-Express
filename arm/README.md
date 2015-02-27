ARM README
==========

Contents
--------

+ [Setup](#setup)
+ [Patching for ARM](#patches)
+ [Final Script](#create-script)
+ [Side Notes](#notes)
+ [Common Errors](#errors)
+ [All In One Script](#all-in-one-script)
+ [Project Main Page](/rspoone/automated-spec-cpu2006/tree/master/README.md)



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


I had build issues when forgetting to set the current system's date and time.


Errors:
-------


`checking build system type... config/config.guess: unable to guess system type`

I fixed this error by updating the CPU2006's config.guess files with the located current version [here](http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD). I also updated config.sub files for good measure (config.guess should suffice though). The current version of config.sub is [here](http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD).

To file the config.guess files:

```bash
find . -iname 'config.guess' -print0
```

Then copy your new config.guess file to those locations.

To file the config.sub files:

```bash
find . -iname 'config.sub' -print0
```

Then copy your new config.sub file to those locations.


---------------------------------------


`_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");`

I fixed this error by deleting this line in all files that contained it.

To find the files with `_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");`:

```bash
find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} +
```

To remove the line:

```bash
sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' tar-1.25/gnu/stdio.in.h

sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' specsum/gnulib/stdio.in.h

sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' tar-1.25/mingw/stdio.h

sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' specsum/win32/stdio.h
```


All In One Script:
------------------

```bash
cd ~/SPECCPU/tools/src

CPU=$(grep 'Processor' /proc/cpuinfo | uniq | sed 's/Processor\s*:\s//g' | sed 's/\s@\s*.*//g' | sed 's/([^)]*)//g' | sed 's/CPU\s*//g')

MARCH=$(gcc -march=native -Q --help=target | grep march)
if [[ $CPU == *'AArch'* ]]; then
  MARCH='armv8-a'
fi

export FORCE_UNSAFE_CONFIGURE=1
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

# update the config.sub files
chmod 775 ../../../arm/config.sub
while IFS= read -d $'\0' -r sub_file ; do
  printf 'Updating config.sub file: %s\n' "$sub_file"
  cp ../../../arm/config.sub $sub_file
done < <(find . -iname 'config.sub' -print0)

# fix errors
find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} + | awk '{print $1;}' | sed 's/:_GL_WARN_ON_USE//g' | while read -r gl_warn_file; do 
  printf 'Fixing _GL_WARN_ON_USE errors: %s\n' "$gl_warn_file"
  sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' $gl_warn_file
done

wait
read
./setup.sh
wait
```