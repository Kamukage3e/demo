#!/bin/bash
sudo apt-get update
sudo apt-get install -y golang-go
cd /home/ubuntu
cat <<EOF > main.go
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
EOF
nohup go run main.go > /var/log/goweb.log 2>&1 &
