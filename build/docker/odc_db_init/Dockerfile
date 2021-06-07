FROM postgres:10-alpine

# This is OK since this container will only be used in a docker-compose
# environment using its own Docker network - all for use by 1 user.
ARG POSTGRES_DB
ARG POSTGRES_USER
ARG POSTGRES_PASSWORD
ENV POSTGRES_DB=${POSTGRES_DB} \
    POSTGRES_USER=${POSTGRES_USER} \
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

COPY data data
