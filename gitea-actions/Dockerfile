FROM vegardit/gitea-act-runner:dind-rootless-0.2.6

USER root

RUN useradd --uid 1001 --create-home --shell /bin/bash runner && \
    usermod -aG docker runner && \
    chown -R 1001:1001 /data/.docker

USER runner
