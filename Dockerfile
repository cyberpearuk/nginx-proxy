FROM jwilder/nginx-proxy

ARG VERSION
ENV VERSION $VERSION

ADD nginx.tmpl /app/nginx.tmpl
ADD optional.d /etc/nginx/optional.d
ADD extra.conf /etc/nginx/conf.d/