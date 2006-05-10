#!/usr/local/bin/perl
# A bit of an evil hack but it post processes the file ../MINFO which
# is generated by `make files` in the top directory.
# This script outputs one mega makefile that has no shell stuff or any
# funny stuff
#

$INSTALLTOP="/usr/local/ssl";
$OPTIONS="";
$ssl_version="";
$banner="\t\@echo Building OpenSSL";

open(IN,"<Makefile") || die "unable to open Makefile!\n";
while(<IN>) {
    $ssl_version=$1 if (/^VERSION=(.*)$/);
    $OPTIONS=$1 if (/^OPTIONS=(.*)$/);
    $INSTALLTOP=$1 if (/^INSTALLTOP=(.*$)/);
}
close(IN);

die "Makefile is not the toplevel Makefile!\n" if $ssl_version eq "";

$infile="MINFO";

%ops=(
	"VC-WIN32",   "Microsoft Visual C++ [4-6] - Windows NT or 9X",
	"VC-CE",   "Microsoft eMbedded Visual C++ 3.0 - Windows CE ONLY",
	"VC-NT",   "Microsoft Visual C++ [4-6] - Windows NT ONLY",
	"VC-W31-16",  "Microsoft Visual C++ 1.52 - Windows 3.1 - 286",
	"VC-WIN16",   "Alias for VC-W31-32",
	"VC-W31-32",  "Microsoft Visual C++ 1.52 - Windows 3.1 - 386+",
	"VC-MSDOS","Microsoft Visual C++ 1.52 - MSDOS",
	"Mingw32", "GNU C++ - Windows NT or 9x",
	"Mingw32-files", "Create files with DOS copy ...",
	"BC-NT",   "Borland C++ 4.5 - Windows NT",
	"BC-W31",  "Borland C++ 4.5 - Windows 3.1 - PROBABLY NOT WORKING",
	"BC-MSDOS","Borland C++ 4.5 - MSDOS",
	"linux-elf","Linux elf",
	"ultrix-mips","DEC mips ultrix",
	"FreeBSD","FreeBSD distribution",
	"OS2-EMX", "EMX GCC OS/2",
	"default","cc under unix",
	);

$platform="";
my $xcflags="";
foreach (@ARGV)
	{
	if (!&read_options && !defined($ops{$_}))
		{
		print STDERR "unknown option - $_\n";
		print STDERR "usage: perl mk1mf.pl [options] [system]\n";
		print STDERR "\nwhere [system] can be one of the following\n";
		foreach $i (sort keys %ops)
		{ printf STDERR "\t%-10s\t%s\n",$i,$ops{$i}; }
		print STDERR <<"EOF";
and [options] can be one of
	no-md2 no-md4 no-md5 no-sha no-mdc2	- Skip this digest
	no-ripemd
	no-rc2 no-rc4 no-rc5 no-idea no-des     - Skip this symetric cipher
	no-bf no-cast no-aes
	no-rsa no-dsa no-dh			- Skip this public key cipher
	no-ssl2 no-ssl3				- Skip this version of SSL
	just-ssl				- remove all non-ssl keys/digest
	no-asm 					- No x86 asm
	no-krb5					- No KRB5
	no-ec					- No EC
	no-engine				- No engine
	no-hw					- No hw
	nasm 					- Use NASM for x86 asm
	gaswin					- Use GNU as with Mingw32
	no-socks				- No socket code
	no-err					- No error strings
	dll/shlib				- Build shared libraries (MS)
	debug					- Debug build
        profile                                 - Profiling build
	gcc					- Use Gcc (unix)

Values that can be set
TMP=tmpdir OUT=outdir SRC=srcdir BIN=binpath INC=header-outdir CC=C-compiler

-L<ex_lib_path> -l<ex_lib>			- extra library flags (unix)
-<ex_cc_flags>					- extra 'cc' flags,
						  added (MS), or replace (unix)
EOF
		exit(1);
		}
	$platform=$_;
	}
foreach (grep(!/^$/, split(/ /, $OPTIONS)))
	{
	print STDERR "unknown option - $_\n" if !&read_options;
	}

$no_mdc2=1 if ($no_des);

$no_ssl3=1 if ($no_md5 || $no_sha);
$no_ssl3=1 if ($no_rsa && $no_dh);

