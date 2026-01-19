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
	MaxImageSize = 5 * 1024 * 1024 // 5MB (Защита от OOM)
	CacheSize    = 50              // 50 изображения в RAM (Защита от OOM)
)

type CachedImage struct {
	Data        []byte
	ContentType string
}

var (
	httpClient = &http.Client{Timeout: 10 * time.Second}
	imgCache   *lru.Cache[string, CachedImage]
)

func main() {
	// CPU Оптимизация: Казваме на vips да не претоварва процесора
	bimg.VipsConcurrencySet(1)
	bimg.VipsCacheSetMax(0)

	var err error
	imgCache, err = lru.New[string, CachedImage](CacheSize)
	if err != nil {
		os.Exit(1)
	}

	port := os.Getenv("PORT")
	if port == "" { port = "8080" }

	http.HandleFunc("/", handleCompress)
	fmt.Printf("Server starting on port %s (Alpine + Cache)...\n", port)
	http.ListenAndServe(":"+port, nil)
}

func handleCompress(w http.ResponseWriter, r *http.Request) {
	imageUrl := r.URL.Query().Get("url")
	if imageUrl == "" {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Proxy is online ✅")
		return
	}

	qualityStr := r.URL.Query().Get("l")
	widthStr := r.URL.Query().Get("w")
	cacheKey := fmt.Sprintf("%s_%s_%s", imageUrl, qualityStr, widthStr)

	// --- ПРОВЕРКА В КЕША ---
	if entry, ok := imgCache.Get(cacheKey); ok {
		w.Header().Set("X-Proxy-Cache", "HIT")
		w.Header().Set("Cache-Control", "public, max-age=604800")
		w.Header().Set("Content-Type", entry.ContentType)
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Write(entry.Data)
		return
	}

	// --- ИЗТЕГЛЯНЕ И ОБРАБОТКА ---
	resp, err := httpClient.Get(imageUrl)
	if err != nil || resp.StatusCode != http.StatusOK {
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	inputData, err := io.ReadAll(io.LimitReader(resp.Body, MaxImageSize+1))
	if err != nil || len(inputData) > MaxImageSize {
		w.WriteHeader(http.StatusRequestEntityTooLarge)
		return
	}

	quality, _ := strconv.Atoi(qualityStr)
	if quality < 1 { quality = 50 }
	width, _ := strconv.Atoi(widthStr)

	options := bimg.Options{
		Quality: quality,
		Type: bimg.WEBP,
		Width: width,
		StripMetadata: true,
		NoProfile: true,
	}

	newImage, err := bimg.NewImage(inputData).Process(options)
	if err != nil {
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
		w.Write(inputData)
		return
	}

	// --- ЗАПИС В КЕША ---
	imgCache.Add(cacheKey, CachedImage{Data: newImage, ContentType: "image/webp"})

	w.Header().Set("X-Proxy-Cache", "MISS")
	w.Header().Set("Content-Type", "image/webp")
	w.Header().Set("Cache-Control", "public, max-age=604800")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Write(newImage)
}