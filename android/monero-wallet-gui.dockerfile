FROM debian:jessie
MAINTAINER MoroccanMalinois <MoroccanMalinois@protonmail.com>

#INSTALL JAVA
RUN echo "deb http://ftp.fr.debian.org/debian/ jessie-backports main contrib" >> /etc/apt/sources.list
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 libz1:i386 \
       openjdk-8-jdk-headless openjdk-8-jre-headless ant \
       unzip make python git build-essential wget
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$PATH

ENV WORKSPACE /usr

#INSTALL ANDROID SDK
#COPY android-sdk_r24.4.1-linux.tgz  ${WORKSPACE}/android-sdk_r24.4.1-linux.tgz
RUN cd ${WORKSPACE} \
    && wget -q http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
    && tar --no-same-owner -xzf android-sdk_r24.4.1-linux.tgz \
    && rm -f ${WORKSPACE}/android-sdk_r24.4.1-linux.tgz

ENV ANDROID_SDK_ROOT ${WORKSPACE}/android-sdk-linux
ENV PATH $PATH:$ANDROID_SDK_ROOT/tools
ENV PATH $PATH:$ANDROID_SDK_ROOT/platform-tools

#INSTALL ANDROID NDK
ENV ANDROID_NDK_REVISION 14-beta1
#COPY android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip ${WORKSPACE}/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip
RUN cd ${WORKSPACE} \
    && wget -q https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && unzip -qq android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && rm -f ${WORKSPACE}/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip
ENV ANDROID_NDK_ROOT ${WORKSPACE}/android-ndk-r${ANDROID_NDK_REVISION}

#Get Qt
ENV QT_VERSION 5.7
ENV ANDROID_API android-21

RUN cd ${WORKSPACE} \
    && git clone git://code.qt.io/qt/qt5.git -b ${QT_VERSION} \
    && cd qt5 \
    && perl init-repository 

#Create new mkspec for clang + libc++
RUN cp -r ${WORKSPACE}/qt5/qtbase/mkspecs/android-clang ${WORKSPACE}/qt5/qtbase/mkspecs/android-clang-libc \
    && cd ${WORKSPACE}/qt5/qtbase/mkspecs/android-clang-libc \
    && sed -i '16i ANDROID_SOURCES_CXX_STL_LIBDIR = $$NDK_ROOT/sources/cxx-stl/llvm-libc++/libs/$$ANDROID_TARGET_ARCH' qmake.conf \
    && sed -i '17i ANDROID_SOURCES_CXX_STL_INCDIR = $$NDK_ROOT/sources/cxx-stl/llvm-libc++/include' qmake.conf \
    && echo "QMAKE_LIBS_PRIVATE      = -lc++_shared -llog -lz -lm -ldl -lc -lgcc " >> qmake.conf \
    && echo "QMAKE_CFLAGS -= -mfpu=vfp " >> qmake.conf \
    && echo "QMAKE_CXXFLAGS -= -mfpu=vfp " >> qmake.conf \ 
    && echo "QMAKE_CFLAGS += -mfpu=vfp4 " >> qmake.conf \
    && echo "QMAKE_CXXFLAGS += -mfpu=vfp4 " >> qmake.conf 

    
#ANDROID SDK TOOLS
RUN echo y | $ANDROID_SDK_ROOT/tools/android update sdk --no-ui --all --filter platform-tools 
RUN echo y | $ANDROID_SDK_ROOT/tools/android update sdk --no-ui --all --filter android-21
RUN echo y | $ANDROID_SDK_ROOT/tools/android update sdk --no-ui --all --filter build-tools-25.0.1 

#build Qt
RUN cd ${WORKSPACE}/qt5 && ./configure -developer-build -release \
    -xplatform android-clang-libc \
    -android-ndk-platform ${ANDROID_API} \
    -android-ndk $ANDROID_NDK_ROOT \
    -android-sdk $ANDROID_SDK_ROOT \
    -opensource -confirm-license \
    -prefix ${WORKSPACE}/Qt-${QT_VERSION} \
    -nomake tests -nomake examples \
    -skip qtserialport \
    -skip qtconnectivity \
    -skip qttranslations \
    -skip qtgamepad -skip qtscript -skip qtdoc

#build Qt tools : uggly patch !!
COPY androiddeployqt.patch ${WORKSPACE}/qt5/qttools/androiddeployqt.patch
RUN cd ${WORKSPACE}/qt5 \
    && cd qttools \
    && git apply androiddeployqt.patch \
    && cd ${WORKSPACE}/qt5 \
    && make -j4 \
    && make install

ENV PATH ${WORKSPACE}/qt5/${QT_VERSION}/android_armv7/bin:$PATH

#Setup Android toolchain
ENV TOOLCHAIN_DIR ${WORKSPACE}/toolchain-arm
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
#COPY boost_${BOOST_VERSION}.tar.bz2 ${WORKSPACE}/boost_${BOOST_VERSION}.tar.bz2
RUN cd ${WORKSPACE} \
    && wget -q https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION_DOT}/boost_${BOOST_VERSION}.tar.bz2/download -O  boost_${BOOST_VERSION}.tar.bz2\
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && rm -f ${WORKSPACE}/boost_${BOOST_VERSION}.tar.bz2

RUN echo "import tools ; \
using gcc : arm : arm-linux-androideabi-clang++ ; \
option.set keep-going : false ; " > ~/user-config.jam

RUN cd ${WORKSPACE}/boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=${WORKSPACE}/boost  --with-libraries=serialization,thread,system,date_time,filesystem,regex,chrono,program_options \
    && ./b2 toolset=gcc-arm link=static install

