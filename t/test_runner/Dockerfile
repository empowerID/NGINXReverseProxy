FROM ubuntu:xenial

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qqy update && \
    apt-get -qqy install libluajit-5.1-dev && \
    ln -s /usr/bin/luajit /usr/bin/lua && \
    apt-get -qqy install libmysqlclient-dev curl git unzip

RUN apt-get -qqy install luarocks && \
    luarocks install luasql-mysql MYSQL_INCDIR=/usr/include/mysql && \
    luarocks install busted

RUN apt-get -qqy install apt-transport-https ca-certificates software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get -qqy update && \
    apt-get -qqy install docker-ce && \
    apt-get -qqy install python python-dev python-distribute python-pip && \
    pip install --upgrade pip==9.0.3 && \
    pip install docker-compose

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV DEBIAN_FRONTEND teletype
