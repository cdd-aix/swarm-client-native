# hadolint ignore=DL3007
FROM oracle/graalvm-ce:latest
RUN gu install native-image
ARG MYUID=${MYUID:-0}
ARG GID=${GID:-}
RUN GID="${GID:-${MYUID}}"\
	; groupadd --non-unique --force --gid "${GID}" builduser\
	&& adduser --non-unique --home-dir /out --uid "${MYUID}" -g builduser\
	--password '*' builduser\
	&& id builduser
USER builduser
