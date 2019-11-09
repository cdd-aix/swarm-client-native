rebuild-test: | rebuild test

rebuild: docker-compose.yaml
	docker-compose build --pull --no-cache

test: | jenkins_up real-test jenkins_down

jenkins_up: docker-compose.yaml
	docker-compose up -d jenkins
	docker-compose run -T jenkins $(CHECK_JENKINS) $(RETRY) $(JENKINS)
	$(RUN_NATIVE_IMAGE) $(CHECK_JENKINS) $(JENKINS)
	docker-compose ps

CHECK_JENKINS  = curl --fail --silent --show-error --location -o /dev/null
RETRY = --retry-connrefused --retry 3 --retry-delay 15
RUN_NATIVE_IMAGE = docker-compose run -T native-image
export MYUID := $(shell id -u)
export GID := $(shell id -g)
JENKINS = http://jenkins:8080/

SWARM_CLIENT = $(basename $(SWARM_CLIENT_JAR))
SWARM_CLIENT_JAR = $(notdir $(SWARM_CLIENT_URL))
SWARM_CLIENT_URL = http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$(JENKINS_SWARM_VERSION)/swarm-client-$(JENKINS_SWARM_VERSION).jar
JENKINS_SWARM_VERSION ?= 3.17
real-test: $(SWARM_CLIENT) libsunec.so
	$(RUN_NATIVE_IMAGE) ./$(SWARM_CLIENT) $(TEST_HELP)
	: # TODO: Will fail until https://github.com/oracle/graal/issues/460 is resolved
	$(RUN_NATIVE_IMAGE) timeout 15 ./$(SWARM_CLIENT) $(TEST_FULL)  || [ $$? -eq 124 ]

TEST_HELP = -help > /dev/null
TEST_FULL = -master http://jenkins/ -username admin -password admin -retry 0

$(SWARM_CLIENT): $(SWARM_CLIENT_JAR) config/$(SWARM_CLIENT)
	$(NATIVE_IMAGE) $(SWARM_OPTS) -jar $<

TOCLEAN += swarm-client ./\?
NATIVE_IMAGE = $(RUN_NATIVE_IMAGE) native-image --no-server --no-fallback -H:+ReportExceptionStackTraces
SWARM_OPTS += --initialize-at-run-time=sun.awt.dnd.SunDropTargetContextPeer\$$EventDispatcher
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.Messages
SWARM_OPTS += -H:ConfigurationFileDirectories=config/$@
SWARM_OPTS += -H:IncludeResourceBundles=org.kohsuke.args4j.spi.Messages
SWARM_OPTS += -H:EnableURLProtocols=https,http

$(SWARM_CLIENT_JAR):
	wget --timestamping $(SWARM_CLIENT_URL)

TOCLEAN += $(SWARM_CLIENT_JAR)

# arg4j requires heavy introspection see
# https://github.com/oracle/graal/issues/1137 and
# https://github.com/oracle/graal/blob/master/substratevm/CONFIGURE.md
config/%: %.jar | clean-config jenkins_up
	echo Inspecting $^ for $@
	mkdir -p config
	$(NATIVE_IMAGE_AGENT) -jar $< -master 'https://www.google.com' -retry 0 || true
	$(NATIVE_IMAGE_AGENT) -jar $< $(TEST_HELP)
# TODO: hudson.FilePath
	: timeout 15 $(NATIVE_IMAGE_AGENT) -jar $< $(TEST_FULL) || [ $$? -eq 124 ]

clean-config:
	: TODO: Make native-image run as current user
	$(RUN_NATIVE_IMAGE) rm -rvf config

# TOCLEAN += config
NATIVE_IMAGE_AGENT = $(RUN_NATIVE_IMAGE) java -agentlib:native-image-agent=config-merge-dir=$@

libsunec.so:
	echo Fetching $@
	$(RUN_NATIVE_IMAGE) find /opt -name $@ -exec cp -v '{}' $@ ';'

TOCLEAN += $(SUNEC)

jenkins_down: docker-compose.yaml
	docker-compose down

clean: | clean-config
	echo Cleaning
	docker-compose down --remove-orphans
	rm -rvf $(TOCLEAN) || true

realclean: clean
	docker-compose down --rmi local --volumes -remove-orphans
	docker image rm $$(awk '$$1=="FROM"{print $$2}' native-image/Dockerfile) || true
