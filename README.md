# Daily Press Review

```
# Get dependency
go get -u github.com/go-sql-driver/mysql
```

```
# Install project from repository clone in file system
go install github.com/weavingtheweb/devobs
```

```
/usr/local/go/bin/go build src/github.com/weavingtheweb/devobs-go/main.go
```

```
# Install binary
go install github.com/weavingtheweb/devobs-go
```

```
# Output statuses related to aggregate having id #1
go run devobs.go -aggregate-id=1 -limit=-1

# or

./bin/devobs.go -aggregate-id=1 -limit=-1
```

```
./bin/devobs -username=VitalikButerin -since-last-week=1 | less
```
