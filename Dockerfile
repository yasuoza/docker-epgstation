ARG EPGSTATION_VERSION=v3.0.0-beta4
# v3はNode.jsのネイティブモジュールを含むため、公式イメージのNode.jsとglibcも引き継ぐ。
FROM l3tnun/epgstation:${EPGSTATION_VERSION}@sha256:86cb8ad9d8b38bae2fc0e5b451f7d9ef2e38d618d4b916de45b84ab0459e8518 AS upstream

FROM upstream AS kodi-ffmpeg-builder
ARG CPUCORE=4
# libaribcaption v1.1.2
ARG LIBARIBCAPTION_REV=c64c23b8905ba514b87c9789269e9f66f949ffe0
ARG FFMPEG_KODI_VERSION=7.1.5
ARG FFMPEG_KODI_SHA256=de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake curl git libdrm-dev libfontconfig1-dev \
        libfreetype-dev libva-dev libx264-dev nasm pkg-config xz-utils && \
    rm -rf /var/lib/apt/lists/*
RUN git init /build/libaribcaption && \
    git -C /build/libaribcaption remote add origin https://github.com/xqq/libaribcaption.git && \
    git -C /build/libaribcaption fetch --depth 1 origin "${LIBARIBCAPTION_REV}" && \
    git -C /build/libaribcaption checkout --detach FETCH_HEAD && \
    cmake -S /build/libaribcaption -B /build/libaribcaption/build \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/kodi \
        -DCMAKE_INSTALL_LIBDIR=lib -DARIBCC_SHARED_LIBRARY=OFF && \
    cmake --build /build/libaribcaption/build -j"${CPUCORE}" && \
    cmake --install /build/libaribcaption/build
RUN curl -fSL --retry 3 --connect-timeout 15 \
        "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_KODI_VERSION}.tar.xz" -o /build/ffmpeg.tar.xz && \
    echo "${FFMPEG_KODI_SHA256}  /build/ffmpeg.tar.xz" | sha256sum -c - && \
    tar -xJf /build/ffmpeg.tar.xz -C /build
COPY scripts/build-kodi-ffmpeg.sh /build/build-kodi-ffmpeg.sh
RUN CPUCORE="${CPUCORE}" /bin/sh /build/build-kodi-ffmpeg.sh "/build/ffmpeg-${FFMPEG_KODI_VERSION}"
COPY patches/kodi-arib-dvb.patch /build/kodi-arib-dvb.patch
# ARIBの消去を伝え、終了時刻未定の字幕で未来の消去PTSやheartbeatのちらつきを生成しない。
# パッチ対象だけ再コンパイルし、修正時にも全codecをビルドし直さず検証できるようにする。
RUN cd "/build/ffmpeg-${FFMPEG_KODI_VERSION}" && git apply /build/kodi-arib-dvb.patch && \
    make -j"${CPUCORE}" && make install

FROM upstream AS comskip-builder
ARG CPUCORE=4
ARG COMSKIP_REV=a140b6ac8bc8f596729e9052819affc779c3b377

RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf automake build-essential ca-certificates git libargtable2-dev libavcodec-dev \
        libavformat-dev libavutil-dev libswscale-dev libtool pkg-config && \
    rm -rf /var/lib/apt/lists/*
RUN git init /tmp/Comskip && \
    git -C /tmp/Comskip remote add origin https://github.com/erikkaashoek/Comskip.git && \
    git -C /tmp/Comskip fetch --depth 1 origin "${COMSKIP_REV}" && \
    git -C /tmp/Comskip checkout --detach FETCH_HEAD
RUN cd /tmp/Comskip && ./autogen.sh && ./configure --disable-gui && \
    make -j"${CPUCORE}" && make install

FROM upstream
# DS718+のi965のエンコード用シェーダーはDebianのnon-freeに含まれる。
# インターレース解除は既存config.ymlのCPU yadif設定を引き続き使用する。
RUN sed -i 's/^Components: main$/Components: main contrib non-free/' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl ffmpeg fonts-noto-cjk i965-va-driver-shaders libargtable2-0 \
        python3 vainfo wget && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/ffmpeg /usr/local/bin/ffmpeg && \
    ln -s /usr/bin/ffprobe /usr/local/bin/ffprobe

COPY --from=comskip-builder /usr/local/bin/comskip /usr/local/bin/comskip
# Kodi用は内部FFmpegライブラリとlibaribcaptionを静的リンクし、配信・Comskip用のABIを保つ。
COPY --from=kodi-ffmpeg-builder /opt/kodi/bin/ffmpeg-kodi /usr/local/bin/ffmpeg-kodi

# aribb24.js 2.xが必要とする字幕管理情報をHLSのID3から欠落させない。
COPY patches/keep-caption-management.cjs /opt/epgstation-patches/keep-caption-management.cjs
RUN node /opt/epgstation-patches/keep-caption-management.cjs /app/node_modules/arib-subtitle-timedmetadater

WORKDIR /app
EXPOSE 8888
ENTRYPOINT []
CMD ["npm", "start"]
