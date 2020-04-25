FROM jwilder/nginx-proxy:latest

RUN apt-get update && apt-get install -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev

ENV NGINX_MODSEC_VERSION=v3/master
RUN git clone --recursive --depth 1 -b ${NGINX_MODSEC_VERSION} --single-branch https://github.com/SpiderLabs/ModSecurity \
  && cd ModSecurity \
  && git submodule init \
  && git submodule update \
  && ./build.sh \
  && ./configure \
  && make \
  && make install
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar zxvf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx \
    && make modules \
    && cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules

# Enable module
RUN sed -i -e 's/user  nginx;/load_module modules\/ngx_http_modsecurity_module.so;\nuser  nginx;/' /etc/nginx/nginx.conf

# Install rules
RUN mkdir /etc/nginx/modsec \
    && wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
    && mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf \
    && sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf

# Workaround for issue https://github.com/SpiderLabs/ModSecurity/issues/1941
RUN cp ./ModSecurity/unicode.mapping /etc/nginx/modsec/unicode.mapping

ENV OWASP_RULES_VERSION=v3.0/master
# Install OWASP Rules
#RUN git clone --recursive --depth 1 -b ${OWASP_RULES_VERSION} --single-branch https://github.com/SpiderLabs/owasp-modsecurity-crs \
    #&& wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_RULES_VERSION}.tar.gz \
    #&& tar -xzvf v${OWASP_RULES_VERSION}.tar.gz \
    #&& mv owasp-modsecurity-crs-${OWASP_RULES_VERSION} /usr/local/owasp-modsecurity-crs \

ENV OWASP_RULES_VERSION=3.0.2
RUN wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_RULES_VERSION}.tar.gz \
    && tar -xzvf v${OWASP_RULES_VERSION}.tar.gz \
    && mv owasp-modsecurity-crs-${OWASP_RULES_VERSION} /usr/local/owasp-modsecurity-crs \
    && cd /usr/local/owasp-modsecurity-crs \
    && cp crs-setup.conf.example crs-setup.conf


# Configure Traditional Mode - https://www.modsecurity.org/CRS/Documentation/anomaly.html
RUN sed -i 's/SecDefaultAction "phase:2,log,auditlog,pass"/SecDefaultAction "phase:2,deny,status:403,log"/' /usr/local/owasp-modsecurity-crs/crs-setup.conf \
    && echo "SecPcreMatchLimit 150000" >>  /usr/local/owasp-modsecurity-crs/crs-setup.conf \
    && echo "SecPcreMatchLimitRecursion 150000" >>  /usr/local/owasp-modsecurity-crs/crs-setup.conf

ARG VERSION
ENV VERSION $VERSION

ADD nginx.tmpl /app/nginx.tmpl

ADD modsec/* /etc/nginx/modsec/
ADD optional.d/* /etc/nginx/optional.d/
ADD extra.d/* /etc/nginx/extra.d/
ADD conf.d/* /etc/nginx/conf.d/

RUN nginx -t