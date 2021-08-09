# https://github.com/l3tnun/docker-mirakurun-epgstation/blob/824246a/epgstation/Dockerfile
FROM node:16-buster-slim
EXPOSE 8888
ARG CPUCORE='4'
ENV DEV='automake curl wget autoconf libass-dev libfreetype6-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev vainfo pkg-config texinfo zlib1g-dev'
ENV FFMPEG_VERSION=4.3

RUN rm /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/debian-security buster/updates main contrib" >> /etc/apt/sources.list && \
    echo "deb-src http://security.debian.org/debian-security buster/updates main contrib" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get -y install $DEV && \
    apt-get -y install make git gcc g++ build-essential python3 yasm libx264-dev libmp3lame-dev libopus-dev && \
    apt-get -y install libasound2 libass9 libvdpau1 libva-x11-2 libva-drm2 libxcb-shm0 libxcb-xfixes0 libxcb-shape0 libvorbisenc2 libtheora0 libx265-dev libnuma-dev i965-va-driver-shaders

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
      --enable-libx265 \
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
    npm run all-install && \
    npm run build

VOLUME "/usr/local/EPGStation/config"
VOLUME "/usr/local/EPGStation/data"
VOLUME "/usr/local/EPGStation/thumbnail"
VOLUME "/usr/local/EPGStation/logs"
VOLUME "/usr/local/EPGStation/recorded"

WORKDIR /usr/local/EPGStation

CMD ["npm", "start"]
