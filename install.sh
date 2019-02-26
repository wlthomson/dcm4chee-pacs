#!/usr/bin/env bash

LDAP_TAG=2.4.44-16.0
POSTGRES_TAG=11.1-15
DCM4CHEE_TAG=5.15.1
DCM4CHE_TOOLS_TAG=5.15.1

LDAP_NAME=slapd-dcm4chee
POSTGRES_NAME=postgres-dcm4chee
DCM4CHEE_NAME=dcm4chee-arc-psql
DCM4CHE_TOOLS_NAME=dcm4che-tools

LDAP_IMAGE=dcm4che/$LDAP_NAME:$LDAP_TAG
POSTGRES_IMAGE=dcm4che/$POSTGRES_NAME:$POSTGRES_TAG
DCM4CHEE_IMAGE=dcm4che/$DCM4CHEE_NAME:$DCM4CHEE_TAG
DCM4CHE_TOOLS_IMAGE=dcm4che/$DCM4CHE_TOOLS_NAME:$DCM4CHE_TOOLS_TAG

LDAP_CONTAINER=ldap
POSTGRES_CONTAINER=db
DCM4CHEE_CONTAINER=arc

POSTGRES_DB=pacsdb
POSTGRES_USER=pacs
POSTGRES_PASSWORD=pacs

BRIDGE_NET=dcmchee_default

# Download or update dcm4chee images.
docker pull $LDAP_IMAGE
docker pull $POSTGRES_IMAGE
docker pull $DCM4CHEE_IMAGE
docker pull $DCM4CHE_TOOLS_IMAGE

# DCM4CHEE tools.
DCM4CHEE_TOOLS_TAG=5.15.1

# Download dcm4chee images.
docker pull dcm4che/dcm4chee-arc-psql:$DCM4CHEE_TAG
docker pull dcm4che/postgres-dcm4chee:$POSTGRES_TAG
docker pull dcm4che/slapd-dcm4chee:$LDAP_TAG
docker pull dcm4che/dcm4che-tools:$DCM4CHEE_TOOLS_TAG

# Remove existing network, containers.
docker network rm $(docker network ls | grep $BRIDGE_NET | awk '{print $1}')
docker container stop $(docker container ls | grep "dcm4che" | awk '{print $1}')
docker container rm $(docker container ls | grep "dcm4che" | awk '{print $1}')

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
           -d $POSTGRES_IMAGE

# Launch LDAP container.
docker run --network=$BRIDGE_NET --name $LDAP_CONTAINER \
           -p 389:389 \
           -v /etc/localtime:/etc/localtime:ro \
           -v /etc/timezone:/etc/timezone:ro \
           -v /var/local/dcm4chee-arc/ldap:/var/lib/ldap \
           -v /var/local/dcm4chee-arc/slapd.d:/etc/ldap/slapd.d \
           -d $LDAP_IMAGE

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
           -d $DCM4CHEE_IMAGE

   # Send CT data to the archive.
 docker run --rm --network=$BRIDGE_NET $DCM4CHE_TOOLS_IMAGE storescu \
	-cDCM4CHEE@arc:11112 /opt/dcm4che/etc/testdata/dicom

 # Copy Weasis viewer config files.
 docker cp ./weasis-pacs-connector.properties arc:/opt/wildfly/standalone/configuration/
 docker cp ./dicom-dcm4chee-arc.properties arc:/opt/wildfly/standalone/configuration
