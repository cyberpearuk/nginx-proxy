FROM ubuntu AS fetch-bins

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

ARG DOCKER_GEN_VERSION=0.7.4
# Install Forego
RUN wget -O /usr/local/bin/forego https://github.com/jwilder/forego/releases/download/v0.16.1/forego \
    && chmod u+x /usr/local/bin/forego \
    # Install docker-gen
    && wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

FROM nginx:1.17.8

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*


COPY usr/bin/* /usr/bin/

ARG NGINX_MODSEC_VERSION=v3/master
RUN install-modsec

# Install rules
RUN mkdir /etc/nginx/modsec \
    && wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
    && mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf \
    && sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf \
    && sed -i 's/SecRuleEngine Reject/SecRequestBodyLimitAction ProcessPartial/' /etc/nginx/modsec/modsecurity.conf \
    # Workaround for issue https://github.com/SpiderLabs/ModSecurity/issues/1941
    && mv /tmp/unicode.mapping /etc/nginx/modsec/unicode.mapping

# Install OWASP Rules
ARG OWASP_RULES_VERSION=3.3.0
RUN wget https://github.com/coreruleset/coreruleset/archive/v${OWASP_RULES_VERSION}.tar.gz \
    && tar -xzvf v${OWASP_RULES_VERSION}.tar.gz \
    && rm v${OWASP_RULES_VERSION}.tar.gz \
    && mv coreruleset-${OWASP_RULES_VERSION} /usr/local/coreruleset \
    && cd /usr/local/coreruleset \
    && cp crs-setup.conf.example crs-setup.conf


# Configure Traditional Mode - https://www.modsecurity.org/CRS/Documentation/anomaly.html
RUN sed -i 's/SecDefaultAction "phase:2,log,auditlog,pass"/SecDefaultAction "phase:2,deny,status:403,log"/' /usr/local/coreruleset/crs-setup.conf \
    && echo "SecRequestBodyLimit 67108864" >>  /usr/local/coreruleset/crs-setup.conf \
    && echo "SecPcreMatchLimit 150000" >>  /usr/local/coreruleset/crs-setup.conf \
    && echo "SecPcreMatchLimitRecursion 150000" >>  /usr/local/coreruleset/crs-setup.conf

# Set image version
ARG VERSION
ENV VERSION $VERSION

# Persist cache data
VOLUME /var/cache/nginx

# Add configuration files
# TODO: The conf.d volume can get mounted, better to use an alternative 
ADD nginx/conf.d/* /etc/nginx/conf.d/
ADD nginx/server.d/* /etc/nginx/server.d/
ADD nginx/modsec/* /etc/nginx/modsec/
ADD nginx/optional.d/* /etc/nginx/optional.d/

# Configure Nginx and apply fix for very long server names
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

COPY network_internal.conf /etc/nginx/



VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

# Add docker-gen
COPY --from=fetch-bins /usr/local/bin/docker-gen /usr/local/bin/docker-gen
# Add forego (for running docker-gen and nginx together)
COPY --from=fetch-bins /usr/local/bin/forego /usr/local/bin/forego

ENV DOCKER_HOST unix:///tmp/docker.sock
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
ADD app /app
WORKDIR /app/


RUN nginx -t