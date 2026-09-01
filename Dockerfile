FROM ghcr.io/acmesh-official/acme.sh:3.1.4

COPY entry-override.sh /entry-override.sh

ENTRYPOINT ["/entry-override.sh"]
