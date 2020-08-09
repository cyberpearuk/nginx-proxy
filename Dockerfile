FROM nginx:1.17.8

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

ARG DOCKER_GEN_VERSION=0.7.4
# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf \
    # Install Forego
    && wget -O /usr/local/bin/forego https://github.com/jwilder/forego/releases/download/v0.16.1/forego \
    && chmod u+x /usr/local/bin/forego \
    # Install docker-gen
    && wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

COPY network_internal.conf /etc/nginx/

WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]

COPY usr/bin/* /usr/bin/

ARG NGINX_MODSEC_VERSION=v3/master
RUN install-modsec
ADD app /app

# Install rules
RUN mkdir /etc/nginx/modsec \
    && wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
    && mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf \
    && sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf \
    && sed -i 's/SecRuleEngine Reject/SecRequestBodyLimitAction ProcessPartial/' /etc/nginx/modsec/modsecurity.conf \
    # Workaround for issue https://github.com/SpiderLabs/ModSecurity/issues/1941
    && mv /tmp/unicode.mapping /etc/nginx/modsec/unicode.mapping

# Install OWASP Rules
ARG OWASP_RULES_VERSION=3.0.2
RUN wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_RULES_VERSION}.tar.gz \
    && tar -xzvf v${OWASP_RULES_VERSION}.tar.gz \
    && rm v${OWASP_RULES_VERSION}.tar.gz \
    && mv owasp-modsecurity-crs-${OWASP_RULES_VERSION} /usr/local/owasp-modsecurity-crs \
    && cd /usr/local/owasp-modsecurity-crs \
    && cp crs-setup.conf.example crs-setup.conf


# Configure Traditional Mode - https://www.modsecurity.org/CRS/Documentation/anomaly.html
RUN sed -i 's/SecDefaultAction "phase:2,log,auditlog,pass"/SecDefaultAction "phase:2,deny,status:403,log"/' /usr/local/owasp-modsecurity-crs/crs-setup.conf \
    && echo "SecRequestBodyLimit 67108864" >>  /usr/local/owasp-modsecurity-crs/crs-setup.conf \
    && echo "SecPcreMatchLimit 150000" >>  /usr/local/owasp-modsecurity-crs/crs-setup.conf \
    && echo "SecPcreMatchLimitRecursion 150000" >>  /usr/local/owasp-modsecurity-crs/crs-setup.conf

ARG VERSION
ENV VERSION $VERSION

# Persist cache
VOLUME /var/cache/nginx

ADD nginx/conf.d/* /etc/nginx/conf.d/
ADD nginx/extra.d/* /etc/nginx/extra.d/
ADD nginx/modsec/* /etc/nginx/modsec/
ADD nginx/optional.d/* /etc/nginx/optional.d/

RUN nginx -t