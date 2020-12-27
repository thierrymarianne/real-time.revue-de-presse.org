package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	_ "github.com/lib/pq"
	"github.com/remeh/sizedwaitgroup"
	_ "github.com/remeh/sizedwaitgroup"
	_ "github.com/ti/nasync"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"gopkg.in/zabawaba99/firego.v1"
	"io/ioutil"
	"log"
	_ "math"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

var username string
var readFromLocalDb bool
var listAggregateNames bool
var sinceDate string
var sinceAWeekAgo bool
var parallel bool
var quiet bool
var publishersListId string
var aggregateTweetPage int
var aggregateTweetLimit int

const (
	maxExecutionTimeInMinutes = 3 * 60
	tweetPerPage              = 100000
)

type Configuration struct {
	Firebase_url             string
	Read_user                string
	Read_password            string
	Read_database            string
	Read_protocol_host_port  string
	Write_user               string
	Write_password           string
	Write_database           string
	Write_protocol_host_port string
}

type Status struct {
	Id             string `json:"id_str"`
	Text           string `json:"full_text"`
	Retweet_count  int    `json:retweet_count`
	Favorite_count int    `json:favorite_count`
}

type Tweet struct {
	id           int
	publishedAt  string
	username     string
	json         string
	url          string
	tweet        string
	retweets     int
	favorites    int
	twitterId    string
	isRetweet    bool
	canBeRetweet bool
	checkedAt    string
}

// See when init function is run at https://stackoverflow.com/q/24790175/282073
func init() {
	const (
		defaultUsername    = "fabpot"
		usage              = "The username, whose tweets are about to be collected and counted"
		localDbUsage       = "The database from which tweets should be read"
		sinceTodayUsage    = "Store tweets collected over the current day"
		sinceLastWeekUsage = "Store tweets collected over the last week"
	)

	flag.StringVar(&username, "username", defaultUsername, usage)
	flag.BoolVar(&readFromLocalDb, "read-from-local-db", false, localDbUsage)
	flag.BoolVar(&sinceAWeekAgo, "since-last-week", false, sinceLastWeekUsage)
	flag.StringVar(&sinceDate, "since-date", formatTodayDate(), sinceTodayUsage)
}

func init() {
	const (
		defaultAggregateListing = false
		usage                   = "List aggregate names"
	)

	flag.BoolVar(&listAggregateNames, "aggregate", defaultAggregateListing, usage)
}

func init() {
	const (
		usage              = "The id of an publishers list, which tweets are to be printed out"
		defaultLimit       = 10
		limitUsage         = "Maximum tweets be collected"
		defaultPage        = 0
		pageUsage          = "Page from where tweets are collected from"
		defaultQuiet       = true
		quietUsage         = "Quiet mode"
		defaultParallel    = true
		parallelUsage      = "Run in parallel"
	)

	flag.StringVar(&publishersListId, "publishers-list-id", "89f6db28-4d4e-49dc-a2c6-b6bb0e7b12af", usage)
	flag.IntVar(&aggregateTweetLimit, "limit", defaultLimit, limitUsage)
	flag.IntVar(&aggregateTweetPage, "page", defaultPage, pageUsage)
	flag.BoolVar(&quiet, "quiet", defaultQuiet, quietUsage)
	flag.BoolVar(&parallel, "in-parallel", defaultParallel, parallelUsage)
}

func main() {
	flag.Parse()

	err, configuration := parseConfiguration()
	handleError(err)

	db := connectToDatabase(configuration)

	// "defer" keyword is described at https://tour.golang.org/flowcontrol/12
	defer db.Close()

	firebase := connectToFirebase(configuration)

	queryTweets(db, firebase, publishersListId, true, aggregateTweetPage, aggregateTweetLimit, `DESC`)
	queryTweets(db, firebase, publishersListId, false, aggregateTweetPage, aggregateTweetLimit, `DESC`)
}

func removeStatuses(firebase *firego.Firebase) {
	ref, err := firebase.Ref("highlights")
	handleError(err)

	err = ref.Remove()
	handleError(err)
}

func formatTodayDate() string {
	today := time.Now()

	return today.Format("2006-01-02")
}

func connectToDatabase(configuration Configuration) *sql.DB {
	dsn := "postgres://" + configuration.Read_user + string(`:`) + configuration.Read_password +
		`@` + configuration.Read_protocol_host_port + `/` +
		configuration.Read_database + `?sslmode=disable`
	db, err := sql.Open("postgres", dsn)
	handleError(err)

	return db
}

