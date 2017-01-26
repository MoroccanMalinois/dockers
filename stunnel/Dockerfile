FROM debian:jessie
MAINTAINER MoroccanMalinois <MoroccanMalinois@protonmail.com>

#Just scripting http://pki-tutorial.readthedocs.io/en/latest/advanced/index.html
RUN apt-get update && apt-get install -y stunnel openssl git vim
ENV bla bla
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/stunnel", "/usr/stunnel.conf"]

