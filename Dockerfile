FROM jwilder/nginx-proxy

ARG VERSION
ENV VERSION $VERSION

ADD nginx.tmpl /app/nginx.tmpl
ADD extra.conf /etc/nginx/extra.conf