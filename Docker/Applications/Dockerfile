
FROM mcr.microsoft.com/dotnet/sdk:8.0

RUN apt update && apt install -y \
    ffmpeg \
    mesa-utils \
    mesa-utils-extra \
    x11-apps

WORKDIR /Sources
COPY TcpTestApp/ .
RUN dotnet restore

RUN dotnet build \
    --self-contained \
    -c Release \
    -o /App
WORKDIR /
COPY entrypoint /entrypoint
COPY sample.mp4 /sample.mp4
