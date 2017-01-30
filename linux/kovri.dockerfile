FROM ubuntu
MAINTAINER MoroccanMalinois <MoroccanMalinois@protonmail.com>

RUN apt-get update && apt-get install -y git build-essential cmake libboost-all-dev miniupnpc libunbound-dev graphviz doxygen libunwind8-dev pkg-config libssl-dev
RUN cd /usr/local && git clone --recursive https://github.com/monero-project/kovri && cd kovri/ && make 

VOLUME /root/.kovri
CMD /usr/local/kovri/build/kovri

