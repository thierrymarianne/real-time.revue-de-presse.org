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

```
# Migrate statuses by relying on containerization
for day in `seq 1 9`; do
    export date='2019-02-0'"${day}" &&
    for aggregate_id in 858;
        export AGGREGATE_ID=$aggregate_id SINCE_DATE=$date && make run-worker;
    done;
done
```

## References

[Firebase Admin SDK](https://console.firebase.google.com)
