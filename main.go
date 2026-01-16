package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"github.com/h2non/bimg"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleCompress)
	fmt.Printf("Server starting on port %s...\n", port)
	http.ListenAndServe(":"+port, nil)
}

func handleCompress(w http.ResponseWriter, r *http.Request) {
	imageUrl := r.URL.Query().Get("url")
	qualityStr := r.URL.Query().Get("l")

	if imageUrl == "" {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Provide a 'url' parameter.")
		return
	}

	quality, err := strconv.Atoi(qualityStr)
	if err != nil || quality <= 0 {
		quality = 50
	}

	// Използваме клиент с хедъри, за да не ни блокират социалните мрежи
	client := &http.Client{}
	req, _ := http.NewRequest("GET", imageUrl, nil)
	
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")

	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	inputData, err := io.ReadAll(resp.Body)
	if err != nil || len(inputData) == 0 {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	options := bimg.Options{
		Quality:       quality,
		Type:          bimg.WEBP,
		NoProfile:     true,
		StripMetadata: true,
	}

	newImage, err := bimg.NewImage(inputData).Process(options)
	if err != nil {
		// Ако bimg не успее (непознат формат), връщаме оригиналната картинка
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
		w.Write(inputData)
		return
	}

	w.Header().Set("Content-Type", "image/webp")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("X-Original-Size", strconv.Itoa(len(inputData)))
	w.Header().Set("X-Compressed-Size", strconv.Itoa(len(newImage)))
	w.Write(newImage)
}