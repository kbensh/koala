FROM debian:12.7

WORKDIR /koala

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    wget \
    unzip \
    python3-pip \
    git \
    gpg

COPY . .
RUN chmod +x /koala/main.sh

ENV LC_ALL=C
ENV TC=UTC

# Fake sudo for install scripts — makes it a no-op
RUN printf '#!/bin/sh\nexec "$@"\n' > /tmp/sudo && chmod +x /tmp/sudo
ENV PATH="/tmp:$PATH"

RUN git config --global --add safe.directory /koala

RUN /koala/setup.sh

ARG BENCHMARK_INSTALLS="yes"

# Run install.sh for each benchmark
RUN  if [ "$BENCHMARK_INSTALLS" = "yes" ]; then \
    set -eux; \
    for bench in /koala/*; do \
        if [ -f "$bench/install.sh" ]; then \
            echo "Running install.sh in $bench"; \
            chmod +x "$bench/install.sh"; \
            bash "$bench/install.sh"; \
        fi; \
    done \
    fi

CMD ["bash"]
