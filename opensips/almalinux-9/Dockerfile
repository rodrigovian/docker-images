# Image
FROM almalinux:9

USER root

# If must write build log
# 0: disable
# 1: enable
# Log file: /var/log/docker-build.log
ARG BUILD_LOG=0

# Debug mode - more verbose
# 0: disable
# 1: enable
ARG DEBUG_MODE=0

# latest stable version
#ARG OPENSIPS_VERSION="latest"
# 3.3 series
#ARG OPENSIPS_VERSION="3.3.x"
# specific version
ARG OPENSIPS_VERSION="3.3.4"

# User and Group  ID for opensips user
ARG OPENSIPS_USER_ID=506
ARG OPENSIPS_GROUP_ID=506

# EXCLUDE_MODULES values:
# - all: all sub directory modules are compiled
# - none/NULL: none sub directory modules are compiled (only core modules is compiled)
# module(s) name: compile specific module(s) name (separated by space)
ARG EXCLUDE_MODULES="all"

# SKIP_MODULES values: NULL, module_name/modules_name separeted by space
# ==> It MUST is used with EXCLUDE_MODULES=all, else it's ignored <==
# - none/NULL: don't use skip_module 
# - module(s) name: skip specific module(s) name (separated by space) to ignore your compile
# These modules into SKIP_MODULES don't have native support in distros based on RedHat 9
ARG SKIP_MODULES="aaa_diameter cachedb_cassandra cachedb_couchbase db_oracle mmgeoip osp sngtc"

COPY install-opensips.sh /usr/src/

WORKDIR /usr/src

RUN bash install-opensips.sh

RUN rm -f install-opensips.sh

WORKDIR /

LABEL maintainer="Rodrigo Vian <rodrigovian@gmail.com>" \
      os.type="linux" \
      os.name="almalinux" \
      os.version="9" \
      opensips.version=${OPENSIPS_VERSION}

VOLUME "/etc/opensips"


CMD ["/bin/bash"]

# Optional
#ENTRYPOINT ["/usr/sbin/opensips", "-f/etc/opensips/opensips.cfg", "-uopensips", "-gopensips", "-FE" ]
