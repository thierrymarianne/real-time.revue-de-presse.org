# Daily Press Review

```
# Get dependency
go get -u github.com/go-sql-driver/mysql
go get -u cloud.google.com/go/compute/metadata
go get -u golang.org/x/oauth2
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

## References

[https://console.firebase.google.com/u/1/project/weaving-the-web-6fe11/settings/serviceaccounts/adminsdk](Firebase Admin SDK)