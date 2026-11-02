ARG EPGSTATION_VERSION=v3.0.0-beta4
# v3はNode.jsのネイティブモジュールを含むため、公式イメージのNode.jsとglibcも引き継ぐ。
FROM l3tnun/epgstation:${EPGSTATION_VERSION}@sha256:86cb8ad9d8b38bae2fc0e5b451f7d9ef2e38d618d4b916de45b84ab0459e8518 AS upstream

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
        ca-certificates curl ffmpeg i965-va-driver-shaders libargtable2-0 \
        python3 vainfo wget && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/ffmpeg /usr/local/bin/ffmpeg && \
    ln -s /usr/bin/ffprobe /usr/local/bin/ffprobe

COPY --from=comskip-builder /usr/local/bin/comskip /usr/local/bin/comskip

WORKDIR /app
EXPOSE 8888
ENTRYPOINT []
CMD ["npm", "start"]
