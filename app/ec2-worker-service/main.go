package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from Go EC2 worker service!")
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":80", nil)
}
