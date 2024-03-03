ARG BASE_IMAGE=alpine
ARG BASE_IMAGE_VERSION=3.16
FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION}
RUN mkdir -p /opt/s0ck3t && \
    apk add libc6-compat tzdata
ARG TARGETOS
ARG TARGETARCH
COPY s0ck3t-*-*-* /opt/s0ck3t/
RUN ls -la /opt/s0ck3t/ && \
    chmod +x /opt/s0ck3t/s0ck3t_*_*-* && \
    ln -s /opt/s0ck3t/s0ck3t_*_${TARGETOS}-${TARGETARCH} /opt/s0ck3t/s0ck3t

ENTRYPOINT ["/opt/s0ck3t/s0ck3t"]
