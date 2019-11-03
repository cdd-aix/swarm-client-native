test: swarm-client libsunec.so jenkins.cid | jenkins_up
	echo Checking $@
	./swarm-client $(TEST_HELP)
# TODO: Will fail until https://github.com/oracle/graal/issues/460 is resolved
	timeout 15 ./swarm-client $(TEST_FULL) || [ $$? -eq 124 ]
TEST_HELP = -help > /dev/null
TEST_FULL = -master $(MASTER_URL) -tunnel $(TUNNEL) -username admin -password admin -retry 0
MASTER_URL = http://$(shell cat jenkins.http_port)/
TUNNEL = $(shell cat jenkins.jnlp_port)
ARCH = $(shell dpkg --print-architecture)

swarm-client: swarm-client.jar config/swarm-client native-image.id
	echo Building $@
	$(NATIVE_IMAGE) $(SWARM_OPTS) -jar $<
TOCLEAN += swarm-client ./\?
NATIVE_IMAGE = $(NATIVE_IMAGE_DOCKER) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
NATIVE_IMAGE_DOCKER = $(DOCKER_RUN)  -v $(PWD):/out --user $(ID) --workdir /out $(NATIVE_IMAGE_I)
DOCKER_RUN = docker container run --rm
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
config/%: %.jar native-image.id jenkins.cid | jenkins_up
	echo Inspecting $^ for $@
	rm -rvf $@
	mkdir -p config
	$(NATIVE_IMAGE_AGENT) -jar $< -master https://www.google.com -retry 0 || true
# TODO: hudson.FilePath
	: timeout 15 $(NATIVE_IMAGE_AGENT) -jar $< $(TEST_FULL) || [ $$? -eq 124 ]
	$(NATIVE_IMAGE_AGENT) -jar $< $(TEST_HELP)
TOCLEAN += config
NATIVE_IMAGE_AGENT = $(NATIVE_IMAGE_DOCKER) java -agentlib:native-image-agent=config-merge-dir=$@

jenkins_up: jenkins.http_port jenkins.jnlp_port
	curl --retry 3 --retry-connrefused --retry-delay 15 $(MASTER_URL) > /dev/null

native-image.id: native-image/Dockerfile
	echo Building docker image $(NATIVE_IMAGE_I)
	docker image build --tag $(NATIVE_IMAGE_I) --iidfile $@ native-image
TOCLEAN += native-image.id
DOCKER_IMAGE_TOCLEAN += localhost/native-image:latest

libsunec.so: native-image.id
	echo Fetching $@
	$(NATIVE_IMAGE_DOCKER) find /opt -name $@ -exec cp -v '{}' $@ ';'
TOCLEAN += $(SUNEC)

jenkins.cid jenkins.http_port jenkins.jnlp_port: jenkins.id
	echo Starting test jenkins
	docker container inspect $(shell cat jenkins.cid) > /dev/null || $(DOCKER_RUN) --publish-all --detach $(JENKINS_IMAGE) > jenkins.cid
	echo $$(cat jenkins.cid)
	docker container port $$(cat jenkins.cid) 8080/tcp | sed -e 's,0\.0\.0\.0,$(HOST),' > jenkins.http_port
	docker container port $$(cat jenkins.cid) 50000/tcp | sed -e 's,0\.0\.0\.0,$(HOST),' > jenkins.jnlp_port
TOCLEAN += jenkins.cid jenkins.http_port jenkins.jnlp_port
HOST = $(shell host $$(hostname) | awk '{print $$4}')
JENKINS_IMAGE = localhost/test-jenkins:latest
DOCKER_CONTAINER_RM += $(shell cat jenkins.cid)

jenkins.id: jenkins/Dockerfile
	echo Building docker image $(JENKINS_IMAGE)
	docker image build --tag $(JENKINS_IMAGE) --iidfile $@ jenkins
TOCLEAN += jenkins.id
DOCKER_IMAGE_TOCLEAN += $(JENKINS_IMAGE)


clean:
	echo Cleaning
	docker container rm -f $(DOCKER_CONTAINER_RM) || true
	docker image rm $(DOCKER_IMAGE_TOCLEAN) || true
	rm -rvf $(TOCLEAN) || true
realclean: clean
	docker image rm $$(awk '$$1=="FROM"{print $$2}' native-image/Dockerfile) || true