func connectToFirebase(configuration Configuration) *firego.Firebase {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	handleError(err)

	file, err := ioutil.ReadFile(dir + `/../config.firebase.json`)
	handleError(err)

	conf, err := google.JWTConfigFromJSON(file, "https://www.googleapis.com/auth/userinfo.email",
		"https://www.googleapis.com/auth/firebase.database")
	handleError(err)

	firebase := firego.New(configuration.Firebase_url, conf.Client(oauth2.NoContext))

	return firebase
}

func parseConfiguration() (error, Configuration) {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	handleError(err)

	file, err := os.Open(dir + `/../config.json`)
	handleError(err)

	decoder := json.NewDecoder(file)
	configuration := Configuration{}
	err = decoder.Decode(&configuration)
	handleError(err)

	return err, configuration
}

func queryTweets(
	db *sql.DB,
	firebase *firego.Firebase,
	publishersListId string,
	includeRetweets bool,
	page int,
	limit int,
	sortingOrder string) {
	totalHighlights := countHighlights(db, limit)

	constraintOnRetweetStatus := ""
	if !includeRetweets {
		constraintOnRetweetStatus = "AND h.is_retweet = false"
	}

	var query string
	query = `
		SELECT
		CONCAT('https://twitter.com/', ust_full_name, '/status/', ust_status_id) as url,
		s.ust_full_name as username,
		s.ust_text as tweet,
		s.ust_created_at as publicationDate,
		s.ust_api_document as Json,
		MAX(COALESCE(p.total_retweets, h.total_retweets)) retweets,
		MAX(COALESCE(p.total_favorites, h.total_retweets)) favorites,
		s.ust_id as id,
		s.ust_status_id as statusId,
		h.is_retweet,
		s.ust_created_at as checkedAt
		FROM highlight h
		INNER JOIN weaving_status s
		ON s.ust_id = h.status_id
		` + sinceWhen() + `
		` + constraintOnRetweetStatus + `
		INNER JOIN publishers_list
		ON h.aggregate_id = publishers_list.id
		AND publishers_list.public_id = $2
		LEFT JOIN status_popularity p
		ON p.status_id = h.status_id
		-- Prevent publications by deleted members from being fetched
		WHERE
		h.member_id NOT IN (
			SELECT usr_id
			FROM weaving_user member,
			publishers_list publication_list
			WHERE publication_list.deleted_at IS NOT NULL
			AND member.usr_twitter_username = publication_list.screen_name
			AND publication_list.screen_name IS NOT NULL
		) 
		GROUP BY 
		h.status_id,
		CONCAT('https://twitter.com/', ust_full_name, '/status/', ust_status_id),
		s.ust_full_name,
		s.ust_text,
		s.ust_created_at,
		s.ust_api_document,
		s.ust_id,
		h.is_retweet,
		s.ust_created_at
		ORDER BY retweets ` + sortingOrder

	if limit > 0 {
		query = query + ` OFFSET $3 LIMIT $4`
	}

	selectTweets, err := db.Prepare(query)
	handleError(err)

	rows := selectTweetsWindow(limit, page, selectTweets, publishersListId, err)

	migrateStatusesToFirebaseApp(rows, firebase, publishersListId, includeRetweets, totalHighlights)
}

func selectTweetsWindow(limit int, page int, selectTweets *sql.Stmt, publishersListId string, err error) *sql.Rows {
	if limit > 0 {
		offset := page * tweetPerPage
		itemsPerPage := limit
		rows, err := selectTweets.Query(sinceDate, publishersListId, offset, itemsPerPage)
		handleError(err)

		return rows
	}

	rows, err := selectTweets.Query(sinceDate, publishersListId)
	handleError(err)

	return rows
}

func countHighlights(db *sql.DB, limit int) int {
	var totalHighlights int

	var query string
	query = `
		SELECT COUNT(*) highlights
		FROM highlight h
		INNER JOIN weaving_status s
		ON 
		s.ust_id = h.status_id
		` + sinceWhen() + `
		INNER JOIN publishers_list
		ON h.aggregate_id = publishers_list.id
		AND publishers_list.public_id = $2
		LEFT JOIN status_popularity p
		ON p.status_id = h.status_id`

	statement, err := db.Prepare(query)
	handleError(err)

	highlightsCount, err := statement.Query(sinceDate, publishersListId)
	handleError(err)

	columns, err := highlightsCount.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	scanArgs[0] = &values[0]

	highlightsCount.Next()
	err = highlightsCount.Scan(scanArgs...)
	handleError(err)

	for _, col := range values {
		totalHighlights, err = strconv.Atoi(string(col))
		handleError(err)
	}

	fmt.Printf("Found %d matching higlights on %s\n", totalHighlights, sinceDate)

	if limit > -1 && limit < totalHighlights {
		return limit
	}

	return totalHighlights
}

func sinceWhen() string {
	if sinceAWeekAgo {
		return `AND s.ust_created_at::timestamp - '1 HOUR'::interval > NOW()::now - '7 DAYS::interval'`
	}

	return `AND (h.publication_date_time::timestamp - '1 HOUR'::interval)::date = $1`
}

