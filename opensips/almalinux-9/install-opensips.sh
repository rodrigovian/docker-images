#!/usr/bin/env bash
################################################################################
# Description: Script for build docker image with opensips on Almalinux 9.
#
# Author: Rodrigo Scharlack Vian <rodrigovian at gmail dot com>
# Created: 2023/03/23
# Modified: 
# Version: 0.0.1
# Release: 1
# BuildRequires: dnf shadow-utils tar 
################################################################################
set -Eeuo pipefail
# -e, -o errorexit: exit at the first error. This is contrary to Bash's default behavior of continuing with the next command.
# -E, -o errtrace: ensures that ERR traps get inherited by functions, command substitutions, and subshell environments.
# -u, -o nounset: treats unset variables as errors.
# -o pipefail: normally Bash pipelines only return the exit code of the last command. This option will propagate intermediate errors.
################################################################################
# Functions
function _msgt() {
  echo >&2 -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${1-}"
}

function _msg() {
  echo >&2 -e "${1-}"
}

################################################################################
BUILD_LOG=${BUILD_LOG-0}

if [ 1 -eq "$BUILD_LOG" ]; then
  # REDIRECT ALL OUTPUT TO LOG FILE
  exec > >(tee -a /var/log/docker-build.log)
  exec 2>&1
fi

################################################################################
# VARIABLES
DEBUG_MODE=${DEBUG_MODE-0}
OPENSIPS_USER_ID=${OPENSIPS_USER_ID-506}
OPENSIPS_GROUP_ID=${OPENSIPS_GROUP_ID-506}
OPENSIPS_VERSION=${OPENSIPS_VERSION-'latest'}

# Modules for compile
EXCLUDE_MODULES=${EXCLUDE_MODULES-''}

# Modules for skip
SKIP_MODULES=${SKIP_MODULES-''}

# All Exclude Modules in version 3.3.4
ALL_MODULES='aaa_diameter aaa_radius auth_jwt b2b_logic_xml cachedb_cassandra '
ALL_MODULES+='cachedb_couchbase cachedb_memcached cachedb_mongodb cachedb_redis '
ALL_MODULES+='carrierroute cgrates compression cpl_c db_berkeley db_http db_mysql '
ALL_MODULES+='db_oracle db_perlvdb db_postgres db_sqlite db_unixodbc dialplan '
ALL_MODULES+='emergency event_rabbitmq event_kafka h350 httpd identity jabber json '
ALL_MODULES+='ldap lua mi_xmlrpc_ng mmgeoip osp perl pi_http presence presence_dfks '
ALL_MODULES+='presence_dialoginfo presence_mwi presence_xml proto_sctp proto_tls '
ALL_MODULES+='proto_wss pua pua_bla pua_dialoginfo pua_mi pua_usrloc pua_xmpp python '
ALL_MODULES+='rabbitmq rabbitmq_consumer regex rest_client rls sngtc siprec snmpstats '
ALL_MODULES+='tls_openssl tls_mgm tls_wolfssl xcap xcap_client xml xmpp uuid'

################################################################################
DNF_OPT='--enablerepo=crb -y'
[ 0 -eq "$DEBUG_MODE" ] && DNF_OPT+='q'

################################################################################
_msgt "Starting image building"
_msg "================================================================================"
_msg

_msgt "Build config"
_msg "OPENSIPS_USER_ID=$OPENSIPS_USER_ID"
_msg "OPENSIPS_GROUP_ID=$OPENSIPS_GROUP_ID"
_msg "OPENSIPS_VERSION=$OPENSIPS_VERSION"
_msg "EXCLUDE_MODULES=$EXCLUDE_MODULES"
_msg "SKIP_MODULES=$SKIP_MODULES"
_msg "================================================================================"
_msg

# Clean and Update
_msgt "Clean DNF cache"
_msg
dnf clean all
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Update packages"
_msg
cmd="dnf update $DNF_OPT"
eval "$cmd"
_msg

# Install auxiliary packages for builder image
_msgt "Install auxiliary packages"
_msg
cmd="dnf install $DNF_OPT dnf-plugins-core epel-release wget"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

cmd="dnf copr -qy enable irontec/sngrep >/dev/null 2>&1"
# echo "$cmd"
eval "$cmd"


