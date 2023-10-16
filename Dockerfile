FROM postgres:15.4-bullseye
# Set the pgvector version
ARG PGVECTOR_VERSION=0.5.0

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
        curl \
        postgresql-server-dev-15

# Download and extract the pgvector release, build the extension, and install it.
RUN curl -f -L -o pgvector.tar.gz "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" && \
    tar -xzf pgvector.tar.gz && \
    cd "pgvector-${PGVECTOR_VERSION}" && \
    make OPTFLAGS="" && \
    make install && \
    mkdir /usr/share/doc/pgvector && \
    cp LICENSE README.md /usr/share/doc/pgvector


# Clean up build dependencies and temporary files
RUN apt-get remove -y build-essential curl postgresql-server-dev-15 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /pgvector.tar.gz /pgvector-${PGVECTOR_VERSION}


FROM golang:1.21.2-bookworm AS BUILD
LABEL authors="danielchalef"

RUN mkdir /app
WORKDIR /app
COPY . .
RUN go mod download && make build

FROM debian:bookworm-slim AS RUNTIME
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=BUILD /app/out/bin/zep /app/
# Ship with default config that can be overridden by ENV vars
COPY config.yaml /app/
COPY cloud_start.sh /app/

RUN chmod +x /app/cloud_start.sh

EXPOSE 8000
ENTRYPOINT ["/app/cloud_start.sh"]
