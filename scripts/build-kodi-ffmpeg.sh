#!/bin/sh
set -eu
cd "$1"

# TSのARIB字幕を画像として復号し、Kodiが選択できるDVB字幕として送る専用バイナリ。
# codecを明示し、ビルド環境の自動検出で配信機能が変わらないようにする。
# libx264はGPUを持たないビルド環境でも字幕変換を検証できるように含める。
PKG_CONFIG_PATH=/opt/kodi/lib/pkgconfig ./configure \
    --prefix=/opt/kodi --progs-suffix=-kodi \
    --disable-autodetect --disable-everything --disable-programs \
    --disable-doc --disable-debug --disable-shared --enable-static \
    --enable-ffmpeg --enable-gpl --enable-pthreads \
    --enable-libaribcaption --enable-libx264 --enable-vaapi --enable-libdrm \
    --pkg-config-flags=--static --extra-libs=-lstdc++ \
    --enable-protocol=file,pipe --disable-network \
    --enable-demuxer=mpegts --enable-muxer=mpegts \
    --enable-decoder=mpeg2video,aac,libaribcaption \
    --enable-encoder=h264_vaapi,libx264,aac,dvbsub \
    --enable-parser=mpegvideo,aac \
    --enable-filter=yadif,format,hwupload,scale_vaapi,scale,aformat,aresample,anull,null
make -j"${CPUCORE}"
make install
