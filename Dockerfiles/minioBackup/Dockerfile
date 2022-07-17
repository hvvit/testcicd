FROM ubuntu
RUN apt update -y && apt install wget -y && wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod a+x mc && mv mc /usr/bin/
RUN apt install -y curl zip bash && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip ./aws &&  ln -svf /usr/local/bin/aws /usr/bin/aws && aws --version
WORKDIR /opt/backup/
COPY ops.sh .
RUN chmod +x ops.sh