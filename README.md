# Daily Press Review

```
# Get dependency
go get -u github.com/go-sql-driver/mysql
```

```
# Build application
go build github.com/daily-press-review-golang
```

```
# Install project from repository clone in file system
go install github.com/daily-press-review-golang
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
