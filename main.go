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

    // 1. СЪЗДАВАНЕ НА КЛИЕНТ С HEADERS
    client := &http.Client{}
    req, _ := http.NewRequest("GET", imageUrl, nil)
    
    // Симулираме Chrome на Windows, за да не ни блокират Twitter/FB
    req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")

    resp, err := client.Do(req)
    if err != nil || resp.StatusCode != http.StatusOK {
        // Ако не можем да вземем картинката, не правим Redirect (заради CSP), 
        // а връщаме грешка или празна картинка
        w.WriteHeader(http.StatusServiceUnavailable)
        return
    }
    defer resp.Body.Close()

    inputData, err := io.ReadAll(resp.Body)
    if err != nil || len(inputData) == 0 {
        w.WriteHeader(http.StatusInternalServerError)
        return
    }

    // 2. ОБРАБОТКА С BIMG
    options := bimg.Options{
        Quality:       quality,
        Type:          bimg.WEBP,
        NoProfile:     true, // Премахва метаданните (EXIF) за още по-малък размер
        StripMetadata: true,
    }

    newImage, err := bimg.NewImage(inputData).Process(options)
    if err != nil {
        // Ако bimg не разпознае формата (напр. липсва поддръжка за AVIF в vips)
        // връщаме оригиналната картинка, вместо да се предаваме
        w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
        w.Write(inputData)
        return
    }

    // 3. ПРЕМАХВАНЕ НА CSP ЗА ГРАЦИОЗНО ЗАРЕЖДАНЕ
    w.Header().Set("Content-Type", "image/webp")
    w.Header().Set("Access-Control-Allow-Origin", "*") // Помага за избягване на CORS грешки
    w.Header().Set("X-Original-Size", strconv.Itoa(len(inputData)))
    w.Header().Set("X-Compressed-Size", strconv.Itoa(len(newImage)))
    w.Write(newImage)
}