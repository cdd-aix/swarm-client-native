# Best practice is a specific release tag
FROM jenkins/jenkins:lts-alpine
ENV JAVA_OPTS "-Djenkins.install.runSetupWizard=false ${JAVA_OPTS:-}"
RUN /usr/local/bin/install-plugins.sh\
	configuration-as-code\
	script-security\
	swarm
COPY jenkins.yaml ${JENKINS_HOME}/
