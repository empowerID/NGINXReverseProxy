# test suite

### Dependencies

The only dependency to run this test suite is docker-ce.

If you have older Docker installer - remove it (Debian based distro considered):

`sudo apt-get remove docker docker-engine docker.io`

The simplest way to install docker-ce is as below (old distros may be not supported):

`curl http://get.docker.com/ | sudo sh`

### How to run

Run the whole test suite:

`NGINXReverseProxy/t/run.sh`

You may specify a single test to run:

`NGINXReverseProxy/t/run.sh config`

When you will run the test first time it will take some minutes to pull all required Docker images.
Please be patient ;-)

