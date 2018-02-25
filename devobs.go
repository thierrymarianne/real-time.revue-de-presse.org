package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"log"
	"os"
	"path/filepath"
	"strings"
	"strconv"
	"time"
)

var username string
var listAggregateNames bool
var quiet bool
var aggregateId int
var aggregateTweetPage int
var aggregateTweetLimit int
var writeDb *sql.DB

const (
	maxExecutionTimeInMinutes = 60
	tweetPerPage = 50000
)

type Configuration struct {
	Read_user     string
	Read_password string
	Read_database string
	Write_user     string
	Write_password string
	Write_database string
	Write_protocol_host_port string
}

type Tweet struct {
	id int
	publishedAt string
	username string
	json string
}

// See when init function is run at https://stackoverflow.com/q/24790175/282073
func init() {
	const (
		defaultUsername = "fabpot"
		usage = "The username, whose tweets are about to be collected and counted"
	)

	flag.StringVar(&username, "username", defaultUsername, usage)
}

func init() {
	const (
		defaultAggregateListing = false
		usage = "List aggregate names"
	)

	flag.BoolVar(&listAggregateNames, "aggregate", defaultAggregateListing, usage)
}

func init() {
	const (
		defaultAggregateId = 0
		usage = "The id of an aggregate, which tweets are to be printed out"
		defaultLimit = 1000
		limitUsage = "Maximum tweets be collected"
		defaultPage = 0
		pageUsage = "Page from where tweets are collected from"
		defaultQuiet = false
		quietUsage = "Quiet mode"
	)

	flag.IntVar(&aggregateId, "aggregate-id", defaultAggregateId, usage)
	flag.IntVar(&aggregateTweetLimit, "limit", defaultLimit, limitUsage)
	flag.IntVar(&aggregateTweetPage, "page", defaultPage, pageUsage)
	flag.BoolVar(&quiet, "quiet", defaultQuiet, quietUsage)
}

func main() {
	flag.Parse()

	db := connectToMySqlDatabase()

	// "defer" keyword is described at https://tour.golang.org/flowcontrol/12
	defer db.Close()

	if aggregateId != 0 {
		selectTweetsOfAggregate(aggregateId, db)

		if aggregateTweetLimit == -1 {
			time.Sleep(maxExecutionTimeInMinutes * 60 * time.Second)
		}

		return
	}

	if listAggregateNames {
		selectAggregates(db)

		return
	}

	selectTweetsOfUser(username, db)
	countTweetsOfUser(username, db)
}

func connectToMySqlDatabase() *sql.DB {
	err, configuration := parseConfiguration()

	dsn := configuration.Read_user + string(`:`) + configuration.Read_password + string(`@/`) +
		configuration.Read_database + `?charset=utf8mb4`
	db, err := sql.Open("mysql", dsn)
	handleError(err)

	dsn = configuration.Write_user + string(`:`) + configuration.Write_password +
		string(`@` + configuration.Write_protocol_host_port +`/`) + configuration.Write_database +
			`?charset=utf8mb4`
	writeDb, err = sql.Open("mysql", dsn)
	handleError(err)

	return db
}

func parseConfiguration() (error, Configuration) {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	handleError(err)

	file, err := os.Open(dir + `/config.json`)
	handleError(err)

	decoder := json.NewDecoder(file)
	configuration := Configuration{}
	err = decoder.Decode(&configuration)
	handleError(err)

	return err, configuration
}

func selectAggregates(db *sql.DB) {
	rows, err := db.Query(`SELECT id as Id, name as Name FROM weaving_aggregate`)

	columns, err := rows.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}

	for rows.Next() {
		err = rows.Scan(scanArgs...)
		handleError(err)

		var value string
		for i, col := range values {
			value = string(col)
			fmt.Printf("%s", strings.Replace(value, `user :: `, ``, -1))

			if i == 0 {
				fmt.Printf("\t")

				continue
			}

			fmt.Printf("\n")
		}
	}
}

func countTweetsOfUser(username string, db *sql.DB) {
	countTweets, err := db.Prepare(`
		SELECT count(*) as Count 
		FROM weaving_twitter_user_stream 
		WHERE ust_full_name = ?`)
	var tweetCount int
	row := countTweets.QueryRow(username)
	err = row.Scan(&tweetCount)
	handleError(err)
	fmt.Printf("\n" + `%d tweets have been collected for "%s"`+"\n", tweetCount, username)
}

func selectTweetsOfUser(username string, db *sql.DB) {
	selectTweets, err := db.Prepare(`
		SELECT 
		ust_full_name as Username,
		ust_text as Tweet,
		ust_api_document as "API source",
		CONCAT("https://twitter.com/", ust_full_name, "/status/", ust_status_id) as URL,
		ust_created_at as "Publication date",
		ust_id as Id			
		FROM weaving_twitter_user_stream 
		WHERE ust_full_name = ? 
		ORDER BY ust_created_at DESC`)
	handleError(err)

	rows, err := selectTweets.Query(username)
	handleError(err)

	printTweets(rows, db, 0)
}

