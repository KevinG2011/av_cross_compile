#!/bin/sh

CONFIGURE_FLAGS="--enable-static --disable-shared"

#ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="arm64 armv7 x86_64"
# directories
SOURCE="fdk-aac-2.0.0"

CWD=`pwd`
SROUCE_DIR="$CWD/$SOURCE"
echo $SROUCE_DIR
cd $SROUCE_DIR
make distclean
cd $CWD

FAT="fat-fdk-aac"

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
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH -fembed-bitcode"

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
		else
			PLATFORM="iPhoneOS"
			CPU=
		    if [ "$ARCH" = "arm64" ]
		    then
#		        CFLAGS="$CFLAGS -D__arm__ -D__ARM_ARCH_7EM__" # hack!
				SIMULATOR="-mios-version-min=9.0"
		        HOST="--host=aarch64-apple-darwin"
			else
                SIMULATOR="-mios-version-min=9.0"
		        HOST="--host=arm-apple-darwin"
	        fi
		fi
		
		CFLAGS="$CFLAGS $SIMULATOR"

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH -Wno-error=unused-command-line-argument-hard-error-in-future"
		AS="gas-preprocessor.pl $CC"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		$CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    CC="$CC" \
		    CXX="$CC" \
		    CPP="$CC -E" \
			AS="$AS" \
		    CFLAGS="$CFLAGS" \
		    LDFLAGS="$LDFLAGS" \
		    CPPFLAGS="$CFLAGS" \
		    --prefix="$THIN/$ARCH"

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