$no_ssl2=1 if ($no_md5);
$no_ssl2=1 if ($no_rsa);

$out_def="out";
$inc_def="outinc";
$tmp_def="tmp";

$mkdir="-mkdir";

($ssl,$crypto)=("ssl","crypto");
$ranlib="echo ranlib";

$cc=(defined($VARS{'CC'}))?$VARS{'CC'}:'cc';
$src_dir=(defined($VARS{'SRC'}))?$VARS{'SRC'}:'.';
$bin_dir=(defined($VARS{'BIN'}))?$VARS{'BIN'}:'';

# $bin_dir.=$o causes a core dump on my sparc :-(

$NT=0;

push(@INC,"util/pl","pl");
if ($platform eq "VC-MSDOS")
	{
	$asmbits=16;
	$msdos=1;
	require 'VC-16.pl';
	}
elsif ($platform eq "VC-W31-16")
	{
	$asmbits=16;
	$msdos=1; $win16=1;
	require 'VC-16.pl';
	}
elsif (($platform eq "VC-W31-32") || ($platform eq "VC-WIN16"))
	{
	$asmbits=32;
	$msdos=1; $win16=1;
	require 'VC-16.pl';
	}
elsif (($platform eq "VC-WIN32") || ($platform eq "VC-NT"))
	{
	$NT = 1 if $platform eq "VC-NT";
	require 'VC-32.pl';
	}
elsif ($platform eq "VC-CE")
	{
	require 'VC-CE.pl';
	}
elsif ($platform eq "Mingw32")
	{
	require 'Mingw32.pl';
	}
elsif ($platform eq "Mingw32-files")
	{
	require 'Mingw32f.pl';
	}
elsif ($platform eq "BC-NT")
	{
	$bc=1;
	require 'BC-32.pl';
	}
elsif ($platform eq "BC-W31")
	{
	$bc=1;
	$msdos=1; $w16=1;
	require 'BC-16.pl';
	}
elsif ($platform eq "BC-Q16")
	{
	$msdos=1; $w16=1; $shlib=0; $qw=1;
	require 'BC-16.pl';
	}
elsif ($platform eq "BC-MSDOS")
	{
	$asmbits=16;
	$msdos=1;
	require 'BC-16.pl';
	}
elsif ($platform eq "FreeBSD")
	{
	require 'unix.pl';
	$cflags='-DTERMIO -D_ANSI_SOURCE -O2 -fomit-frame-pointer';
	}
elsif ($platform eq "linux-elf")
	{
	require "unix.pl";
	require "linux.pl";
	$unix=1;
	}
elsif ($platform eq "ultrix-mips")
	{
	require "unix.pl";
	require "ultrix.pl";
	$unix=1;
	}
elsif ($platform eq "OS2-EMX")
	{
	$wc=1;
	require 'OS2-EMX.pl';
	}
else
	{
	require "unix.pl";

	$unix=1;
	$cflags.=' -DTERMIO';
	}

$out_dir=(defined($VARS{'OUT'}))?$VARS{'OUT'}:$out_def.($debug?".dbg":"");
$tmp_dir=(defined($VARS{'TMP'}))?$VARS{'TMP'}:$tmp_def.($debug?".dbg":"");
$inc_dir=(defined($VARS{'INC'}))?$VARS{'INC'}:$inc_def;

$bin_dir=$bin_dir.$o unless ((substr($bin_dir,-1,1) eq $o) || ($bin_dir eq ''));

$cflags= "$xcflags$cflags" if $xcflags ne "";

