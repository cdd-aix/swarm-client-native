ok: swarm-client libsunec.so
	echo Checking $@
	./swarm-client -help
	./swarm-client -master $(MASTER_URL) -retry 1
MASTER_URL ?= https://www.google.com/
ARCH = $(shell dpkg --print-architecture)

swarm-client: swarm-client.jar config/swarm-client native-image.id
	echo Building $@
	$(NATIVE_IMAGE) $(SWARM_OPTS) -jar $<
TOCLEAN += swarm-client ./\?
NATIVE_IMAGE = $(NATIVE_IMAGE_DOCKER) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
NATIVE_IMAGE_DOCKER = docker run --rm  -v $(PWD):/out --user $(ID) --workdir /out $(NATIVE_IMAGE_I)
NATIVE_IMAGE_I = localhost/native-image:latest
ID = $(shell id -u $(LOGNAME))
SWARM_OPTS += --initialize-at-run-time=sun.awt.dnd.SunDropTargetContextPeer\$$EventDispatcher
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.Messages
SWARM_OPTS += -H:ConfigurationFileDirectories=config/$@
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.spi.Messages
SWARM_OPTS += -H:EnableURLProtocols=https,http

swarm-client.jar:
	echo Fetching $@
	wget --timestamping $(SWARM_CLIENT_URL)
	cp -p "$${SWARM_CLIENT_URL##*/}" swarm-client.jar
TOCLEAN += swarm-client.jar
JENKINS_SWARM_VERSION ?= 3.17
export SWARM_CLIENT_URL = http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$(JENKINS_SWARM_VERSION)/swarm-client-$(JENKINS_SWARM_VERSION).jar

# arg4j requires heavy introspection see
# https://github.com/oracle/graal/issues/1137 and
# https://github.com/oracle/graal/blob/master/substratevm/CONFIGURE.md
config/%: %.jar native-image.id
	echo Inspecting $^ for $@
	mkdir -p config
	$(NATIVE_IMAGE_AGENT) -jar $< -master $(MASTER_URL) -retry 1 || true
	$(NATIVE_IMAGE_AGENT) -jar $< -help
TOCLEAN += config
NATIVE_IMAGE_AGENT = $(NATIVE_IMAGE_DOCKER) java -agentlib:native-image-agent=config-merge-dir=$@

native-image.id: native-image/Dockerfile
	echo Building docker image $(NATIVE_IMAGE_I)
	docker image build --pull --no-cache --tag $(NATIVE_IMAGE_I) native-image
	docker image list --quiet $(NATIVE_IMAGE_I) > $@
TOCLEAN += native-image.id
DOCKER_TOCLEAN += localhost/native-image:latest

libsunec.so: native-image.id
	echo Fetching $@
	$(NATIVE_IMAGE_DOCKER) find /opt -name $@ -exec cp -v '{}' $@ ';'
TOCLEAN += $(SUNEC)

clean:
	echo Cleaning
	docker image rm $(DOCKER_TOCLEAN) || true
	rm -rvf $(TOCLEAN) || true
