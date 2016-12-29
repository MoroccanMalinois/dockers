FROM ubuntu
MAINTAINER MoroccanMalinois@protonmail.com

# start with :
# docker run -it -e DISPLAY=$DISPLAY -v /tmp/.x11-unix:/tmp/.X11-unix monero-wallet-gui

RUN apt-get update && apt-get install -y git build-essential cmake libboost-all-dev miniupnpc libunbound-dev graphviz doxygen libunwind8-dev pkg-config libssl-dev
RUN apt-get install -y qtbase5-dev qt5-default qtdeclarative5-dev qml-module-qtquick-controls qml-module-qtquick-xmllistmodel qttools5-dev-tools qml-module-qtquick-dialogs
RUN apt-get install -y libqt5qml-graphicaleffects qml-module-qt-labs-settings
RUN cd /usr/local && git clone https://github.com/monero-project/monero-core.git && cd monero-core && ./build.sh

VOLUME /root/Monero
CMD /usr/local/monero-core/build/release/bin/monero-wallet-gui

