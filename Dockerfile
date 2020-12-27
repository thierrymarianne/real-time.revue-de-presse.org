FROM golang:1.15-buster

WORKDIR /go/src/app

COPY . .
COPY ./config.firebase.json /go/src/app/config.firebase.json
COPY ./config.json /go/src/app/config.json

RUN go get -d -v .
RUN go install -v .
RUN go build -o /go/src/app/bin/devobs-realtime-database

CMD ["bin/devobs-realtime-database"]