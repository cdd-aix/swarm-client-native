ok: swarm-client $(SUNEC)
	./swarm-client -help
	./swarm-client -master $(MASTER_URL) -retry 1
MASTER_URL = https://zeniv.linux.org.uk/
export SUNEC = libsunec.so
export JAVA_HOME=$(PWD)
ARCH = $(shell dpkg --print-architecture)

swarm-client: swarm-client.jar swarm-config native-image.id
	$(NATIVE_IMAGE) $(SWARM_OPTS) -jar $<
TOCLEAN += swarm-client ./\?
NATIVE_IMAGE = $(NATIVE_IMAGE_DOCKER) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
NATIVE_IMAGE_DOCKER = docker run --rm  -v $(PWD):/out --user $(ID) --workdir /out $(NATIVE_IMAGE_I)
NATIVE_IMAGE_I = localhost/native-image:latest
ID = $(shell id -u $(LOGNAME))
SWARM_OPTS += --initialize-at-run-time=sun.awt.dnd.SunDropTargetContextPeer\$$EventDispatcher
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.Messages
SWARM_OPTS += -H:ConfigurationFileDirectories=swarm-config
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.spi.Messages
SWARM_OPTS += -H:EnableURLProtocols=https,http

swarm-client.jar:
	wget --timestamping $(SWARM_CLIENT_URL)
	cp -p "$${SWARM_CLIENT_URL##*/}" swarm-client.jar
TOCLEAN += swarm-client.jar
JENKINS_SWARM_VERSION ?= 3.17
export SWARM_CLIENT_URL = http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$(JENKINS_SWARM_VERSION)/swarm-client-$(JENKINS_SWARM_VERSION).jar

# arg4j requires heavy introspection see
# https://github.com/oracle/graal/issues/1137 and
# https://github.com/oracle/graal/blob/master/substratevm/CONFIGURE.md
swarm-config: swarm-client.jar
	$(NATIVE_IMAGE_AGENT) -jar $< -master $(MASTER_URL) -retry 1 || true
	$(NATIVE_IMAGE_AGENT) -jar $< -help
TOCLEAN += swarm-config
NATIVE_IMAGE_AGENT = $(NATIVE_IMAGE_DOCKER) java -agentlib:native-image-agent=config-merge-dir=$@

native-image.id: Dockerfile
	docker image build --no-cache --tag $(NATIVE_IMAGE_I) .
	docker image list --quiet $(NATIVE_IMAGE_I) > $@
TOCLEAN += native-image.id
DOCKER_TOCLEAN += localhost/native-image:latest

$(SUNEC): native-image.id
	$(NATIVE_IMAGE_DOCKER) find /opt -name $(SUNEC) -exec cp -v '{}' $(SUNEC) ';'
TOCLEAN += $(SUNEC)

clean:
	rm -rvf $(TOCLEAN)
	docker image rm $(DOCKER_TOCLEAN)
