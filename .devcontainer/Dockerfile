# [Choice] Debian / Ubuntu version (use Debian 11/9, Ubuntu 18.04/21.04 on local arm64/Apple Silicon): debian-11, debian-10, debian-9, ubuntu-21.04, ubuntu-20.04, ubuntu-18.04
ARG VARIANT=${VARIANT:-bookworm}
FROM mcr.microsoft.com/vscode/devcontainers/go:${VARIANT}

# Below is how you set the image attribution; this replaces the old AUTHOR directive
# TODO: maybe pick these up via variables?

# date and time on which the artifact was built, conforming to RFC 3339.
# This is made by the builder
#LABEL org.opencontainers.artifact.created '2023-03-22T21:41:44.399Z'
# human readable description for the artifact (string)
LABEL org.opencontainers.artifact.description 'Development container for s0ck3t'
# date and time on which the image was built, conforming to RFC 3339.
# This is made by the builder
#LABEL org.opencontainers.image.created '2023-03-22T21:41:44.399Z'
# contact details of the people or organization responsible for the image (freeform string)
LABEL org.opencontainers.image.authors 'Xcape, Inc. <support@xcapeinc.com>'
# URL to find more information on the image (string)
LABEL org.opencontainers.image.url 'https://github.com/xcape-inc/s0ck3t'
# URL to get documentation on the image (string)
LABEL org.opencontainers.image.documentation 'https://github.com/xcape-inc/s0ck3t'
# URL to get source code for building the image (string)
LABEL org.opencontainers.image.source 'https://github.com/xcape-inc/s0ck3t.git'
# version of the packaged software
# The version MAY match a label or tag in the source code repository
# version MAY be Semantic versioning-compatible
# Set by the builder
# LABEL org.opencontainers.image.version 'main'
# Source control revision identifier for the packaged software.
# Set by the builder
#LABEL org.opencontainers.image.revision '867543254567843'
# Name of the distributing entity, organization or individual.
LABEL org.opencontainers.image.vendor 'Xcape, Inc.'
# License(s) under which contained software is distributed as an SPDX License Expression.
LABEL org.opencontainers.image.licenses 'MIT-0'
# Name of the reference for a target (string).
# SHOULD only be considered valid when on descriptors on index.json within image layout.
# Character set of the value SHOULD conform to alphanum of A-Za-z0-9 and separator set of -._:@/+
# The reference must match the following grammar:
# ref       ::= component ("/" component)*
# component ::= alphanum (separator alphanum)*
# alphanum  ::= [A-Za-z0-9]+
# separator ::= [-._:@+] | "--"
# set by the builder
# LABEL org.opencontainers.image.ref.name 'refs/heads/main'
# Human-readable title of the image (string)
LABEL org.opencontainers.image.title 's0ck3t devcontainer'
# Human-readable description of the software packaged in the image (string)
LABEL org.opencontainers.image.description 'Development container for s0ck3t'
# Digest of the image this image is based on (string)
# This SHOULD be the immediate image sharing zero-indexed layers with the image, such as from a Dockerfile FROM statement.
# This SHOULD NOT reference any other images used to generate the contents of the image (e.g., multi-stage Dockerfile builds).
# Note: this was captured on original image creation; it WILL change
#LABEL org.opencontainers.image.base.digest 'sha256:67211c14fa74f070d27cc59d69a7fa9aeff8e28ea118ef3babc295a0428a6d21'
# Image reference of the image this image is based on (string)
# This SHOULD be image references in the format defined by distribution/distribution.
# This SHOULD be a fully qualified reference name, without any assumed default registry. (e.g., registry.example.com/my-org/my-image:tag instead of my-org/my-image:tag).
# This SHOULD be the immediate image sharing zero-indexed layers with the image, such as from a Dockerfile FROM statement.
# This SHOULD NOT reference any other images used to generate the contents of the image (e.g., multi-stage Dockerfile builds).
# If the image.base.name annotation is specified, the image.base.digest annotation SHOULD be the digest of the manifest referenced by the image.ref.name annotation.
LABEL org.opencontainers.image.base.name 'mcr.microsoft.com/vscode/devcontainers/base:bullseye'

# [Option] Enable non-root Docker access in container
ARG ENABLE_NONROOT_DOCKER="true"
# [Option] Use the OSS Moby CLI instead of the licensed Docker CLI
ARG USE_MOBY="true"
# [Option] Select CLI version
ARG CLI_VERSION="latest"

# Enable new "BUILDKIT" mode for Docker CLI
ENV DOCKER_BUILDKIT=1

# [Choice] Node.js version: none, lts/*, 18, 16, 14
ARG NODE_VERSION="none"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

COPY library-scripts/docker-debian.sh /tmp/library-scripts/
# [Option] Install Docker CLI
ARG INSTALL_DOCKER="true"
RUN if [ "${INSTALL_DOCKER}" = "true" ]; then \
        /bin/bash /tmp/library-scripts/docker-debian.sh "${ENABLE_NONROOT_DOCKER}" "/var/run/docker-host.sock" "/var/run/docker.sock" "${USERNAME}" "${USE_MOBY}" "${CLI_VERSION}"; \
    else \
        echo '#!/bin/bash\n"$@"' > /usr/local/share/docker-init.sh && chmod +x /usr/local/share/docker-init.sh; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends file \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# [Optional] Uncomment the next lines to use go get to install anything else you need
COPY --chown=vscode:vscode go.mod go.sum /tmp/modulesrc/
USER vscode
RUN cd /tmp/modulesrc && \
    ls -la && \
    go get -u ./... && \
    rm -rf /tmp/modulesrc

# This goes just before thersion tagger
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

USER root

# Work around for https://github.com/actions/checkout/issues/956 so this container can be used in github ci
RUN mkdir -m 1777 /__w

ARG VERSION=unset
ARG LONG_FORM_VERSION=unset

RUN (printf 's0ck3t devcontainer' > /etc/opencontainers_image_title) && \
    (printf '%s' "${VERSION}" > /etc/opencontainers_image_version) && \
    (printf '%s' "${LONG_FORM_VERSION}" > /etc/opencontainers_image_version_long)
USER vscode
