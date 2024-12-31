FROM debian:bookworm-slim AS base

# Set environment variables
ENV UMS_HOME /opt/ums
ENV UMS_COMMIT d2384fb

# Create the UMS directory
WORKDIR $UMS_HOME

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    wget \
    gnupg2 \
    git \
    openjdk-17-jre-headless \
    ffmpeg \
    mediainfo \
    procps \
    iputils-ping \
    && wget https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb \
    && dpkg -i deb-multimedia-keyring_2024.9.1_all.deb \
    && rm deb-multimedia-keyring_2024.9.1_all.deb \
    && echo "deb http://www.deb-multimedia.org $(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2) main" > /etc/apt/sources.list.d/deb-multimedia.list \
    && apt-get update && apt-get install tsmuxer \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

from base AS build
RUN apt-get update && apt-get install -y \
    maven \
    && git clone https://github.com/UniversalMediaServer/UniversalMediaServer.git . \
    && git checkout $UMS_COMMIT \
    && mvn clean install -Dmaven.test.skip=true \
    && rm -rf $UMS_HOME/src/main/external-resources/windows

# Stage 3: Runtime environment
FROM base AS runtime

COPY --from=build $UMS_HOME/src/main/external-resources $UMS_HOME/src/main/external-resources
COPY --from=build $UMS_HOME/target/ums.jar $UMS_HOME/ums.jar

RUN mkdir -p $UMS_HOME/linux \
    && ln -s /bin/tsmuxer $UMS_HOME/linux/tsMuxeR

# Copy the docker-init script
COPY ./docker-init $UMS_HOME

# Ensure the script is executable
RUN chmod +x $UMS_HOME/docker-init

# Set the entrypoint
ENTRYPOINT $UMS_HOME/docker-init
