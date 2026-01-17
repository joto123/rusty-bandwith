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
	
	// Стартираме сървъра
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
	}
}

func handleCompress(w http.ResponseWriter, r *http.Request) {
	imageUrl := r.URL.Query().Get("url")
	qualityStr := r.URL.Query().Get("l")

if imageUrl == "" {
    w.WriteHeader(http.StatusOK)
    fmt.Fprint(w, "Proxy is online ✅")
    return
}

	// Парсване на качеството
	quality, err := strconv.Atoi(qualityStr)
	if err != nil || quality <= 0 {
		quality = 50 // Стойност по подразбиране
	}

	// 1. ПОДГОТОВКА НА ЗАЯВКАТА С ХЕДЪРИ
	client := &http.Client{}
	req, err := http.NewRequest("GET", imageUrl, nil)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	// Симулираме модерен браузър, за да избегнем блокировки от Twitter/Google/FB
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")
	req.Header.Set("Referer", "https://www.google.com/")

	// Изпълнение на заявката
	resp, err := client.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	// Ако източникът върне грешка (напр. 404 или 403)
	if resp.StatusCode != http.StatusOK {
		w.WriteHeader(resp.StatusCode)
		return
	}

	// Четем данните на изображението
	inputData, err := io.ReadAll(resp.Body)
	if err != nil || len(inputData) == 0 {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	// 2. ОБРАБОТКА И КОМПРЕСИЯ
	options := bimg.Options{
		Quality:       quality,
		Type:          bimg.WEBP,
		NoProfile:     true, // Премахва метаданните за пестене на място
		StripMetadata: true,
	}

	// Опит за обработка
	newImage, err := bimg.NewImage(inputData).Process(options)
	
	// 3. LOGIC ЗА ВРЪЩАНЕ НА РЕЗУЛТАТА
	w.Header().Set("Access-Control-Allow-Origin", "*")

	if err != nil {
		// FALLBACK: Ако компресията се провали, връщаме оригиналната картинка
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
		w.Header().Set("X-Proxy-Status", "original-fallback")
		w.Write(inputData)
		return
	}

	// Успешна компресия
	w.Header().Set("Content-Type", "image/webp")
	w.Header().Set("X-Proxy-Status", "compressed")
	w.Header().Set("X-Original-Size", strconv.Itoa(len(inputData)))
	w.Header().Set("X-Compressed-Size", strconv.Itoa(len(newImage)))
	w.Write(newImage)
}