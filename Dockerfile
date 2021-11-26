FROM ubuntu AS fetch-bins

# Install wget and install/updates certificates
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

ARG DOCKER_GEN_VERSION=0.8.0
# Install Forego
RUN wget -O /usr/bin/forego https://github.com/jwilder/forego/releases/download/v0.16.1/forego \
    && chmod u+x /usr/bin/forego \
    # Install docker-gen
    && wget https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && tar -C /usr/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
    && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

FROM nginx:1.19.10 as nginx-base

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    wget \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

COPY /usr/bin/install-modsec /usr/bin/

ARG NGINX_MODSEC_VERSION=v3.0.4
RUN install-modsec

# Install OWASP Rules
ARG OWASP_RULES_VERSION=3.3.1-rc1
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

# Copy utilities
COPY /opt/dhparam /opt/dhparam
RUN ln -s /opt/dhparam/generate-dhparam.sh /usr/bin/generate-dhparam 

# Copy entrypoint
COPY /usr/bin/docker-entrypoint  /usr/bin/docker-entrypoint
ENTRYPOINT ["/usr/bin/docker-entrypoint"]

RUN nginx -t

# Create image with docker-gen and foregot
FROM nginx-base as production

ADD app /app
WORKDIR /app/

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam", "/var/cache/nginx"]

# Add start script
COPY /usr/bin/start /usr/bin/

# Add docker-gen
COPY --from=fetch-bins /usr/bin/docker-gen /usr/bin/docker-gen
# Add forego (for running docker-gen and nginx together)
COPY --from=fetch-bins /usr/bin/forego /usr/bin/forego

ENV DOCKER_HOST unix:///tmp/docker.sock
CMD ["/usr/bin/start"]