# Install Development Tools group
_msgt "Install packages group 'Development Tools'"
_msg
cmd="dnf groupinstall $DNF_OPT 'Development Tools'"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Packages for opensips core
_msgt "Install core packages for opensips"
_msg
cmd="dnf install $DNF_OPT lynx ncurses-devel m4 openssl-devel"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Checking if modules are valids
# Exclude modules

if [ "$EXCLUDE_MODULES" == "none" ] || [ -z "$EXCLUDE_MODULES" ]; then
  MAKE_EXCLUDE_MODULES=""
  MAKE_SKIP_MODULES=""
elif [ "$EXCLUDE_MODULES" == "all" ]; then
  MAKE_EXCLUDE_MODULES="exclude_modules=''"
else
  AUX_EXCLUDE_MODULES=''
  for m in ${EXCLUDE_MODULES} ; do
    if [[ "$ALL_MODULES" =~  (^$m\ |\ $m\ |\ $m$) ]]; then
      AUX_EXCLUDE_MODULES+="$m "
    else
      [ 1 -eq "$DEBUG_MODE" ] && _msg "- Module $m non exist! Ignored!"
    fi
  done
  [ -n "$AUX_EXCLUDE_MODULES" ] && MAKE_EXCLUDE_MODULES="exclude_modules='${AUX_EXCLUDE_MODULES%\ *}'"
  MAKE_SKIP_MODULES=""
fi

# If EXCLUDE_MODULES=all, check skip modules
if [ "$EXCLUDE_MODULES" == "all" ]; then
  if [ "$SKIP_MODULES" == "none" ] || [ -z "$SKIP_MODULES" ]; then
    [ 1 -eq "$DEBUG_MODE" ] && _msg "- None module for skip!"
  else
    AUX_SKIP_MODULES=''
    for m in ${SKIP_MODULES} ; do
      if [[ "$ALL_MODULES" =~  (^$m\ |\ $m\ |\ $m$) ]]; then
        AUX_SKIP_MODULES+="$m "
      else
        [ 1 -eq "$DEBUG_MODE" ] && _msg "- Module $m non exist! Ignored!"
      fi
    done
    [ -n "$AUX_SKIP_MODULES" ] && MAKE_SKIP_MODULES="exclude_modules='${AUX_SKIP_MODULES%\ *}'"
  fi
fi

# Checking the modules dependency for compile
_msgt "Checking the modules dependency for compile"
PACKAGE_MODULES=''
PACKAGE_MODULES_DEPENDENCY=''

# m4
PACKAGE_MODULES_DEPENDENCY+='m4 '

# aaa_diameter - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^aaa_diameter\ |\ aaa_diameter\ |\ aaa_diameter$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

#xaaa_radius
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^aaa_radius\ |\ aaa_radius\ |\ aaa_radius$) ]]; then
  PACKAGE_MODULES+='radcli-compat-devel '
  PACKAGE_MODULES_DEPENDENCY+='radcli '
fi

# auth_jwt
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^auth_jwt\ |\ auth_jwt\ |\ auth_jwt$) ]]; then
  PACKAGE_MODULES+='libjwt-devel '
  PACKAGE_MODULES_DEPENDENCY+='libjwt '
fi

# b2b_logic_xml => deprecated
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^b2b_logic_xml\ |\ b2b_logic_xml\ |\ b2b_logic_xml$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# cachedb_cassandra - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cachedb_cassandra\ |\ cachedb_cassandra\ |\ cachedb_cassandra$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# cachedb_couchbase - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cachedb_couchbase\ |\ cachedb_couchbase\ |\ cachedb_couchbase$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# cachedb_memcached
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cachedb_memcached\ |\ cachedb_memcached\ |\ cachedb_memcached$) ]]; then
  PACKAGE_MODULES+='libmemcached-devel '
  PACKAGE_MODULES_DEPENDENCY+='libmemcached '
fi

# cachedb_mongodb
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cachedb_mongodb\ |\ cachedb_mongodb\ |\ cachedb_mongodb$) ]]; then
  PACKAGE_MODULES+='cyrus-sasl-devel json-c-devel mongo-c-driver-devel '
  PACKAGE_MODULES_DEPENDENCY+='cyrus-sasl mongo-c-driver json-c '
fi

# cachedb_redis
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cachedb_redis\ |\ cachedb_redis\ |\ cachedb_redis$) ]]; then
  PACKAGE_MODULES+='hiredis-devel '
  PACKAGE_MODULES_DEPENDENCY+='hiredis '
