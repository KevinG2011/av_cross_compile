#!/bin/sh

CONFIGURE_FLAGS="--enable-gpl --disable-shared --disable-stripping --disable-ffmpeg --disable-ffplay --disable-ffprobe --disable-avdevice --disable-indevs --disable-filters --disable-devices --disable-parsers --disable-postproc --disable-debug --disable-asm --disable-yasm --disable-doc --disable-bsfs --disable-muxers --disable-demuxers --disable-ffplay --disable-ffprobe --disable-outdevs --enable-cross-compile --enable-filter=aresample --enable-bsf=aac_adtstoasc --enable-bsf=h264_mp4toannexb --enable-small --enable-dct --enable-dwt --enable-lsp --enable-mdct --enable-rdft --enable-fft --enable-static --enable-version3 --enable-nonfree --disable-encoders --enable-encoder=pcm_s16le --enable-encoder=aac --enable-encoder=libx264 --enable-encoder=libmp3lame --enable-libmp3lame --enable-encoder=mp2 --disable-decoders --enable-decoder=aac --enable-decoder=mp3 --enable-decoder=h264 --enable-decoder=pcm_s16le --disable-parsers --enable-parser=aac --enable-parser=mpeg4video --enable-parser=mpegvideo --enable-parser=mpegaudio --enable-parser=aac --disable-muxers --enable-muxer=h264 --enable-muxer=flv --enable-muxer=mp4 --enable-muxer=mp3 --enable-muxer=wav --enable-muxer=adts --disable-demuxers --enable-demuxer=flv --enable-demuxer=mpegvideo --enable-demuxer=mpegtsraw --enable-demuxer=mpegts --enable-demuxer=mpegps --enable-demuxer=h264 --enable-demuxer=y4m --enable-demuxer=wav --enable-demuxer=aac --enable-demuxer=hls --enable-demuxer=mov --enable-demuxer=m4v --disable-protocols --enable-protocol=rtmp --enable-protocol=http --enable-protocol=file --enable-libx264 --enable-libfdk-aac --enable-libfdk_aac --enable-encoder=libfdk_aac"

#ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="arm64 armv7 x86_64"
# directories
SOURCE="FFmpeg"

CWD=`pwd`
SROUCE_DIR="$CWD/$SOURCE"
echo $SROUCE_DIR

FAT="fat-$SOURCE"

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"

# absolute path to x264 library
X264="`pwd`/../build-x264/fat-x264"

# absolute path to fdk-aac library
FDK_AAC="`pwd`/../build-fdk-aac/fat-fdk-aac"

COMPILE="y"
LIPO=""

DEPLOYMENT_TARGET="9.0"

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
	
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
			ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
			|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi
	
	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		echo 'usage gitsubmodule update --init --recursive'
		exit 1
	fi
	
	cd $SROUCE_DIR
	make distclean
	cd $CWD
	
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
			PLATFORM="iPhoneSimulator"
			CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
			PLATFORM="iPhoneOS"
			CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
			if [ "$ARCH" = "arm64" ]
			then
				EXPORT="GASPP_FIX_XCODE5=1"
			fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		if [ "$X264" ]
		then
			CFLAGS="$CFLAGS -I$X264/include"
			LDFLAGS="$LDFLAGS -L$X264/lib"
		fi
		if [ "$FDK_AAC" ]
		then
			CFLAGS="$CFLAGS -I$FDK_AAC/include"
			LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi
		
		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
			--target-os=darwin \
			--arch=$ARCH \
			--cc="$CC" \
			$CONFIGURE_FLAGS \
			--extra-cflags="$CFLAGS" \
			--extra-ldflags="$LDFLAGS" \
			--prefix="$THIN/$ARCH" \
		|| exit 1
		
		make clean
		make -j8 install $EXPORT || exit 1
		cd $CWD
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
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done
	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

echo Done