$cflags.=" -DOPENSSL_NO_IDEA" if $no_idea;
$cflags.=" -DOPENSSL_NO_AES"  if $no_aes;
$cflags.=" -DOPENSSL_NO_RC2"  if $no_rc2;
$cflags.=" -DOPENSSL_NO_RC4"  if $no_rc4;
$cflags.=" -DOPENSSL_NO_RC5"  if $no_rc5;
$cflags.=" -DOPENSSL_NO_MD2"  if $no_md2;
$cflags.=" -DOPENSSL_NO_MD4"  if $no_md4;
$cflags.=" -DOPENSSL_NO_MD5"  if $no_md5;
$cflags.=" -DOPENSSL_NO_SHA"  if $no_sha;
$cflags.=" -DOPENSSL_NO_SHA1" if $no_sha1;
$cflags.=" -DOPENSSL_NO_RIPEMD" if $no_ripemd;
$cflags.=" -DOPENSSL_NO_MDC2" if $no_mdc2;
$cflags.=" -DOPENSSL_NO_BF"   if $no_bf;
$cflags.=" -DOPENSSL_NO_CAST" if $no_cast;
$cflags.=" -DOPENSSL_NO_DES"  if $no_des;
$cflags.=" -DOPENSSL_NO_RSA"  if $no_rsa;
$cflags.=" -DOPENSSL_NO_DSA"  if $no_dsa;
$cflags.=" -DOPENSSL_NO_DH"   if $no_dh;
$cflags.=" -DOPENSSL_NO_SOCK" if $no_sock;
$cflags.=" -DOPENSSL_NO_SSL2" if $no_ssl2;
$cflags.=" -DOPENSSL_NO_SSL3" if $no_ssl3;
$cflags.=" -DOPENSSL_NO_ERR"  if $no_err;
$cflags.=" -DOPENSSL_NO_KRB5" if $no_krb5;
$cflags.=" -DOPENSSL_NO_EC"   if $no_ec;
$cflags.=" -DOPENSSL_NO_ENGINE"   if $no_engine;
$cflags.=" -DOPENSSL_NO_HW"   if $no_hw;
$cflags.=" -DOPENSSL_FIPS"    if $fips;
#$cflags.=" -DRSAref"  if $rsaref ne "";

## if ($unix)
##	{ $cflags="$c_flags" if ($c_flags ne ""); }
##else
	{ $cflags="$c_flags$cflags" if ($c_flags ne ""); }

$ex_libs="$l_flags$ex_libs" if ($l_flags ne "");

%shlib_ex_cflags=("SSL" => " -DOPENSSL_BUILD_SHLIBSSL",
		  "CRYPTO" => " -DOPENSSL_BUILD_SHLIBCRYPTO");

if ($msdos)
	{
	$banner ="\t\@echo Make sure you have run 'perl Configure $platform' in the\n";
	$banner.="\t\@echo top level directory, if you don't have perl, you will\n";
	$banner.="\t\@echo need to probably edit crypto/bn/bn.h, check the\n";
	$banner.="\t\@echo documentation for details.\n";
	}

# have to do this to allow $(CC) under unix
$link="$bin_dir$link" if ($link !~ /^\$/);

$INSTALLTOP =~ s|/|$o|g;

#############################################
# We parse in input file and 'store' info for later printing.
open(IN,"<$infile") || die "unable to open $infile:$!\n";
$_=<IN>;
for (;;)
	{
	chop;

	($key,$val)=/^([^=]+)=(.*)/;
	if ($key eq "RELATIVE_DIRECTORY")
		{
		if ($lib ne "")
			{
			$uc=$lib;
			$uc =~ s/^lib(.*)\.a/$1/;
			$uc =~ tr/a-z/A-Z/;
			$lib_nam{$uc}=$uc;
			$lib_obj{$uc}.=$libobj." ";
			}
		last if ($val eq "FINISHED");
		$lib="";
		$libobj="";
		$dir=$val;
		}

	if ($key eq "KRB5_INCLUDES")
		{ $cflags .= " $val";}

	if ($key eq "LIBKRB5")
		{ $ex_libs .= " $val";}

	if ($key eq "TEST")
		{ $test.=&var_add($dir,$val); }

	if (($key eq "PROGS") || ($key eq "E_OBJ"))
		{ $e_exe.=&var_add($dir,$val); }

	if ($key eq "LIB")
		{
		$lib=$val;
		$lib =~ s/^.*\/([^\/]+)$/$1/;
		}

	if ($key eq "EXHEADER")
		{ $exheader.=&var_add($dir,$val); }

	if ($key eq "HEADER")
		{ $header.=&var_add($dir,$val); }

	if ($key eq "LIBOBJ")
		{ $libobj=&var_add($dir,$val); }

	if (!($_=<IN>))
		{ $_="RELATIVE_DIRECTORY=FINISHED\n"; }
	}
close(IN);

