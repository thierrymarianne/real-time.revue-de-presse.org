package main

import (
	"fmt"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
)

func handleError(err error) {
	if err != nil {
		panic(err.Error())
	}
}

func main() {
	db, err := sql.Open("mysql", "graystone:EXLh2aNHFJDzQrp@/weaving_dev")
	handleError(err)

	rows, err := db.Query(
		`SELECT ust_full_name as Username, ust_text as Tweet, ust_api_document as "API source", ust_created_at as "Publication date" ` +
		 `FROM weaving_twitter_user_stream ` +
		 `WHERE ust_full_name = "jonathanbeurel"` +
		 `ORDER BY ust_created_at DESC`)
	handleError(err)

	// "defer" keyword is described at https://tour.golang.org/flowcontrol/12
	defer db.Close()

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
			fmt.Println(columns[i], ":", value)
		}
		fmt.Println("------------------")
	}
}