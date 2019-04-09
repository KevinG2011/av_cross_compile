#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-shared"

#ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="arm64 armv7 x86_64"
# directories
SOURCE="x264"

CWD=`pwd`
SROUCE_DIR="$CWD/$SOURCE"
echo $SROUCE_DIR

FAT="fat-$SOURCE"

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"

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
	cd $SROUCE_DIR
	make distclean
	cd $CWD
	
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		ASFLAGS=
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
			PLATFORM="iPhoneSimulator"
			CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
				SIMULATOR="-mios-simulator-version-min=9.0"  
		    	HOST="--host=x86_64-apple-darwin"
		    else
				SIMULATOR="-mios-simulator-version-min=9.0"  
				HOST="--host=i386-apple-darwin"
		    fi
			CFLAGS="$CFLAGS $SIMULATOR"
		else
			PLATFORM="iPhoneOS"
			CPU=
		    if [ "$ARCH" = "arm64" ]
		    then
				SIMULATOR="-mios-version-min=9.0"
		        HOST="--host=aarch64-apple-darwin"
				XARCH="-arch aarch64"
			else
                SIMULATOR="-mios-version-min=9.0"
		        HOST="--host=arm-apple-darwin"
				XARCH="-arch arm"
	        fi
			CFLAGS="$CFLAGS $SIMULATOR"
			ASFLAGS="$CFLAGS"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		if [ $PLATFORM = "iPhoneOS" ]
		then
		    export AS="gas-preprocessor.pl $XARCH -- $CC"
		else
		    export -n AS
		fi
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --extra-cflags="$CFLAGS" \
		    --extra-asflags="$ASFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" || exit 1

		make -j8 install
		cd $CWD
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