$defs= <<"EOF";
# This makefile has been automatically generated from the OpenSSL distribution.
# This single makefile will build the complete OpenSSL distribution and
# by default leave the 'intertesting' output files in .${o}out and the stuff
# that needs deleting in .${o}tmp.
# The file was generated by running 'make makefile.one', which
# does a 'make files', which writes all the environment variables from all
# the makefiles to the file call MINFO.  This file is used by
# util${o}mk1mf.pl to generate makefile.one.
# The 'makefile per directory' system suites me when developing this
# library and also so I can 'distribute' indervidual library sections.
# The one monster makefile better suits building in non-unix
# environments.

EOF

$defs .= $preamble if defined $preamble;

if ($platform eq "VC-CE")
	{
	$defs.= <<"EOF";
!INCLUDE <\$(WCECOMPAT)/wcedefs.mak>

EOF
	}

$defs.= <<"EOF";
INSTALLTOP=$INSTALLTOP

# Set your compiler options
PLATFORM=$platform
CC=$bin_dir${cc}
CFLAG=$cflags
APP_CFLAG=$app_cflag
LIB_CFLAG=$lib_cflag
SHLIB_CFLAG=$shl_cflag
APP_EX_OBJ=$app_ex_obj
SHLIB_EX_OBJ=$shlib_ex_obj
# add extra libraries to this define, for solaris -lsocket -lnsl would
# be added
EX_LIBS=$ex_libs

# The OpenSSL directory
SRC_D=$src_dir

LINK=$link
LFLAGS=$lflags

BN_ASM_OBJ=$bn_asm_obj
BN_ASM_SRC=$bn_asm_src
BNCO_ASM_OBJ=$bnco_asm_obj
BNCO_ASM_SRC=$bnco_asm_src
DES_ENC_OBJ=$des_enc_obj
DES_ENC_SRC=$des_enc_src
BF_ENC_OBJ=$bf_enc_obj
BF_ENC_SRC=$bf_enc_src
CAST_ENC_OBJ=$cast_enc_obj
CAST_ENC_SRC=$cast_enc_src
RC4_ENC_OBJ=$rc4_enc_obj
RC4_ENC_SRC=$rc4_enc_src
RC5_ENC_OBJ=$rc5_enc_obj
RC5_ENC_SRC=$rc5_enc_src
MD5_ASM_OBJ=$md5_asm_obj
MD5_ASM_SRC=$md5_asm_src
SHA1_ASM_OBJ=$sha1_asm_obj
SHA1_ASM_SRC=$sha1_asm_src
RMD160_ASM_OBJ=$rmd160_asm_obj
RMD160_ASM_SRC=$rmd160_asm_src

# The output directory for everything intersting
OUT_D=$out_dir
# The output directory for all the temporary muck
TMP_D=$tmp_dir
# The output directory for the header files
INC_D=$inc_dir
INCO_D=$inc_dir${o}openssl

CP=$cp
RM=$rm
RANLIB=$ranlib
MKDIR=$mkdir
MKLIB=$bin_dir$mklib
MLFLAGS=$mlflags
ASM=$bin_dir$asm

######################################################
# You should not need to touch anything below this point
######################################################

E_EXE=openssl
SSL=$ssl
CRYPTO=$crypto

# BIN_D  - Binary output directory
# TEST_D - Binary test file output directory
# LIB_D  - library output directory
# Note: if you change these point to different directories then uncomment out
# the lines around the 'NB' comment below.
# 
BIN_D=\$(OUT_D)
TEST_D=\$(OUT_D)
LIB_D=\$(OUT_D)

# INCL_D - local library directory
# OBJ_D  - temp object file directory
OBJ_D=\$(TMP_D)
INCL_D=\$(TMP_D)

O_SSL=     \$(LIB_D)$o$plib\$(SSL)$shlibp
O_CRYPTO=  \$(LIB_D)$o$plib\$(CRYPTO)$shlibp
SO_SSL=    $plib\$(SSL)$so_shlibp
SO_CRYPTO= $plib\$(CRYPTO)$so_shlibp
L_SSL=     \$(LIB_D)$o$plib\$(SSL)$libp
L_CRYPTO=  \$(LIB_D)$o$plib\$(CRYPTO)$libp

L_LIBS= \$(L_SSL) \$(L_CRYPTO)

######################################################
