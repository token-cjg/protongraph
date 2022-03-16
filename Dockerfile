FROM ubuntu:20.04

RUN apt-get update && apt-get install libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev libgl-dev -y
#RUN apt-get install xauth -y
#RUN DEBIAN_FRONTEND=noninteractive apt-get install xorg -yq
#RUN apt-get install openbox -y
COPY builds/server /usr/protongraph
WORKDIR /usr/protongraph
RUN echo 'sleep infinity' >> /bootstrap.sh
RUN chmod +x /bootstrap.sh

#EXPOSE 6000
#CMD ./headless
CMD /bootstrap.sh