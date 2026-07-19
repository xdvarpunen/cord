FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 22.04 dropped the native "chromium" apt package (snap-only now, which
# doesn't work in containers), so install Google Chrome's .deb directly.
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"
ENV CHROME_EXECUTABLE=/usr/bin/google-chrome-stable

RUN git clone --branch stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    && chown -R vscode:vscode "$FLUTTER_HOME"

USER vscode

RUN flutter config --enable-web --no-analytics \
    && flutter precache --web \
    && flutter doctor
