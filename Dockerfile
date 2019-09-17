# https://github.com/l3tnun/docker-mirakurun-epgstation/blob/824246a/epgstation/Dockerfile
FROM debian:stretch-slim
EXPOSE 8888
ARG CPUCORE='4'
ENV DEV='automake curl wget autoconf libass-dev libfreetype6-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev vainfo pkg-config texinfo zlib1g-dev'
ENV FFMPEG_VERSION=3.4.6

RUN apt-get update && \
    apt-get -y install $DEV && \
    apt-get -y install make git gcc g++ build-essential python2.7 yasm libx264-dev libmp3lame-dev libopus-dev && \
    apt-get -y install libasound2 libass5 libvdpau1 libva-x11-1 libva-drm1 libxcb-shm0 libxcb-xfixes0 libxcb-shape0 libvorbisenc2 libtheora0

#ffmpeg build
RUN mkdir /tmp/ffmpeg_sources && \
    cd /tmp/ffmpeg_sources && \
    wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 -O ffmpeg.tar.bz2 && \
    tar xjvf ffmpeg.tar.bz2 && \
    cd /tmp/ffmpeg_sources/ffmpeg* && \
    ./configure \
      --prefix=/usr/local \
      --disable-shared \
      --pkg-config-flags=--static \
      --enable-gpl \
      --enable-vaapi \
      --enable-libass \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libtheora \
      --enable-libvorbis \
      --enable-libx264 \
      --enable-nonfree \
      --disable-debug \
      --disable-doc \
    && \
    cd /tmp/ffmpeg_sources/ffmpeg* && \
    make -j${CPUCORE} && \
    make install

# comskip
RUN echo "deb http://deb.debian.org/debian stretch main" >> /etc/apt/sources.list
RUN echo "deb-src http://deb.debian.org/debian stretch main" >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y \
    libargtable2-dev \
    libavutil-dev \
    libavformat-dev \
    libavcodec-dev
ADD https://api.github.com/repos/erikkaashoek/Comskip/git/refs/heads/master comskip-version.json
RUN git clone --depth 1 https://github.com/erikkaashoek/Comskip.git /tmp/Comskip
RUN cd /tmp/Comskip && ./autogen.sh && ./configure && make -j ${CPUCORE} && make install

# nodejs install
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y nodejs

# 不要なパッケージを削除
RUN apt-get -y remove $DEV && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/ffmpeg_sources && \
    rm -rf /tmp/Comskip

# install EPGStation
# Prevent git clone cache https://stackoverflow.com/a/39278224
ADD https://api.github.com/repos/l3tnun/EPGStation/git/refs/heads/master epgstation-version.json
RUN cd /usr/local/ && \
    git clone --depth 1 https://github.com/l3tnun/EPGStation.git && \
    cd /usr/local/EPGStation && \
    npm install && \
    npm run build

VOLUME "/usr/local/EPGStation/config"
VOLUME "/usr/local/EPGStation/data"
VOLUME "/usr/local/EPGStation/thumbnail"
VOLUME "/usr/local/EPGStation/logs"
VOLUME "/usr/local/EPGStation/recorded"

WORKDIR /usr/local/EPGStation

CMD ["npm", "start"]