#INSTALL cmake
# don't use 3.7 : https://github.com/android-ndk/ndk/issues/254
ENV CMAKE_VERSION 3.6.3
RUN cd ${WORKSPACE} \
    && wget -q https://cmake.org/files/v3.6/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && tar -xvzf ${WORKSPACE}/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && rm -f ${WORKSPACE}/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz
ENV PATH ${WORKSPACE}/cmake-${CMAKE_VERSION}-Linux-x86_64/bin:$PATH

RUN apt-get update && apt-get install -y automake curl file pkg-config 

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
RUN cd ${WORKSPACE} \
    && curl -O http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
    && tar -xzf zlib-${ZLIB_VERSION}.tar.gz \
    && rm zlib-${ZLIB_VERSION}.tar.gz \
    && mv zlib-${ZLIB_VERSION} zlib \
    && cd zlib && ./configure --static \
    && make

# open ssl
ENV CPPFLAGS -mthumb -mfloat-abi=softfp -mfpu=vfp -march=$ARCH  -DANDROID
ENV OPENSSL_VERSION 1.0.2j
RUN cd ${WORKSPACE} \
    && curl -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && rm openssl-${OPENSSL_VERSION}.tar.gz \
    && cd ${WORKSPACE}/openssl-${OPENSSL_VERSION} \
    && sed -i -e "s/mandroid/target\ armv7\-none\-linux\-androideabi/" Configure \
    && ./Configure android-armv7 \
           no-asm \
           no-shared --static \
           --with-zlib-include=${WORKSPACE}/zlib/include --with-zlib-lib=${WORKSPACE}/zlib/lib \
    && make build_crypto build_ssl -j 4 \
    && cd ${WORKSPACE} && mv openssl-${OPENSSL_VERSION}  openssl


# Get iconv and ZBar
ENV ICONV_VERSION 1.14
RUN cd ${WORKSPACE} \
    && git clone https://github.com/ZBar/ZBar.git \
    && wget -q http://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICONV_VERSION}.tar.gz \
    && tar -xzf libiconv-${ICONV_VERSION}.tar.gz \
    && cd libiconv-${ICONV_VERSION} \
    && ./configure --build=x86_64-linux-gnu --host=arm-eabi --prefix=/usr/libiconv --disable-rpath 

#Build libiconv.a and libzbarjni.a
COPY android.mk.patch ${WORKSPACE}/ZBar/android.mk.patch
RUN cd ${WORKSPACE}/ZBar \
    && git apply android.mk.patch \
    && echo \
"APP_ABI := armeabi-v7a \n\
APP_STL := c++_shared \n\
TARGET_PLATFORM := ${ANDROID_API} \n\
TARGET_ARCH_ABI := armeabi-v7a \n\
APP_CFLAGS +=  -target armv7-none-linux-androideabi -fexceptions -fstack-protector-strong -fno-limit-debug-info -mfloat-abi=softfp -mfpu=vfp -fno-builtin-memmove -fno-omit-frame-pointer -fno-stack-protector\n"\
        >> ${WORKSPACE}/ZBar/android/jni/Application.mk \
    && cd ${WORKSPACE}/ZBar/android \
    && android update project --path . -t "${ANDROID_API}" \
    && ant -Dndk.dir=${ANDROID_NDK_ROOT} -Diconv.src=${WORKSPACE}/libiconv-${ICONV_VERSION} zbar-clean zbar-ndk-build

ENV PATH ${WORKSPACE}/Qt-${QT_VERSION}/bin:$PATH
RUN cd ${WORKSPACE} \
    && git clone https://github.com/monero-project/monero-core.git \
    && cd monero-core \
    && git clone https://github.com/monero-project/monero.git \
    && cd monero \
    && cd .. 
#    && ./get_libwallet_api.sh debug-android

#NB : don't know how to produce a clean environnement to just run get_libwallet_api.sh debug-android

RUN mkdir -p ${WORKSPACE}/monero-core/monero/build/release \
    && cd ${WORKSPACE}/monero-core/monero/build/release \
    && cmake -D CMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE -D STATIC=ON -D ARCH="armv7-a" -D ANDROID=true -D BUILD_GUI_DEPS=ON -D USE_LTO=OFF -D BUILD_TESTS=OFF -D BUILD_DOCUMENTATION=OFF -D INSTALL_VENDORED_LIBUNBOUND=ON \
           -D ATOMIC=/usr/toolchain-arm/arm-linux-androideabi/lib/armv7-a/libatomic.a \
           -D OPENSSL_USE_STATIC_LIBS=true -D OPENSSL_ROOT_DIR=/usr/openssl -D OPENSSL_INCLUDE_DIR=/usr/openssl/include \
           -D BOOST_IGNORE_SYSTEM_PATHS=ON \
           -D BOOST_ROOT=/usr/boost \
           -D CMAKE_INSTALL_PREFIX=${WORKSPACE}/monero-core/monero  ../.. \
    && cd ${WORKSPACE}/monero-core/monero/build/release/src/wallet \
    && make version -C ../.. \
    && make -j4 \
    && make install \
    && cd ${WORKSPACE}/monero-core/monero/build/release/external/unbound \
    && make install 

RUN cp ${WORKSPACE}/openssl/lib* ${WORKSPACE}/monero-core/monero/lib
RUN cp ${WORKSPACE}/boost/lib/lib* ${WORKSPACE}/monero-core/monero/lib

# NB : zxcvbn-c needs to build a local binary and Qt don't care about these environnement variable
RUN cd ${WORKSPACE}/monero-core \
    && CPPFLAGS="" CC="gcc" CXX="g++" AR="ar" AS="as" LD="ld" RANLIB="ranlib" NM="nm" STRIP="strip" CHOST="" ARCH="" ./build.sh debug-android \
    && cd build \
    && make deploy

