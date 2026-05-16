ARG VERSION=1.0.0

FROM ubuntu:22.04

ARG VERSION
LABEL version="${VERSION}" \
      maintainer="ayalmauda-ai" \
      description="Seyoawe automation engine"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libssl3 \
        git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY engine/seyoawe.linux   ./seyoawe.linux
COPY engine/run.sh          ./run.sh
COPY engine/modules/        ./modules/
COPY engine/workflows/      ./workflows/
COPY engine/configuration/  ./configuration/

RUN chmod +x seyoawe.linux run.sh

CMD ["./run.sh", "linux"]
