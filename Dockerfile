FROM ghcr.io/acmesh-official/acme.sh:3.1.6

COPY entry-override.sh /entry-override.sh
RUN chmod +x /entry-override.sh

ENTRYPOINT ["/entry-override.sh"]
