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
	qualityStr := r.URL.Query().Get("l") // 'l' е параметърът на Bandwidth Hero

	if imageUrl == "" {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Please provide a 'url' parameter.")
		return
	}

	quality, err := strconv.Atoi(qualityStr)
	if err != nil || quality == 0 {
		quality = 50 // Качество по подразбиране
	}

	// Изтегляне на оригиналното изображение
	resp, err := http.Get(imageUrl)
	if err != nil {
		http.Redirect(w, r, imageUrl, http.StatusFound)
		return
	}
	defer resp.Body.Close()

	inputData, _ := io.ReadAll(resp.Body)

	// Компресия чрез bimg (използва libvips под капака)
	options := bimg.Options{
		Quality: quality,
		Type:    bimg.WEBP, // Винаги конвертираме към WebP за макс икономия
	}

	newImage, err := bimg.NewImage(inputData).Process(options)
	if err != nil {
		http.Redirect(w, r, imageUrl, http.StatusFound)
		return
	}

	w.Header().Set("Content-Type", "image/webp")
	w.Header().Set("X-Original-Size", strconv.Itoa(len(inputData)))
	w.Header().Set("X-Compressed-Size", strconv.Itoa(len(newImage)))
	w.Write(newImage)
}