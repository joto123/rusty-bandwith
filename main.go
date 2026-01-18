package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/h2non/bimg"
	"github.com/hashicorp/golang-lru/v2"
)

const (
	MaxImageSize = 15 * 1024 * 1024 // 15MB
	CacheSize    = 300              // Увеличено на 300 за по-добра ефективност
)

type CachedImage struct {
	Data        []byte
	ContentType string
}

var (
	httpClient = &http.Client{Timeout: 15 * time.Second}
	imgCache   *lru.Cache[string, CachedImage]
)

func main() {
	var err error
	imgCache, err = lru.New[string, CachedImage](CacheSize)
	if err != nil {
		fmt.Printf("Failed to setup cache: %v\n", err)
		os.Exit(1)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleCompress)

	fmt.Printf("Server starting on port %s with Advanced Optimizations...\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
	}
}

func handleCompress(w http.ResponseWriter, r *http.Request) {
	imageUrl := r.URL.Query().Get("url")
	qualityStr := r.URL.Query().Get("l")
	widthStr := r.URL.Query().Get("w") // Нов параметър за ширина

	if imageUrl == "" {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Proxy is online ✅")
		return
	}

	// Ключ за кеша (URL + Качество + Ширина)
	cacheKey := fmt.Sprintf("%s_q%s_w%s", imageUrl, qualityStr, widthStr)

	// 1. ПРОВЕРКА В КЕША
	if entry, ok := imgCache.Get(cacheKey); ok {
		setCacheHeaders(w)
		w.Header().Set("X-Proxy-Cache", "HIT")
		w.Header().Set("Content-Type", entry.ContentType)
		w.Write(entry.Data)
		return
	}

	quality, _ := strconv.Atoi(qualityStr)
	if quality < 1 || quality > 100 {
		quality = 60
	}

	width, _ := strconv.Atoi(widthStr)

	// 2. ИЗТЕГЛЯНЕ
	req, err := http.NewRequest("GET", imageUrl, nil)
	if err != nil {
		http.Error(w, "Invalid URL", http.StatusBadRequest)
		return
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
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

	inputData, err := io.ReadAll(io.LimitReader(resp.Body, MaxImageSize+1))
	if err != nil || len(inputData) > MaxImageSize {
		http.Error(w, "Image error or too large", http.StatusRequestEntityTooLarge)
		return
	}

	// 3. ОБРАБОТКА (Smart Resize + Compression)
	options := bimg.Options{
		Quality:       quality,
		Type:          bimg.WEBP,
		StripMetadata: true,
		NoProfile:     true,
		Embed:         true,
	}

	// Ако е зададена ширина, преоразмеряваме автоматично
	if width > 0 {
		options.Width = width
	}

	newImage, err := bimg.NewImage(inputData).Process(options)

	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	if err != nil {
		// Fallback към оригинала
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
		w.Header().Set("X-Proxy-Status", "original-fallback")
		w.Write(inputData)
		return
	}

	// 4. ЗАПИС В КЕША И ОТГОВОР
	finalEntry := CachedImage{Data: newImage, ContentType: "image/webp"}
	imgCache.Add(cacheKey, finalEntry)

	setCacheHeaders(w)
	w.Header().Set("X-Proxy-Cache", "MISS")
	w.Header().Set("X-Proxy-Status", "compressed")
	w.Header().Set("Content-Type", "image/webp")
	w.Write(newImage)
}

// Помощна функция за браузърно кеширане
func setCacheHeaders(w http.ResponseWriter) {
	w.Header().Set("Cache-Control", "public, max-age=604800, immutable") // 7 дни
	w.Header().Set("Access-Control-Allow-Origin", "*")
}