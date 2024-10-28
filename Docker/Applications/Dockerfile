
FROM debian:bookworm

RUN apt update && apt install -y \
    ffmpeg \
    mesa-utils \
    mesa-utils-extra \
    x11-apps
COPY entrypoint /entrypoint
COPY sample.mp4 /sample.mp4
