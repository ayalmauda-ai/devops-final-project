FROM jenkins/jenkins:lts

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl unzip gnupg lsb-release ca-certificates \
        software-properties-common python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LO "https://dl.k8s.io/release/v1.30.4/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -LO "https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip" && \
    unzip terraform_1.9.5_linux_amd64.zip && \
    mv terraform /usr/local/bin/terraform && \
    rm terraform_1.9.5_linux_amd64.zip

RUN pip3 install --no-cache-dir --break-system-packages ansible==9.5.1

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

USER jenkins

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
