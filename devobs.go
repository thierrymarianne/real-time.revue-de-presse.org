package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"log"
)

func main() {
	db, err := sql.Open("mysql", "graystone:EXLh2aNHFJDzQrp@/weaving_dev")
	handleError(err)

	username := "jonathanbeurel"

	selectTweetsOfUserWithUsername(username, db)

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
	// "defer" keyword is described at https://tour.golang.org/flowcontrol/12
	defer db.Close()
	rows, err := selectTweets.Query(username)
	columns, err := rows.Columns()
	handleError(err)
	values := make([]sql.RawBytes, len(columns))
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}
	type Message struct {
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

			if i != 2 {
				fmt.Printf("%s: %s\n", columns[i], value)
			} else {
				apiDocument := []byte(value)

				isValid := json.Valid(apiDocument)
				if !isValid {
					handleError(errors.New("Invalid JSON"))
				}

				err := json.Unmarshal(apiDocument, &decodedApiDocument)

				if err != nil {
					handleError(err)
				}

				fmt.Printf("Retweet count : %d\n", decodedApiDocument.Retweet_count)
				fmt.Printf("Favorite count : %d\n", decodedApiDocument.Favorite_count)
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
