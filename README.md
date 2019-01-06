# Daily Press Review

## Dependencies

```
# Get dependency
go get -u github.com/go-sql-driver/mysql
go get -u cloud.google.com/go/compute/metadata
go get -u golang.org/x/oauth2
go get -u gopkg.in/zabawaba99/firego.v1
go get -u github.com/ti/nasync
```

## Build


```
# Build application
go build github.com/daily-press-review-golang
```

## Installation

```
# Install project from repository clone in file system
go install github.com/daily-press-review-golang
```

## Run

```
# Migrate statuses from the first aggregate
./daily-press-review-golang -aggregate-id=1 -since-date=2019-01-02 -in-parallel=true
```

```
How to migrate a year?

```

## References

[https://console.firebase.google.com/u/1/project/weaving-the-web-6fe11/settings/serviceaccounts/adminsdk](Firebase Admin SDK)
