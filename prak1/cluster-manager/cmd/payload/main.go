package main

import (
    "fmt"
    "log"
    "net/http"
    "time"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        time.Sleep(50 * time.Millisecond)
        fmt.Fprint(w, "Payload service alive\n")
    })

    log.Println("Payload service started on :8082")
    log.Fatal(http.ListenAndServe(":8082", nil))
}