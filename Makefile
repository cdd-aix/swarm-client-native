ok: swarm-client
	swarm-client -help

TOCLEAN += swarm-client
swarm-client: swarm-client.jar native-image.id
	$(NATIVE_IMAGE) $(SWARM_NATIVE_IMAGE_OPTS) -jar $<
NATIVE_IMAGE = docker run --rm  -v $(PWD):/out --user $(ID) --workdir /out $(NATIVE_IMAGE_I) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
NATIVE_IMAGE_I = localhost/native-image:latest
ID = $(shell id -u $(LOGNAME))

TOCLEAN += swarm-client.jar
swarm-client.jar:
	wget --timestamping $(SWARM_CLIENT_URL)
	cp -p "$${SWARM_CLIENT_URL##*/}" swarm-client.jar

JENKINS_SWARM_VERSION ?= 3.17
export SWARM_CLIENT_URL = http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$(JENKINS_SWARM_VERSION)/swarm-client-$(JENKINS_SWARM_VERSION).jar

TOCLEAN += native-image.id
DOCKER_TOCLEAN += localhost/native-image:latest
native-image.id: Dockerfile
	docker image build --tag $(NATIVE_IMAGE_I) .
	docker image list --quiet $(NATIVE_IMAGE_I) > $@

clean:
	rm -vf $(TOCLEAN)
	rm -rvf ./\?
	docker image rm $(DOCKER_TOCLEAN)
