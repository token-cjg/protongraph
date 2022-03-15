FROM ubuntu:20.04

RUN apt-get update && apt-get install libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev libgl-dev -y
RUN apt-get install xauth -y
COPY builds/linux /usr/protongraph
WORKDIR /usr/protongraph
RUN echo 'sleep infinity' >> /bootstrap.sh
RUN chmod +x /bootstrap.sh

CMD /bootstrap.sh