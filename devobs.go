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
)

var username string

type Configuration struct {
	User     string
	Password string
	Database string
}

func init() {
	const (
		defaultUsername = "fabpot"
		usage = "The username, whose tweets are about to be collected and counted"
	)

	flag.StringVar(&username, "username", defaultUsername, usage)
}

func main() {
	flag.Parse()

	db := connectToMySqlDatabase()

	selectTweetsOfUserWithUsername(username, db)
	countTweetsOfUser(username, db)

	// "defer" keyword is described at https://tour.golang.org/flowcontrol/12
	defer db.Close()
}
func connectToMySqlDatabase() *sql.DB {
	err, configuration := parseConfiguration()

	dsn := configuration.User + string(`:`) + configuration.Password + string(`@/`) + configuration.Database
	db, err := sql.Open("mysql", dsn)
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

func countTweetsOfUser(username string, db *sql.DB) {
	countTweets, err := db.Prepare(`SELECT count(*) as Count ` +
		`FROM weaving_twitter_user_stream ` +
		`WHERE ust_full_name = ?`)
	var tweetCount int
	row := countTweets.QueryRow(username)
	err = row.Scan(&tweetCount)
	handleError(err)
	fmt.Printf(`%d tweets have been collected for "%s"`+"\n", tweetCount, username)
}

func selectTweetsOfUserWithUsername(username string, db *sql.DB) {
	selectTweets, err := db.Prepare(
		`SELECT 
			ust_full_name as Username,
			ust_text as Tweet,
			ust_api_document as "API source",
			CONCAT("https://twitter.com/", ust_full_name, "/status/", ust_status_id) as URL,
			ust_created_at as "Publication date" ` +
			`FROM weaving_twitter_user_stream ` +
			`WHERE ust_full_name = ? ` +
			`ORDER BY ust_created_at DESC`)
	handleError(err)

	rows, err := selectTweets.Query(username)
	columns, err := rows.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}
	type Message struct {
		Text string `json:text`
		Retweet_count  int `json:retweet_count`
		Favorite_count int `json:favorite_count`
	}
	var decodedApiDocument Message
	for rows.Next() {
		err = rows.Scan(scanArgs...)
		handleError(err)

		var value string
		for i, col := range values {
			value = string(col)

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
		fmt.Println("------------------")
	}
}

func handleError(err error) {
	if err != nil {
		log.Fatal(err.Error())
	}
}