fi

# carrierroute
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^carrierroute\ |\ carrierroute\ |\ carrierroute$) ]]; then
  PACKAGE_MODULES+='libconfuse-devel '
  PACKAGE_MODULES_DEPENDENCY+='libconfuse '
fi

# cgrates
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cgrates\ |\ cgrates\ |\ cgrates$) ]]; then
  PACKAGE_MODULES+='json-c-devel '
  PACKAGE_MODULES_DEPENDENCY+='json-c '
fi

# compression
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^compression\ |\ compression\ |\ compression$) ]]; then
  PACKAGE_MODULES+='zlib-devel '
  PACKAGE_MODULES_DEPENDENCY+='zlib '
fi

# cpl_c
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^cpl_c\ |\ cpl_c\ |\ cpl_c$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# db_berkeley
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_berkeley\ |\ db_berkeley\ |\ db_berkeley$) ]]; then
  PACKAGE_MODULES+='libdb-devel '
  PACKAGE_MODULES_DEPENDENCY+='libdb '
fi

# db_http
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_http\ |\ db_http\ |\ db_http$) ]]; then
  PACKAGE_MODULES+='libcurl-devel '
  PACKAGE_MODULES_DEPENDENCY+='libcurl-minimal '
  #PACKAGE_MODULES_DEPENDENCY+='libcurl curl '
fi

# db_mysql
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_mysql\ |\ db_mysql\ |\ db_mysql$) ]]; then
  PACKAGE_MODULES+='mysql-devel '
  PACKAGE_MODULES_DEPENDENCY+='mysql-libs '
fi

# db_oracle - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_oracle\ |\ db_oracle\ |\ db_oracle$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# db_perlvdb
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_perlvdb\ |\ db_perlvdb\ |\ db_perlvdb$) ]]; then
  PACKAGE_MODULES+='perl-devel '
  PACKAGE_MODULES_DEPENDENCY+='perl '
fi

# db_postgres
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_postgres\ |\ db_postgres\ |\ db_postgres$) ]]; then
  PACKAGE_MODULES+='libpq-devel '
  PACKAGE_MODULES_DEPENDENCY+='libpq '
fi

# db_sqlite
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_sqlite\ |\ db_sqlite\ |\ db_sqlite$) ]]; then
  PACKAGE_MODULES+='sqlite-devel '
  PACKAGE_MODULES_DEPENDENCY+='sqlite sqlite-libs '
fi

# db_unixodbc
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^db_unixodbc\ |\ db_unixodbc\ |\ db_unixodbc$) ]]; then
  PACKAGE_MODULES+='unixODBC-devel '
  PACKAGE_MODULES_DEPENDENCY+='unixODBC '
fi

# dialplan
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^dialplan\ |\ dialplan\ |\ dialplan$) ]]; then
  PACKAGE_MODULES+='pcre-devel '
  PACKAGE_MODULES_DEPENDENCY+='pcre '
fi

# emergency
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^emergency\ |\ emergency\ |\ emergency$) ]]; then
  PACKAGE_MODULES+='libcurl-devel '
  PACKAGE_MODULES_DEPENDENCY+='libcurl-minimal '
  # PACKAGE_MODULES_DEPENDENCY+='libcurl curl '
fi

# event_kafka
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^event_kafka\ |\ event_kafka\ |\ event_kafka$) ]]; then
  PACKAGE_MODULES+='librdkafka-devel '
  PACKAGE_MODULES_DEPENDENCY+='librdkafka '
fi

# event_rabbitmq
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^event_rabbitmq\ |\ event_rabbitmq\ |\ event_rabbitmq$) ]]; then
  PACKAGE_MODULES+='librabbitmq-devel '
  PACKAGE_MODULES_DEPENDENCY+='librabbitmq '
fi

# h350
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^h350\ |\ h350\ |\ h350$) ]]; then
  PACKAGE_MODULES+='openldap-devel '
  PACKAGE_MODULES_DEPENDENCY+='openldap '
fi

# http
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^http\ |\ http\ |\ http$) ]]; then
  PACKAGE_MODULES+='libmicrohttpd-devel '
  PACKAGE_MODULES_DEPENDENCY+='libmicrohttpd '
fi

