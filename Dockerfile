# Copyright (c) 2024 Victor Chavez <vchavezb@protonmail.com>
# SPDX-License-Identifier: GPL-3.0

FROM debian:12.4 AS ffmpeg_build

ENV INSTALL_DIR /opt

RUN apt-get update -y && \
	apt-get install -y wget git cmake gcc g++

# Build FFMPEG and dependencies from source
# since dji sdk uses old version of ffmpeg
# This allows a controlled and reproducible build system
# https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu

WORKDIR /tmp


#####################
# FFMPEG build deps #
#####################
RUN	apt-get -y install \
		autoconf \
		automake \
		build-essential \
		libass-dev \
		libfreetype6-dev \
		libgnutls28-dev \
		libmp3lame-dev \
		libsdl2-dev \
		libtool \
		libva-dev \
		libvdpau-dev \
		libvorbis-dev \
		libxcb1-dev \
		libxcb-shm0-dev \
		libxcb-xfixes0-dev \
		meson \
		ninja-build \
		pkg-config \
		texinfo \
		wget \
		yasm \
		zlib1g-dev
		

# FFMPEG libs that are stable enough for use with
# version 4.4 and can be retrieved from debian packages

RUN apt-get install -y \
	libunistring-dev \
	nasm

# FFMPEG v2.8.15 is documented by dji drone to be the latest working version with
# their demos. https://github.com/dji-sdk/Onboard-SDK/issues/703#issuecomment-757608153
# However, last compatible version is ffmpeg v4.4 (April 8th, 2021). 
# This requires to adjust some library dependencies to work with this ffmpeg version.
# Note: Some libraries are compiled from source to keep reproducible builds of this
#		container but could also be installed from package manager.
#		In specific dav1d and svt-av1 MUST be be compiled from source
ENV FFMPEG_VERSION 4.4
# Video codecs
ENV DAV1D_VERSION 0.9.2
ENV SVT_AV1_VERSION 0.8.7
ENV X265_VERSION 3.5
ENV AOM_VERSION 3.8.1
ENV X264_VERSION stable

############
# libdav1d #
############
RUN git clone --branch $DAV1D_VERSION --depth 1 https://code.videolan.org/videolan/dav1d.git && \
	mkdir -p dav1d/build && \
	cd dav1d/build && \
	meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "$INSTALL_DIR" --libdir="$INSTALL_DIR/lib" && \
	ninja && \
	ninja install
	
################
# libsvtav1    #
################
RUN git clone --branch v$SVT_AV1_VERSION https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
	mkdir -p SVT-AV1/build && \
	cd SVT-AV1/build && \
	cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF .. && \
	ninja && \
	ninja install
	
############
# libx265  #
############	
RUN apt-get install libnuma-dev && \
	wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/Release_$X265_VERSION.tar.bz2 && \
	tar xjvf x265.tar.bz2 && \
	cd multicoreware*/build/linux && \
	cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DENABLE_SHARED=off ../../source && \
	ninja && \
	ninja install
	
############
# libx264  #
############	
RUN git clone --depth 1 --branch $X264_VERSION https://code.videolan.org/videolan/x264.git && \
	cd x264 && \
	./configure --prefix="$INSTALL_DIR" --enable-static --enable-pic && \
	make -j8 && \
	make install


###########
# libaom  #
###########
RUN git clone --branch v$AOM_VERSION --depth 1 https://aomedia.googlesource.com/aom && \
	mkdir -p aom_build && \
	cd aom_build && \
	cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DENABLE_TESTS=OFF -DENABLE_NASM=on ../aom && \
	ninja && \
	ninja install


# Audio Codecs
ENV FDK_AAC_VERSION 2.0.3
ENV VPX_VERSION 1.14.0
ENV OPUS_VERSION 1.4

###############
# libfdk-aac #
###############
RUN git clone --branch v$FDK_AAC_VERSION --depth 1 https://github.com/mstorsjo/fdk-aac && \
	cd fdk-aac && \
	autoreconf -fiv && \
	./configure --prefix="$INSTALL_DIR" --enable-shared && \
	make -j8 && \
	make install
	
############
# libvpx   #
############	
RUN git clone --branch v$VPX_VERSION --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
	cd libvpx && \
	./configure --prefix="$INSTALL_DIR" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
	make -j8 && \
	make install

############
# libopus  #
############	
RUN git clone --branch v$OPUS_VERSION --depth 1 https://github.com/xiph/opus.git && \
	cd opus && \
	./autogen.sh && \
	./configure --prefix="$INSTALL_DIR" --enable-shared && \
	make -j8 && \
	make install
	

RUN wget -q -O ffmpeg.tar.bz2 https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2 && \
	tar xjf ffmpeg.tar.bz2


RUN	cd ffmpeg-$FFMPEG_VERSION && \
	PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig" \
	./configure \
	  --prefix="$INSTALL_DIR" \
	  --pkg-config-flags="--static" \
	  --extra-libs="-lpthread -lm" \
      --extra-ldflags="-Wl,-Bsymbolic" \
	  --ld="g++" \
	  --enable-gpl \
	  --disable-doc \
	  --enable-gnutls \
# Decide whether to use libaom or libsvtav1
#	  --enable-libaom \
	  --enable-libsvtav1 \
	  --enable-libass \
	  --enable-libfreetype \
	  --enable-libmp3lame \
	  --enable-libfdk-aac \
	  --enable-libopus \
	  --enable-libvpx \
	  --enable-libdav1d \
	  --enable-libvorbis \
	  --enable-libx264 \
	  --enable-libx265 \
	  --enable-nonfree \
	  --enable-pic \
      --enable-shared && \
	make -j8 && \
	make install

ENV OPEN_CV_VERSION 3.4

RUN git clone --branch $OPEN_CV_VERSION --depth 1 https://github.com/opencv/opencv && \
	cd opencv && \
	mkdir build && \
	cd build && \
	cmake .. -G Ninja \
		-D CMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
		-D BUILD_EXAMPLES=OFF \
		-D INSTALL_PYTHON_EXAMPLES=OFF \
		-D INSTALL_C_EXAMPLES=OFF && \
	ninja && \
	ninja install

FROM debian:12.4

COPY --from=ffmpeg_build /opt/. /usr/local

RUN apt-get update -y

RUN apt-get install ninja-build git gcc g++ cmake -y
	
RUN apt-get install libusb-1.0-0-dev -y
RUN apt-get install libssl-dev -y
ENV DJI_SDK_VER=118e2825a347499efb8ed253146552c5b9b10779
ENV DJI_SDK_URL=https://github.com/dji-sdk/Onboard-SDK.git
ENV DJI_PSDK_GIT https://github.com/dji-sdk/Payload-SDK.git

COPY dji-osdk-include-fix.patch .

RUN	apt-get -y install \
		libass-dev \
		libmp3lame-dev \
		libsdl2-dev \
		libva-dev \
		libvdpau-dev \
		libvorbis-dev \
		libxcb1-dev \
		libxcb-shape0

RUN git clone --depth 1 --branch master $DJI_SDK_URL dji-osdk

RUN cd dji-osdk && \
	git apply ../dji-osdk-include-fix.patch

RUN cd dji-osdk && \
	mkdir build && \
	cd build && \
	cmake .. -G Ninja && \
	ninja

RUN git clone --depth 1 --branch master $DJI_PSDK_GIT dji-psdk && \
	cd dji-psdk && \
	mkdir build && \
	cd build && \
	cmake .. -G Ninja && \
	ninja
	
RUN apt-get clean -y
RUN rm -rf /var/lib/apt/lists/*





