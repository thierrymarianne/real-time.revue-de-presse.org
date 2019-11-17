FROM golang:1.13.4-buster

WORKDIR /go/src/app

COPY . .
COPY ./config.firebase.json /go/config.firebase.json
COPY ./config.json /go/config.json

RUN go get -d -v .
RUN go install -v .
RUN go build

CMD ["devobs-realtime-database"]