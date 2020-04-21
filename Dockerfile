FROM jwilder/nginx-proxy

RUN apt-get update && apt-get install -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev

RUN git clone --recursive --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity \
  && cd ModSecurity \
  && git submodule init \
  && git submodule update \
  && ./build.sh \
  && ./configure \
  && make \
  && make install
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

ENV NGINX_VERSION=1.17.5
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

ENV OWASP_RULES_VERSION=3.0.2
# Install OWASP Rules
RUN wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_RULES_VERSION}.tar.gz \
    && tar -xzvf v${OWASP_RULES_VERSION}.tar.gz \
    && mv owasp-modsecurity-crs-${OWASP_RULES_VERSION} /usr/local/owasp-modsecurity-crs \
    && cd /usr/local/owasp-modsecurity-crs \
    && cp crs-setup.conf.example crs-setup.conf

ARG VERSION
ENV VERSION $VERSION

ADD nginx.tmpl /app/nginx.tmpl

ADD modsec/* /etc/nginx/modsec/
ADD optional.d/* /etc/nginx/optional.d/
ADD extra.d/* /etc/nginx/extra.d/
ADD conf.d/* /etc/nginx/conf.d/