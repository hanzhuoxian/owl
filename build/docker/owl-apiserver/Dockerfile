FROM BASE_IMAGE
LABEL maintainer="<hanzhuoxian@outlook.com>"

WORKDIR /opt/owl

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
      echo "Asia/Shanghai" > /etc/timezone && \
      mkdir -p /var/log/owl

COPY owl-apiserver /opt/owl/bin/

ENTRYPOINT ["/opt/owl/bin/owl-apiserver"]
CMD ["-c", "/etc/owl/owl-apiserver.yaml"]