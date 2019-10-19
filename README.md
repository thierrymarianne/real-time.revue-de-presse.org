# DevObs

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
go build github.com/devobs-realtime-database
```

## Installation

```
# Install project from repository clone in file system
go install github.com/devobs-realtime-database
```

## Run

```
# Migrate statuses from the first aggregate
export aggregate_id="__FILL_ME_WITH_A_NUMBER__"
./devobs-realtime-database -aggregate-id="${aggregate_id}" -since-date=2019-01-02 -in-parallel=true
```

## References

[Firebase Admin SDK](https://console.firebase.google.com)
