FROM debian:jessie
MAINTAINER MoroccanMalinois <MoroccanMalinois@protonmail.com>

#INSTALL JAVA
RUN echo "deb http://ftp.fr.debian.org/debian/ jessie-backports main contrib" >> /etc/apt/sources.list
RUN dpkg --add-architecture i386 && apt-get update
RUN apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 libz1:i386 \
    openjdk-8-jdk-headless openjdk-8-jre-headless ant \
    libdbus-1-3 libglib2.0-0 unzip make python git build-essential wget
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$PATH

ENV WORKSPACE /usr

#INSTALL ANDROID SDK
#COPY android-sdk_r24.4.1-linux.tgz  ${WORKSPACE}/android-sdk_r24.4.1-linux.tgz
RUN cd ${WORKSPACE} \
    && wget http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
    && tar --no-same-owner -xzf android-sdk_r24.4.1-linux.tgz \
    && rm -f ${WORKSPACE}/android-sdk_r24.4.1-linux.tgz

ENV ANDROID_SDK_ROOT ${WORKSPACE}/android-sdk-linux
ENV PATH $PATH:$ANDROID_SDK_ROOT/tools
ENV PATH $PATH:$ANDROID_SDK_ROOT/platform-tools

#INSTALL ANDROID NDK
ENV ANDROID_NDK_REVISION 14-beta1
#COPY android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip ${WORKSPACE}/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip
RUN cd ${WORKSPACE} \
    && wget https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && unzip android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
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
    && make -j4


#ENV PATH ${WORKSPACE}/qt/5.7/android_armv7/bin:$PATH


