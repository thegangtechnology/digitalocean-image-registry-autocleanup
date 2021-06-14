FROM digitalocean/doctl:1.61.0

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN mv doctl /usr/local/bin/doctl

COPY script.sh script.sh 
RUN chmod +x script.sh
USER root:root

ENTRYPOINT ["/bin/bash"]
CMD ["./script.sh"]