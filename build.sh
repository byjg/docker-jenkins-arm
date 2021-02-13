#!/bin/bash

set -e

OPENJDK_ARM=adoptopenjdk/openjdk8:jdk8u282-b08-debian
JENKINS_VERSION=2.263.4
JENKINS_SHA=1d4a7409784236a84478b76f3f2139939c0d7a3b4b2e53b1fcef400c14903ab6
DOCKER_REPO=docker.io/byjg/jenkins-arm

# Build Jenkins

git clone https://github.com/jenkinsci/docker.git /tmp/docker

cd /tmp/docker

docker build \
    --build-arg JENKINS_VERSION=$JENKINS_VERSION \
    --build-arg JENKINS_SHA=$JENKINS_SHA \
    -t $DOCKER_REPO:$JENKINS_VERSION \
    -f 8/debian/buster/hotspot/Dockerfile .
docker push $DOCKER_REPO:$JENKINS_VERSION


# Build Jenkins Agent

git clone https://github.com/jenkinsci/docker-agent.git /tmp/docker-agent

cd /tmp/docker-agent
sed -i -e "s~^FROM.*$~FROM $OPENJDK_ARM~g" 8/buster/Dockerfile
sed -i -e "s~apt-get install~apt-get -y install~g" 8/buster/Dockerfile 

docker build -t $DOCKER_REPO:agent-4.6 -f 8/buster/Dockerfile .
docker push $DOCKER_REPO:agent-4.6

# Build Jenkins Inbound Agent

git clone https://github.com/jenkinsci/docker-inbound-agent.git /tmp/docker-inbound-agent

cd /tmp/docker-inbound-agent
sed -i -e "s~^FROM.*$~FROM $DOCKER_REPO:agent-4.6~g" 8/debian/Dockerfile

docker build -t $DOCKER_REPO:inbound-agent-4.6 -f 8/debian/Dockerfile .
docker push $DOCKER_REPO:inbound-agent-4.6

