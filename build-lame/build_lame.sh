#!/bin/sh  

CONFIGURE_FLAGS="--disable-shared --disable-frontend"  

#ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="armv7 arm64 x86_64"  
# directories
SOURCE="lame-3.100"

CWD=`pwd`
SROUCE_DIR="$CWD/$SOURCE"

FAT="fat-$SOURCE"

SCRATCH="scratch"
# must be an absolute path  
THIN=`pwd`/"thin"

COMPILE="y"
LIPO=""


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
	cd $SROUCE_DIR
	make distclean
	cd $CWD
	
	for ARCH in $ARCHS  
	do  
		echo "building $ARCH..."  
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"
		
		CFLAGS="-arch $ARCH -fembed-bitcode"
		
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]  
		then  
			PLATFORM="iPhoneSimulator"
			if [ "$ARCH" = "x86_64" ]  
			then  
				SIMULATOR="-mios-simulator-version-min=9.0"  
				HOST="--host=x86_64-apple-darwin"
			else  
				SIMULATOR="-mios-simulator-version-min=9.0"  
				HOST="--host=i386-apple-darwin"
			fi  
		else  
			PLATFORM="iPhoneOS"			
			if [ "$ARCH" = "arm64" ]
			then
				SIMULATOR="-miphoneos-version-min=9.0"
				HOST="--host=aarch64-apple-darwin"
			else
				SIMULATOR="-miphoneos-version-min=9.0"
				HOST="--host=arm-apple-darwin"
			fi
		fi  

		CFLAGS="$CFLAGS $SIMULATOR"
		
		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH "
		LDFLAGS="$CFLAGS"
		
		$CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --prefix="$THIN/$ARCH" \
		    CC="$CC" \
		    CFLAGS="$CFLAGS" \
		    LDFLAGS="$LDFLAGS" 
		
		make clean
		make -j8 install  
	done  
fi  

if [ "$LIPO" ]  
then  
	echo "building fat binaries..."  
	mkdir -p $FAT/lib  
	set - $ARCHS
	cd $THIN/$1/lib  
	for LIB in *.a  
	do  
		cd $CWD  
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB  
	done  
  
	cd $CWD  
	cp -rf $THIN/$1/include $FAT  
fi