FROM swift:6.4.2@sha256:0384f00cf80f81064a907c249a0ad56a1648906f65075a95b1827e88de666e21
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake ninja-build pkg-config patchelf libibus-1.0-dev ibus ibus-gtk3 libgtk-3-dev \
    libfcitx5core-dev libfcitx5config-dev fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-qt5 qtbase5-dev \
    dbus-x11 xvfb xdotool x11-utils openbox python3 python3-gi gir1.2-IBus-1.0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
RUN apt-get update && apt-get install -y --no-install-recommends fonts-dejavu-core && rm -rf /var/lib/apt/lists/*
