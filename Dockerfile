
FROM alpine AS compiler

ARG VERSION=0.11.0
ARG PLATFORM=linux
ARG OPTIONS=-Doptimize=ReleaseSafe

RUN apk update && apk add \
    # Zig
    curl tar xz \
    # DWM
    git libx11-dev libxft-dev libxinerama-dev ncurses

# ziglang.org/download/<ver>/zig-<linux>-<architecture>-<ver>.tar.xz

RUN curl https://ziglang.org/download/$VERSION/zig-$PLATFORM-$(uname -m)-$VERSION.tar.xz -O && \
    tar -xf *.tar.xz && \
    mv zig-$PLATFORM-$(uname -m)-$VERSION /compiler

WORKDIR /build
COPY . /build
RUN /compiler/zig build $OPTIONS

FROM alpine AS output

RUN apk update && apk add xinit
COPY --from=compiler /build/zig-out/bin /bin
VOLUME /tmp/.X11-unix
