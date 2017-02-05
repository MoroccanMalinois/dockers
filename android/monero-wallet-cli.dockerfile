FROM debian:jessie
MAINTAINER MoroccanMalinois@protonmail.com

RUN apt-get update && apt-get install -y unzip \
    automake \
    build-essential \
    wget \
    curl \
    file \
    pkg-config \
    git \
    python

#INSTALL ANDROID SDK
#COPY android-sdk_r24.4.1-linux.tgz  /usr/android-sdk_r24.4.1-linux.tgz
RUN cd /usr \
    && wget http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
    && tar --no-same-owner -xzf android-sdk_r24.4.1-linux.tgz \
    && rm -f /usr/android-sdk_r24.4.1-linux.tgz

ENV ANDROID_SDK_ROOT /usr/android-sdk-linux
ENV PATH $PATH:$ANDROID_SDK_ROOT/tools
ENV PATH $PATH:$ANDROID_SDK_ROOT/platform-tools

#INSTALL ANDROID NDK
ENV ANDROID_NDK_REVISION 14-beta1
#COPY android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip /usr/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip
RUN cd /usr \
    && wget https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && unzip android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && rm -f /usr/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip
ENV ANDROID_NDK_ROOT /usr/android-ndk-r${ANDROID_NDK_REVISION}

ENV TOOLCHAIN_DIR /usr/toolchain-arm
RUN $ANDROID_NDK_ROOT/build/tools/make_standalone_toolchain.py \
         --arch arm \
         --api 21 \
         --install-dir $TOOLCHAIN_DIR \
         --stl=libc++

ENV SYSROOT $TOOLCHAIN_DIR/sysroot
ENV PATH $PATH:$TOOLCHAIN_DIR/bin:$SYSROOT/usr/local/bin

#INSTALL BOOST
ENV BOOST_VERSION 1_62_0
ENV BOOST_VERSION_DOT 1.62.0
#COPY boost_${BOOST_VERSION}.tar.bz2 /usr/boost_${BOOST_VERSION}.tar.bz2
RUN cd /usr \
    && wget https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION_DOT}/boost_${BOOST_VERSION}.tar.bz2/download -O  boost_${BOOST_VERSION}.tar.bz2\
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && rm -f /usr/boost_${BOOST_VERSION}.tar.bz2

RUN echo "import tools ; \
using gcc : arm : arm-linux-androideabi-clang++ ; \
option.set keep-going : false ; " > ~/user-config.jam

RUN cd /usr/boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=/usr/boost  --with-libraries=serialization,thread,system,date_time,filesystem,regex,chrono,program_options \
    && ./b2 toolset=gcc-arm link=static install

#INSTALL cmake
# don't use 3.7 : https://github.com/android-ndk/ndk/issues/254
ENV CMAKE_VERSION 3.6.3
RUN cd /usr \
    && wget https://cmake.org/files/v3.6/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && tar -xvzf /usr/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && rm -f /usr/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz
ENV PATH /usr/cmake-${CMAKE_VERSION}-Linux-x86_64/bin:$PATH

ENV SYSROOT $TOOLCHAIN_DIR/sysroot
ENV PATH $PATH:$TOOLCHAIN_DIR/bin:$SYSROOT/usr/local/bin

# Configure toolchain path
#ENV CROSS_COMPILE arm-linux-androideabi
ENV CC arm-linux-androideabi-clang
ENV CXX arm-linux-androideabi-clang++
ENV AR arm-linux-androideabi-ar
ENV AS arm-linux-androideabi-as
ENV LD arm-linux-androideabi-ld
ENV RANLIB arm-linux-androideabi-ranlib
ENV NM arm-linux-androideabi-nm
ENV STRIP arm-linux-androideabi-strip
ENV CHOST arm-linux-androideabi
ENV ARCH armv7-a
ENV CXXFLAGS -std=c++11

# download, configure and make Zlib
ENV ZLIB_VERSION 1.2.11
RUN cd /usr \
    && curl -O http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
    && tar -xzf zlib-${ZLIB_VERSION}.tar.gz \
    && rm zlib-${ZLIB_VERSION}.tar.gz \
    && mv zlib-${ZLIB_VERSION} zlib \
    && cd zlib && ./configure --static \
    && make 

# open ssl
ENV CPPFLAGS -mthumb -mfloat-abi=softfp -mfpu=vfp -march=$ARCH  -DANDROID
ENV OPENSSL_VERSION 1.0.2k
RUN cd /usr \
    && curl -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && rm openssl-${OPENSSL_VERSION}.tar.gz \
    && cd /usr/openssl-${OPENSSL_VERSION} \
    && sed -i -e "s/mandroid/target\ armv7\-none\-linux\-androideabi/" Configure \
    && ./Configure android-armv7 \
           no-asm \
           no-shared --static \
           --with-zlib-include=/usr/zlib/include --with-zlib-lib=/usr/zlib/lib \
    && make build_crypto build_ssl -j 4 \
    && cd /usr && mv openssl-${OPENSSL_VERSION}  openssl

#NB : don't know how to produce a clean environnement to just run make release-static-android
#NB2 : only build simplewallet because fails for monerod
RUN cd /usr \
    && git clone https://github.com/monero-project/monero.git \
    && cd monero \
    && mkdir build/release \
    && cd build/release && cmake \
        -D OPENSSL_USE_STATIC_LIBS=true -D OPENSSL_ROOT_DIR=/usr/openssl -D OPENSSL_INCLUDE_DIR=/usr/openssl/include \
        -D BOOST_IGNORE_SYSTEM_PATHS=ON -D BOOST_ROOT=/usr/boost \
        -D ATOMIC=/usr/toolchain-arm/arm-linux-androideabi/lib/armv7-a/libatomic.a \
        -D BUILD_TESTS=OFF -D ARCH="armv7-a" -D STATIC=ON -D BUILD_64=OFF -D CMAKE_BUILD_TYPE=release -D ANDROID=true -D INSTALL_VENDORED_LIBUNBOUND=ON ../.. \
    && cd src/simplewallet \
    && make -j4 