# identity - openssl-devel is default installed
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^identity\ |\ identity\ |\ identity$) ]]; then
#   PACKAGE_MODULES+='openssl-devel '
#   PACKAGE_MODULES_DEPENDENCY+='openssl '
# fi

# jabber
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^jabber\ |\ jabber\ |\ jabber$) ]]; then
  PACKAGE_MODULES+='expat-devel '
  PACKAGE_MODULES_DEPENDENCY+='expat '
fi

# json
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^json\ |\ json\ |\ json$) ]]; then
  PACKAGE_MODULES+='json-c-devel '
  PACKAGE_MODULES_DEPENDENCY+='json-c '
fi

# ldap
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^ldap\ |\ ldap\ |\ ldap$) ]]; then
  PACKAGE_MODULES+='openldap-devel '
  PACKAGE_MODULES_DEPENDENCY+='openldap '
fi

# lua
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^lua\ |\ lua\ |\ lua$) ]]; then
  PACKAGE_MODULES+='compat-lua-devel '
  PACKAGE_MODULES_DEPENDENCY+='compat-lua '
fi

# mi_xmlrpc_ng
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^mi_xmlrpc_ng\ |\ mi_xmlrpc_ng\ |\ mi_xmlrpc_ng$) ]]; then
  PACKAGE_MODULES+='libxml2-devel xmlrpc-c-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 xmlrpc-c '
fi

# mmgeoip - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^mmgeoip\ |\ __mmgeoipMOD__\ |\ mmgeoip$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# osp - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^osp\ |\ osp\ |\ osp$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# perl
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^perl\ |\ perl\ |\ perl$) ]]; then
  PACKAGE_MODULES+='perl-devel perl-ExtUtils-Embed perl-ExtUtils-MakeMaker '
  PACKAGE_MODULES_DEPENDENCY+='perl '
fi

# pi_http
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pi_http\ |\ pi_http\ |\ pi_http$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# presence
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^presence\ |\ presence\ |\ presence$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# presence_dfks
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^presence_dfks\ |\ presence_dfks\ |\ presence_dfks$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# presence_dialoginfo
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^presence_dialoginfo\ |\ presence_dialoginfo\ |\ presence_dialoginfo$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# presence_mwi
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^presence_mwi\ |\ presence_mwi\ |\ presence_mwi$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# presence_xml
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^presence_xml\ |\ presence_xml\ |\ presence_xml$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# proto_sctp
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^proto_sctp\ |\ proto_sctp\ |\ proto_sctp$) ]]; then
  PACKAGE_MODULES+='lksctp-tools-devel '
  PACKAGE_MODULES_DEPENDENCY+='lksctp-tools '
  MAKE_SCTP='SCTP=1'
fi

# proto_tls - openssl-devel is default installed
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^proto_tls\ |\ proto_tls\ |\ proto_tls$) ]]; then
#   PACKAGE_MODULES+='openssl-devel '
#   PACKAGE_MODULES_DEPENDENCY+='openssl '
# fi

# proto_wss - openssl-devel is default installed
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^proto_wss\ |\ proto_wss\ |\ proto_wss$) ]]; then
#   PACKAGE_MODULES+='openssl-devel '
#   PACKAGE_MODULES_DEPENDENCY+='openssl '
# fi

# pua
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua\ |\ pua\ |\ pua$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# pua_bla
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua_bla\ |\ pua_bla\ |\ pua_bla$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# pua_dialoginfo
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua_dialoginfo\ |\ pua_dialoginfo\ |\ pua_dialoginfo$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# pua_mi
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua_mi\ |\ pua_mi\ |\ pua_mi$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# pua_usrloc
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua_usrloc\ |\ pua_usrloc\ |\ pua_usrloc$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# pua_xmpp
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^pua_xmpp\ |\ pua_xmpp\ |\ pua_xmpp$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# python
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^python\ |\ python\ |\ python$) ]]; then
  PACKAGE_MODULES+='python3-devel '
  PACKAGE_MODULES_DEPENDENCY+='python3 '
fi

# rabbitmq
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^rabbitmq\ |\ rabbitmq\ |\ rabbitmq$) ]]; then
  PACKAGE_MODULES+='librabbitmq-devel '
  PACKAGE_MODULES_DEPENDENCY+='librabbitmq '
fi

