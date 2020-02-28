FROM jwilder/nginx-proxy

ADD nginx.tmpl /app/nginx.tmpl
ADD extra.conf /etc/nginx/extra.conf