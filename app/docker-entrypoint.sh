#!/bin/bash
set -e

# Generate dhparam file if required
# Note: if $DHPARAM_BITS is not defined, generate-dhparam.sh will use 2048 as a default
# Note2: if $DHPARAM_GENERATION is set to false in environment variable, dh param generator will skip completely
/app/generate-dhparam.sh $DHPARAM_BITS $DHPARAM_GENERATION

# Compute the DNS resolvers for use in the templates - if the IP contains ":", it's IPv6 and must be enclosed in []
export RESOLVERS=$(awk '$1 == "nameserver" {print ($2 ~ ":")? "["$2"]": $2}' ORS=' ' /etc/resolv.conf | sed 's/ *$//g')
if [ "x$RESOLVERS" = "x" ]; then
    echo "Warning: unable to determine DNS resolvers for nginx" >&2
    unset RESOLVERS
fi

exec "$@"