# rabbitmq_consumer
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^rabbitmq_consumer\ |\ rabbitmq_consumer\ |\ rabbitmq_consumer$) ]]; then
  PACKAGE_MODULES+='librabbitmq-devel '
  PACKAGE_MODULES_DEPENDENCY+='librabbitmq '
fi

# regex
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^regex\ |\ regex\ |\ regex$) ]]; then
  PACKAGE_MODULES+='pcre-devel '
  PACKAGE_MODULES_DEPENDENCY+='pcre '
fi

# rest_client
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^rest_client\ |\ rest_client\ |\ rest_client$) ]]; then
  PACKAGE_MODULES+='libcurl-devel '
  PACKAGE_MODULES_DEPENDENCY+='libcurl-minimal '
  # PACKAGE_MODULES_DEPENDENCY+='libcurl curl '
fi

# rls
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^rls\ |\ rls\ |\ rls$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# sngtc - no native package
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^sngtc\ |\ sngtc\ |\ sngtc$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# siprec
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^siprec\ |\ siprec\ |\ siprec$) ]]; then
  PACKAGE_MODULES+='libuuid-devel '
  PACKAGE_MODULES_DEPENDENCY+='libuuid '
fi

# snmpstats
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^snmpstats\ |\ snmpstats\ |\ snmpstats$) ]]; then
  PACKAGE_MODULES+='net-snmp-devel '
  PACKAGE_MODULES_DEPENDENCY+='net-snmp '
fi

# tls_openssl - openssl-devel is default installed
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^tls_openssl\ |\ tls_openssl\ |\ tls_openssl$) ]]; then
#   PACKAGE_MODULES+='openssl-devel '
#   PACKAGE_MODULES_DEPENDENCY+='openssl '
# fi

# tls_mgm - no needed libray

# tls_wolfssl - no needed libray ??????
# if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^tls_wolfssl\ |\ tls_wolfssl\ |\ tls_wolfssl$) ]]; then
#   PACKAGE_MODULES+=' '
#   PACKAGE_MODULES_DEPENDENCY+=' '
# fi

# xcap
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^xcap\ |\ xcap\ |\ xcap$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# xcap_client
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^xcap_client\ |\ xcap_client\ |\ xcap_client$) ]]; then
  PACKAGE_MODULES+='libcurl-devel libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libcurl-minimal libxml2 '
fi

# xml
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^xml\ |\ xml\ |\ xml$) ]]; then
  PACKAGE_MODULES+='libxml2-devel '
  PACKAGE_MODULES_DEPENDENCY+='libxml2 '
fi

# xmpp
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^xmpp\ |\ xmpp\ |\ xmpp$) ]]; then
  PACKAGE_MODULES+='expat-devel '
  PACKAGE_MODULES_DEPENDENCY+='expat '
fi

# uuid
if [ "$EXCLUDE_MODULES" == "all" ] || ! [[ "$SKIP_MODULES" =~  (^uuid\ |\ uuid\ |\ uuid$) ]]; then
  PACKAGE_MODULES+='libuuid-devel '
  PACKAGE_MODULES_DEPENDENCY+='libuuid '
fi

AUX=''
for pkg in $PACKAGE_MODULES; do
  if ! [[ "$AUX" =~  (^$pkg\ |\ $pkg\ |\ $pkg$) ]]; then
    AUX+="$pkg "
  fi
done
[ -n "$AUX" ] && PACKAGE_MODULES=${AUX%\ *}

_msg
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Install modules packages"
_msg
cmd="dnf install $DNF_OPT $PACKAGE_MODULES"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Download opensips version
_msgt "Download opensips package version $OPENSIPS_VERSION"
_msg
cmd="wget --quiet -c -np -nd -nH -r -N -l1 -erobots=off -A \".tar.gz\" https://opensips.org/pub/opensips/$OPENSIPS_VERSION/"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Unpacked tarball
cmd="ls *.tar.gz"
TARBALL=$(eval "$cmd")
if [ "$OPENSIPS_VERSION" == "latest" ]; then
  _msg
  _msgt "Latest version is $TARBALL"
  _msg "--------------------------------------------------------------------------------"
  _msg
fi

_msgt "Unpacking tarball"
_msg
cmd="tar -xzf $TARBALL"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Buildir for opensips
_msgt "Change to opensips dir for building"
_msg
pushd "${TARBALL/.tar.gz/}"
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Clean project"
_msg
make proper
_msg "--------------------------------------------------------------------------------"
_msg

