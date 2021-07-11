#!/bin/bash

# docker run --privileged -v /tmp/k8s-containers:/var/lib/containers -it --rm -v $PWD:/work -w /work byjg/k8s-ci

set -e

if [ -z "$DOCKER_USERNAME" ]  || [ -z "$DOCKER_PASSWORD" ] || [ -z "$DOCKER_REGISTRY" ]
then
  echo You need to setup \$DOCKER_USERNAME, \$DOCKER_PASSWORD and \$DOCKER_REGISTRY before run this command.
  exit 1
fi

buildah login --username $DOCKER_USERNAME --password $DOCKER_PASSWORD $DOCKER_REGISTRY

podman run --rm --events-backend=file --cgroup-manager=cgroupfs --privileged docker://multiarch/qemu-user-static --reset -p yes

DOCKER_REPO=docker.io/byjg/jenkins-arm

JENKINS_VERSION=$(curl -s https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/ | cut -d\" -f2 | cut -d/ -f1 | grep "^2\." | sort --version-sort | tail -n 1)
JENKINS_SHA=$(curl -fsSL https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /tmp/jenkins.war && sha256sum /tmp/jenkins.war | cut -d\  -f1)

if [ -z "$JENKINS_VERSION" ] || [ -z "$JENKINS_SHA" ]
then
  echo JENKINS_VERSION or JENKINS_SHA is empty. Check the code
  exit 1
fi

# Build Jenkins

git clone https://github.com/jenkinsci/docker.git /tmp/docker

cd /tmp/docker

sed -i -e "s~^FROM \(.*\)$~FROM docker://\1~g" 8/debian/buster/hotspot/Dockerfile
buildah bud \
    --platform "linux/arm64/v8" \
    --build-arg JENKINS_VERSION=$JENKINS_VERSION \
    --build-arg JENKINS_SHA=$JENKINS_SHA \
    -t $DOCKER_REPO:$JENKINS_VERSION \
    -f 8/debian/buster/hotspot/Dockerfile .
buildah push --format v2s2 $DOCKER_REPO:$JENKINS_VERSION


# Build Jenkins Agent

git clone https://github.com/jenkinsci/docker-agent.git /tmp/docker-agent

cd /tmp/docker-agent
AGENT_TAG=$(git tag | sort --version-sort | tail -n 1)

git checkout $AGENT_TAG
sed -i -e "s~^FROM \(.*\)$~FROM docker://\1~g" 8/buster/Dockerfile
sed -i -e "s~apt-get install~apt-get -y install~g" 8/buster/Dockerfile 

buildah bud \
    --platform "linux/arm64/v8" \
    -t $DOCKER_REPO:agent-$AGENT_TAG \
    -f 8/buster/Dockerfile .
buildah push --format v2s2 $DOCKER_REPO:agent-$AGENT_TAG

# Build Jenkins Inbound Agent

git clone https://github.com/jenkinsci/docker-inbound-agent.git /tmp/docker-inbound-agent

cd /tmp/docker-inbound-agent
git checkout $AGENT_TAG
sed -i -e "s~^FROM.*$~FROM $DOCKER_REPO:agent-$AGENT_TAG~g" 8/debian/Dockerfile

buildah bud \
    --platform "linux/arm64/v8" \
    -t $DOCKER_REPO:inbound-agent-$AGENT_TAG \
    -f 8/debian/Dockerfile .
buildah push --format v2s2 $DOCKER_REPO:inbound-agent-$AGENT_TAG

