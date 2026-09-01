FROM ghcr.io/acmesh-official/acme.sh:3.1.4

# Overwrite the entry.sh
COPY entry.sh /entry.sh

ENTRYPOINT ["/entry.sh"]
CMD ["daemon"]
