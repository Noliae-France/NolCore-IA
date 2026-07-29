FROM ubuntu:24.04 AS build
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tar clang libssl-dev && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /tmp/nolc && curl -fsSL https://noliae-nolc.s3.gra.io.cloud.ovh.net/nolc-latest-linux-x86_64.tar.gz | tar -xzf - --strip-components=1 -C /tmp/nolc
# Le service IA utilise les deux formes d'import héritées : ../nolc/lib/* et
# vendor/nolc/lib/*. Conserver les deux chemins dans l'image de compilation.
COPY vendor/nolc/lib /nolc/lib
COPY vendor/nolc/lib /app/vendor/nolc/lib
COPY *.nol /app/
WORKDIR /app
RUN install -m 0755 /tmp/nolc/nolc /usr/local/bin/nolc && nolc build main.nol -o nolcore --lien ssl --lien crypto --chemin-lib /usr/lib/x86_64-linux-gnu
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends libssl3 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --system --uid 10001 nolcore
COPY --from=build /app/nolcore /app/nolcore
USER 10001:10001
EXPOSE 8092
CMD ["/app/nolcore"]