func selectTweetsOfAggregate(aggregateId int, db *sql.DB) {
	if aggregateTweetLimit != -1 {
		queryTweets(db, aggregateId, aggregateTweetPage, aggregateTweetLimit, `DESC`)

		return
	}

	countTweets, err := db.Prepare(`
		SELECT count(*) as Count 
		FROM weaving_status_aggregate sa
		WHERE sa.aggregate_id = ?`)

	var tweetCount int
	row := countTweets.QueryRow(aggregateId)
	err = row.Scan(&tweetCount)
	handleError(err)

	offsets := tweetCount / tweetPerPage
	pageRange := make([]int, offsets + 1)

	for page := range pageRange {
		go func (page int) {
			queryTweets(db, aggregateId, page, tweetPerPage, `ASC`)
		}(page)

		go func (page int) {
			queryTweets(db, aggregateId, page, tweetPerPage, `DESC`)
		}(page)
	}
}

func queryTweets(db *sql.DB, aggregateId int, page int, limit int, sortingOrder string) {
	selectTweets, err := db.Prepare(`
		SELECT 
		ust_full_name as Username,
		ust_text as Tweet,
		ust_api_document as "API source",
		CONCAT("https://twitter.com/", ust_full_name, "/status/", ust_status_id) as URL,
		ust_created_at as "Publication date",
		ust_id as Id
		FROM weaving_status_aggregate sa, weaving_twitter_user_stream s
		WHERE s.ust_id = sa.status_id 
		AND sa.aggregate_id = ? 
		ORDER BY sa.status_id ` + sortingOrder + ` LIMIT ?,?`)
	handleError(err)

	offset := page * tweetPerPage
	itemsPerPage := limit / 2 + 1
	rows, err := selectTweets.Query(aggregateId, offset, itemsPerPage)
	handleError(err)

	printTweets(rows, db, offset)

	if aggregateTweetLimit == -1 {
		fmt.Printf("Inserted %d tweets of page #%d from offset %d with direction %s\n",
			itemsPerPage, page, offset, sortingOrder)
	}
}

func printTweets(rows *sql.Rows, db *sql.DB, offset int) {
	type Message struct {
		Text string `json:text`
		Retweet_count  int `json:retweet_count`
		Favorite_count int `json:favorite_count`
	}
	var decodedApiDocument Message

	columns, err := rows.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}

	insertTweet, err := writeDb.Prepare(`
		REPLACE INTO tweet (id, username, published_at, json)
		VALUES (?, ?, ?, ?)`)
	handleError(err)

	rowIndex := 1

	for rows.Next() {
		err = rows.Scan(scanArgs...)
		handleError(err)

		var value string
		var tweet Tweet

		for i, col := range values {
			value = string(col)

			switch {
				case i == 0:
					tweet.username = value
				case i == 2:
					tweet.json = value
				case i == 4:
					tweet.publishedAt = value
				case i == 5:
					tweet.id, err = strconv.Atoi(value)
					handleError(err)
			}

			if (quiet) {
				continue
			}

			if i != 2 && i != 1 {
				fmt.Printf("%s: %s\n", columns[i], value)
			} else if i != 1 {
				apiDocument := []byte(value)

				isValid := json.Valid(apiDocument)
				if !isValid {
					handleError(errors.New("Invalid JSON"))
				}

				err := json.Unmarshal(apiDocument, &decodedApiDocument)

				if err != nil {
					handleError(err)
				}

				fmt.Printf("Text : %q\n", decodedApiDocument.Text)
				fmt.Printf("Retweet count : %d \n", decodedApiDocument.Retweet_count)
				fmt.Printf("Favorite count : %d \n", decodedApiDocument.Favorite_count)
			}
		}

		if quiet && rowIndex % 1000 == 0 {
			fmt.Printf(`.` + "\n")
		}

		rowIndex++

		if (!quiet) {
			fmt.Println("------------------")
		}

		insertTweetIntoWriteDatabase(tweet, insertTweet, offset)
	}
}

func insertTweetIntoWriteDatabase(tweet Tweet, statement *sql.Stmt, offset int) {
	result, err := statement.Exec(
		tweet.id,
		tweet.username,
		tweet.publishedAt,
		tweet.json)
	handleError(err)

	if quiet {
		affectedRows, err := result.RowsAffected()
		handleError(err)

		inserts := make([]int, affectedRows)

		for _ = range inserts {
			fmt.Printf(`%d` + "\n", offset)
		}
	}
}

func handleError(err error) {
	if err != nil {
		log.Fatal(err.Error())
	}
}