func migrateStatusesToFirebaseApp(
	rows *sql.Rows,
	firebase *firego.Firebase,
	publishersListId string,
	includeRetweets bool,
	totalHighlights int) {
	columns, err := rows.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}

	rowIndex := 0

	tweets := make([]Tweet, totalHighlights)

	for rows.Next() {
		err = rows.Scan(scanArgs...)
		handleError(err)

		var decodedApiDocument Status
		var value string
		var tweet Tweet

		tweet.canBeRetweet = includeRetweets

		for i, col := range values {
			value = string(col)

			switch {
			case i == 0:
				tweet.url = value
			case i == 1:
				tweet.username = value
			case i == 2:
				tweet.tweet = value
			case i == 3:
				tweet.publishedAt = value
			case i == 4:
				tweet.json = value
			case i == 5:
				tweet.retweets, err = strconv.Atoi(value)
			case i == 6:
				tweet.favorites, err = strconv.Atoi(value)
			case i == 7:
				tweet.id, err = strconv.Atoi(value)
			case i == 8:
				tweet.twitterId = value
			case i == 9:
				tweet.isRetweet = false
				if value == "1" {
					tweet.isRetweet = true
				}
			case i == 10:
				tweet.checkedAt = value
			}

			tweets[rowIndex] = tweet

			if quiet {
				continue
			}

			if i != 4 && i != 1 {
				fmt.Printf("%s: %s\n", columns[i], value)
			} else if i == 4 {
				apiDocument := []byte(value)

				isValid := json.Valid(apiDocument)
				if !isValid {
					fmt.Printf("%s for status \"%s\"", "Invalid JSON", string(values[8]))
					continue
				}

				err := json.Unmarshal(apiDocument, &decodedApiDocument)
				if err != nil {
					handleError(err)
				}
			}
		}

		if quiet && rowIndex%1000 == 0 {
			fmt.Printf(`.`)
		}

		rowIndex++

		if !quiet {
			fmt.Println("------------------")
		}
	}

	fmt.Printf("\n")

	var statusType string
	statusType = "status"
	if includeRetweets {
		statusType = "retweet"
	}

	path := "highlights/" + publishersListId + "/" + sinceDate + "/" + statusType + "/"
	fmt.Printf("About to remove %s\n", path)
	statusRef, err := firebase.Ref(path)
	handleError(err)

	err = statusRef.Remove()
	handleError(err)

	if parallel {
		swg := sizedwaitgroup.New(100)

		for index, tweet := range tweets {
			swg.Add()

			go (func(tweet Tweet, index int) {
				defer swg.Done()
				addToFirebaseApp(tweet, index, firebase, publishersListId)
			})(tweet, index)
		}

		swg.Wait()

		return
	}

	for index, tweet := range tweets {
		addToFirebaseApp(tweet, index, firebase, publishersListId)
	}
}

func addToFirebaseApp(tweet Tweet, index int, firebase *firego.Firebase, publishersListId string) {
	var decodedApiDocument Status
	apiDocument := []byte(tweet.json)

	isValid := json.Valid(apiDocument)
	if !isValid {
		fmt.Printf("%s for status \"%s\"", "Invalid JSON", tweet.twitterId)
		return
	}

	err := json.Unmarshal(apiDocument, &decodedApiDocument)
	handleError(err)

	statusId := decodedApiDocument.Id

	var statusType string
	statusType = "status"
	if tweet.canBeRetweet {
		statusType = "retweet"
	}

	statusRef, err := firebase.Ref("highlights/" + publishersListId + "/" + sinceDate + "/" +
		statusType + "/" + statusId)
	handleError(err)

	status := map[string]interface{}{
		"id":             tweet.id,
		"twitterId":      tweet.twitterId,
		"username":       tweet.username,
		"text":           tweet.tweet,
		"url":            tweet.url,
		"json":           tweet.json,
		"publishedAt":    tweet.publishedAt,
		"checkedAt":      tweet.checkedAt,
		"isRetweet":      tweet.isRetweet,
		"twitter_id":     decodedApiDocument.Id,
		"totalRetweets":  tweet.retweets,
		"totalFavorites": tweet.favorites,
	}

	err = statusRef.Update(status)
	if err != nil {
		fmt.Printf("%s \"%s\" indexed at %d\n", "Could not migrate status", tweet.twitterId, index)
		fmt.Printf("(%s)", err)
		return
	}

	fmt.Printf("%s \"%s\" indexed at %d\n", "Migrated status", tweet.twitterId, index)
}

func handleError(err error) {
	if err != nil {
		log.Fatal(err.Error())
	}
}
