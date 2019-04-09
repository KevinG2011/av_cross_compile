#!/bin/sh  

#make distclean  

CONFIGURE_FLAGS="--disable-shared --disable-frontend"  

ARCHS="armv7 arm64 x86_64"  

# SOURCE是下载lame源码包，解压后的目录，可以把sh脚本放到这个目录，source改为""  
SOURCE=""  
# FAT是所有指令集build后，输出的目录，所有静态库被合并成一个静态库  
FAT="fat-lame"

# SCRATCH是下载lame源码包，解压后的目录，必须是绝对路径  
SCRATCH=`pwd`
echo $SCRATCH
# must be an absolute path  
# THIN 各自指令集build后输出的静态库所在的目录，每个指令集为一个静态库  
THIN=$SCRATCH/"thin"  
echo $THIN
  
COMPILE=""  
LIPO="y"  


if [ "$*" ]
then  
	if [ "$*" = "lipo" ]  
	then  
		# skip compile  
		COMPILE=  
	else
		ARCHS="$*"  
		if [ $# -eq 1 ]  
		then  
			# skip lipo  
			LIPO=  
		fi  
	fi  
fi  


if [ "$COMPILE" ]  
then  
	CWD=`pwd`  
	echo "$CWD/$SOURCE........."  
	for ARCH in $ARCHS  
	do  
		echo "building $ARCH..."  
		mkdir -p "$THIN/$ARCH"
#		mkdir -p "$SCRATCH/$ARCH"  
#		cd "$SCRATCH/$ARCH"
		
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]  
		then  
			PLATFORM="iPhoneSimulator"  
			if [ "$ARCH" = "x86_64" ]  
			then  
				SIMULATOR="-mios-simulator-version-min=9.0"  
				HOST=x86_64-apple-darwin
			else  
				SIMULATOR="-mios-simulator-version-min=9.0"  
				HOST=i386-apple-darwin
			fi  
		else  
			PLATFORM="iPhoneOS"
			SIMULATOR="-miphoneos-version-min=9.0"
			HOST=arm-apple-darwin 
		fi  

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		echo $XCRUN_SDK
		#AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"  

		LDFLAGS="$CFLAGS"
		
		./configure \
		--disable-shared \
		--disable-frontend \
		--host=$HOST \
		--prefix="$THIN/$ARCH" \
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH" \
		CFLAGS="-arch $ARCH -fembed-bitcode $SIMULATOR" \
		LDFLAGS="-arch $ARCH -fembed-bitcode $SIMULATOR" 

		make clean
		make -j3 install  
	done  
fi  

if [ "$LIPO" ]  
then  
	echo "building fat binaries..."  
	mkdir -p $FAT/lib  
	set - $ARCHS
	CWD=`pwd`  
	cd $THIN/$1/lib  
	for LIB in *.a  
	do  
		cd $CWD  
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB  
	done  
  
	cd $CWD  
	cp -rf $THIN/$1/include $FAT  
fi