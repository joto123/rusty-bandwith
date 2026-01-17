package main

import (
    "fmt"
    "io"
    "net/http"
    "os"
    "strconv"
    "time"

    "github.com/h2non/bimg"
)

const (
    MaxImageSize = 15 * 1024 * 1024 // 15MB
)

var httpClient = &http.Client{
    Timeout: 12 * time.Second,
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    http.HandleFunc("/", handleCompress)

    fmt.Printf("Server starting on port %s...\n", port)
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        fmt.Printf("Failed to start server: %v\n", err)
    }
}

func handleCompress(w http.ResponseWriter, r *http.Request) {
    imageUrl := r.URL.Query().Get("url")
    qualityStr := r.URL.Query().Get("l")

    if imageUrl == "" {
        w.WriteHeader(http.StatusOK)
        fmt.Fprint(w, "Proxy is online")
        return
    }

    // Parse quality
    quality, err := strconv.Atoi(qualityStr)
    if err != nil || quality < 1 || quality > 100 {
        quality = 60
    }

    // Prepare request
    req, err := http.NewRequest("GET", imageUrl, nil)
    if err != nil {
        http.Error(w, "Bad request", http.StatusBadRequest)
        return
    }

    req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/*,*/*;q=0.8")
    req.Header.Set("Referer", "https://www.google.com/")

    resp, err := httpClient.Do(req)
    if err != nil {
        http.Error(w, "Upstream error", http.StatusServiceUnavailable)
        return
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        w.WriteHeader(resp.StatusCode)
        return
    }

    // Limit reader to avoid OOM
    limitedReader := io.LimitReader(resp.Body, MaxImageSize+1)
    inputData, err := io.ReadAll(limitedReader)
    if err != nil {
        http.Error(w, "Read error", http.StatusInternalServerError)
        return
    }

    if len(inputData) > MaxImageSize {
        http.Error(w, "Image too large", http.StatusRequestEntityTooLarge)
        return
    }

    // Compression options
    options := bimg.Options{
        Quality:       quality,
        Type:          bimg.WEBP,
        StripMetadata: true,
        NoProfile:     true,
    }

    newImage, err := bimg.NewImage(inputData).Process(options)

    w.Header().Set("Access-Control-Allow-Origin", "*")

    if err != nil {
        // Fallback to original
        w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
        w.Header().Set("X-Proxy-Status", "original-fallback")
        w.Write(inputData)
        return
    }

    // Success
    w.Header().Set("Content-Type", "image/webp")
    w.Header().Set("X-Proxy-Status", "compressed")
    w.Header().Set("X-Original-Size", strconv.Itoa(len(inputData)))
    w.Header().Set("X-Compressed-Size", strconv.Itoa(len(newImage)))
    w.Write(newImage)
}
