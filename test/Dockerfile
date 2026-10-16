FROM docker:27-dind
# sops/age are deliberately NOT installed: install-tools.sh must do that.
RUN apk add --no-cache bash git curl openssh-client openssh-keygen util-linux
COPY entrypoint.sh scenario.sh /test/
RUN chmod +x /test/*.sh
ENTRYPOINT ["/test/entrypoint.sh"]
