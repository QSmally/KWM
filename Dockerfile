
FROM debian:bookworm AS compiler

ARG VERSION=0.11.0
ARG OPTIONS=-Doptimize=ReleaseSafe

RUN apt update && apt install -y \
    # Zig
    curl tar xz-utils \
    # DWM
    git libx11-dev libxft-dev libxinerama-dev libncurses-dev

# ziglang.org/download/<ver>/zig-<linux>-<architecture>-<ver>.tar.xz

RUN curl https://ziglang.org/download/$VERSION/zig-linux-$(uname -m)-$VERSION.tar.xz -O && \
    tar -xf *.tar.xz && \
    mv zig-linux-$(uname -m)-$VERSION /compiler

WORKDIR /build
COPY . /build
RUN /compiler/zig build $OPTIONS

FROM debian:bookworm AS output

RUN apt update && apt install -y \
    x11-xserver-utils \
    x11-utils \
    xauth \
    xinit \
    xinput \
    xserver-xorg \
    xserver-xorg-input-all \
    xserver-xorg-input-evdev \
    xserver-xorg-legacy \
    xserver-xorg-video-all \
    # debug
    xterm htop vim
COPY --from=compiler /build/zig-out/bin /bin
COPY Scripts/xinitrc /root/.xinitrc
COPY Scripts/entrypoint /root/entrypoint

ENV UDEV=on

VOLUME /tmp/.X11-unix