# Build
_msgt "Building opensips"
_msg
#ln -sf /usr/bin/python3 /usr/bin/python

B_CFLAGS="-m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables "
B_CFLAGS+="-fstack-clash-protection -fcf-protection"

cmd="LOCALBASE=/usr NICER=0 CFLAGS='$B_CFLAGS' PYTHON=python3 " 
cmd+="make TLS=1 $MAKE_SCTP $MAKE_EXCLUDE_MODULES $MAKE_SKIP_MODULES "
cmd+="cfg_target='/etc/opensips/' "
cmd+="modules_prefix='/usr' modules_dir='lib64/opensips/modules' all"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Install
_msgt "Install opensips"
_msg
cmd="make TLS=1 $MAKE_SCTP LIBDIR=lib64 basedir='/' prefix='/usr' "
cmd+="cfg_prefix='/' cfg_target='/etc/opensips/' "
cmd+="$MAKE_EXCLUDE_MODULES $MAKE_SKIP_MODULES "
cmd+="modules_prefix='/usr' modules_dir='lib64/opensips/modules' install"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Copy default file to /usr/share/doc/opensips/
cp /etc/opensips/opensips.cfg /usr/share/doc/opensips/

# Install sysconfig file
install -D -p -m 644 packaging/redhat_fedora/opensips.sysconfig /etc/sysconfig/opensips

# Clean /etc/opensips
_msgt "Clean opensips config directory"
_msg
rm -fr /etc/opensips/*
_msg "--------------------------------------------------------------------------------"
_msg

# Add opensips user and group
_msgt "Create group for opensips"
_msg
cmd="groupadd -r -g $OPENSIPS_GROUP_ID opensips"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Create user for opensips"
_msg
cmd="useradd -r -g opensips -u $OPENSIPS_USER_ID "
cmd+="-d /var/run/opensips -s /sbin/nologin "
cmd+="-c 'OpenSIPS SIP Server' opensips"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Create opensips home
_msgt "Create opensips home"
_msg
cmd="install -o opensips -g opensips -m 0755 -d /var/run/opensips"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Set permissions
_msgt "Set permission to opensips user and group"
_msg
cmd="chown opensips:opensips /etc/opensips && chmod 0755 /etc/opensips"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Exit workdir opensips
popd
_msgt "Opensips build and install sucessfull"
_msg
_msg "--------------------------------------------------------------------------------"
_msg

# Download opensips-cli
_msgt "Download opensips-cli"
_msg
cmd="git clone https://github.com/opensips/opensips-cli"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Install requirements for opensips-cli
_msgt "Install required packages for opensips-cli"
_msg
cmd="dnf install $DNF_OPT python3-devel python3-rpm-macros python3-mysqlclient python3-sqlalchemy python3-pyOpenSSL"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Buildir for opensips-cli
_msgt "Change to opensips-cli dir for building"
_msg
pushd opensips-cli 
_msg "--------------------------------------------------------------------------------"
_msg

# Compile and install in /usr
_msgt "Build and install opensips-cli"
_msg
cmd="CFLAGS='-m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' python3 setup.py install --prefix /usr"
[ 1 -eq "$DEBUG_MODE" ] && _msg "[DEBUG] $cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Exit workdir opensips-cli 
popd
_msgt "Opensips-cli build and install sucessfull"
_msg
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Clean source directories"
_msg
# Remove opensips and opensips-cli source
rm -fr opensips*
rm -fr /usr/src/annobin
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Removing Group 'Development Tools'"
_msg
# Ignore systemd packages because it can't to be uninstall
cmd="dnf group remove $DNF_OPT 'Development Tools' --exclude='systemd*'"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Remove all devel packages and yours dependencies
_msgt "Removing all devel packages"
_msg
cmd="dnf remove $DNF_OPT '*-devel'"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Install required packages for this opensips image"
_msg
cmd="dnf install $DNF_OPT $PACKAGE_MODULES_DEPENDENCY"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

_msgt "Install some packages util"
_msg
cmd="dnf install $DNF_OPT net-tools ngrep procps sngrep"
# echo "$cmd"
eval "$cmd"
_msg "--------------------------------------------------------------------------------"
_msg

# Clean dnf
_msgt "Clean DNF cache"
_msg 
dnf clean all
_msg "================================================================================"
_msg
################################################################################
_msgt "Opensips image build finished!"
_msg