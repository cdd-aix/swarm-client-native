ok: swarm-client
	./swarm-client -help

TOCLEAN += swarm-client ./\?
swarm-client: swarm-client.jar swarm-config native-image.id
	$(NATIVE_IMAGE) $(SWARM_OPTS) -jar $<
NATIVE_IMAGE = $(NATIVE_IMAGE_DOCKER) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
NATIVE_IMAGE_DOCKER = docker run --rm  -v $(PWD):/out --user $(ID) --workdir /out $(NATIVE_IMAGE_I)
NATIVE_IMAGE_I = localhost/native-image:latest
ID = $(shell id -u $(LOGNAME))
SWARM_OPTS += --initialize-at-run-time=sun.awt.dnd.SunDropTargetContextPeer\$$EventDispatcher
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.Messages
SWARM_OPTS += -H:ConfigurationFileDirectories=swarm-config

TOCLEAN += swarm-client.jar
swarm-client.jar:
	wget --timestamping $(SWARM_CLIENT_URL)
	cp -p "$${SWARM_CLIENT_URL##*/}" swarm-client.jar
JENKINS_SWARM_VERSION ?= 3.17
export SWARM_CLIENT_URL = http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$(JENKINS_SWARM_VERSION)/swarm-client-$(JENKINS_SWARM_VERSION).jar

TOCLEAN += swarm-config
swarm-config: swarm-client.jar
	$(NATIVE_IMAGE_AGENT) -jar $< -help
NATIVE_IMAGE_AGENT = $(NATIVE_IMAGE_DOCKER) java -agentlib:native-image-agent=config-output-dir=$@

TOCLEAN += native-image.id
DOCKER_TOCLEAN += localhost/native-image:latest
native-image.id: Dockerfile
	docker image build --no-cache --tag $(NATIVE_IMAGE_I) .
	docker image list --quiet $(NATIVE_IMAGE_I) > $@

clean:
	rm -rvf $(TOCLEAN)
	docker image rm $(DOCKER_TOCLEAN)
