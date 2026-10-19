# Verified upstream multi-platform digest; the first supported server is amd64.
FROM python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d
# Godot's headless Linux template and the tested relay/codec need only this base's libc.
RUN groupadd --gid 10001 worldrise && useradd --uid 10001 --gid 10001 --no-create-home worldrise \
    && mkdir /data && chown 10001:10001 /data
ARG SERVER_VERSION=0.42.0
LABEL org.opencontainers.image.title="World Rise Dedicated Server" \
    org.opencontainers.image.version="${SERVER_VERSION}" io.worldrise.engine.version="4.5.1"
COPY output/linux-server/v${SERVER_VERSION}/ /app/
COPY hosting/supervise.py hosting/admin.py /app/
ENV WORLD_RISE_DURABLE_HELPER=/app/durable_replace.py WORLD_RISE_PYTHON=/usr/local/bin/python3 \
    HOME=/tmp XDG_DATA_HOME=/tmp/data XDG_CONFIG_HOME=/tmp/config XDG_CACHE_HOME=/tmp/cache \
    WORLD_RISE_DATA_DIR=/data WORLD_RISE_PASSWORD_FILE=/run/secrets/server_password
WORKDIR /app
USER 10001:10001
EXPOSE 24571/udp 24572/udp
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 CMD ["python3", "/app/supervise.py", "--health"]
ENTRYPOINT ["python3", "/app/supervise.py"]
