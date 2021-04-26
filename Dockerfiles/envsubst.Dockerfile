
FROM alpine

RUN apk add --update \
        libintl \
    && apk add --virtual \
        build_deps \
        gettext