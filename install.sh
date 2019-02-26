#!/usr/bin/env bash

# Bridge network.
BRIDGE_NET=dcmchee_default

# LDAP.
LDAP_TAG=2.4.44-16.0
LDAP_CONTAINER=ldap

# Postgres.
POSTGRES_TAG=11.1-15
POSTGRES_CONTAINER=db
POSTGRES_DB=pacsdb
POSTGRES_USER=pacs
POSTGRES_PASSWORD=pacs

# DCM4CHEE.
DCM4CHEE_TAG=5.15.1
DCM4CHEE_CONTAINER=arc

# DCM4CHEE tools.
DCM4CHEE_TOOLS_TAG=5.15.1

# Download dcm4chee images.
docker pull dcm4che/dcm4chee-arc-psql:$DCM4CHEE_TAG
docker pull dcm4che/postgres-dcm4chee:$POSTGRES_TAG
docker pull dcm4che/slapd-dcm4chee:$LDAP_TAG
docker pull dcm4che/dcm4che-tools:$DCM4CHEE_TOOLS_TAG

# Create bridge network.
docker network create $BRIDGE_NET

# Launch database container.
 docker run --network=$BRIDGE_NET --name $POSTGRES_CONTAINER \
           -p 5432:5432 \
           -e POSTGRES_DB=$POSTGRES_DB \
           -e POSTGRES_USER=$POSTGRES_USER \
           -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
           -v /etc/localtime:/etc/localtime:ro \
           -v /etc/timezone:/etc/timezone:ro \
           -v /var/local/dcm4chee-arc/db:/var/lib/postgresql/data \
           -d dcm4che/postgres-dcm4chee:$POSTGRES_TAG

# Launch LDAP container.
docker run --network=$BRIDGE_NET --name $LDAP_CONTAINER \
           -p 389:389 \
           -v /etc/localtime:/etc/localtime:ro \
           -v /etc/timezone:/etc/timezone:ro \
           -v /var/local/dcm4chee-arc/ldap:/var/lib/ldap \
           -v /var/local/dcm4chee-arc/slapd.d:/etc/ldap/slapd.d \
           -d dcm4che/slapd-dcm4chee:$LDAP_TAG

 # Launch dch4che container.
 docker run --network=$BRIDGE_NET --name $DCM4CHEE_CONTAINER \
           -p 8080:8080 \
           -p 8443:8443 \
           -p 9990:9990 \
           -p 11112:11112 \
           -p 2575:2575 \
           -e POSTGRES_DB=pacsdb \
           -e POSTGRES_USER=pacs \
           -e POSTGRES_PASSWORD=pacs \
           -e WILDFLY_WAIT_FOR="ldap:389 db:5432" \
           -v /etc/localtime:/etc/localtime:ro \
           -v /etc/timezone:/etc/timezone:ro \
           -v /var/local/dcm4chee-arc/wildfly:/opt/wildfly/standalone \
           -d dcm4che/dcm4chee-arc-psql:$DCM4CHEE_TAG

   # Send CT data to the archive.
 docker run --rm --network=$BRIDGE_NET dcm4che/dcm4che-tools:$DCM4CHEE_TOOLS_TAG storescu \
	-cDCM4CHEE@arc:11112 /opt/dcm4che/etc/testdata/dicom
