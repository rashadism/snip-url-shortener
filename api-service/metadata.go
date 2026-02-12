package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"
)

var (
	titleRe   = regexp.MustCompile(`(?i)<title[^>]*>(.*?)</title>`)
	faviconRe = regexp.MustCompile(`(?i)<link[^>]+rel=["'](?:shortcut )?icon["'][^>]+href=["']([^"']+)["']`)
)

func fetchMetadata(ctx context.Context, shortCode, originalURL string, store *Store) {
	ctx, span := tracer.Start(ctx, "fetchMetadata")
	defer span.End()

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	client := tracedHTTPClient()
	req, err := http.NewRequestWithContext(ctx, "GET", originalURL, nil)
	if err != nil {
		log.Printf("metadata fetch: bad request for %s: %v", originalURL, err)
		return
	}
	req.Header.Set("User-Agent", "snip-bot/1.0")

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("metadata fetch: failed for %s: %v", originalURL, err)
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20)) // 1MB limit
	if err != nil {
		log.Printf("metadata fetch: read failed for %s: %v", originalURL, err)
		return
	}

	html := string(body)
	title := extractTitle(html)
	favicon := extractFavicon(html, originalURL)

	if title != "" || favicon != "" {
		if err := store.UpdateMetadata(ctx, shortCode, title, favicon); err != nil {
			log.Printf("metadata update failed for %s: %v", shortCode, err)
		}
	}
}

func extractTitle(html string) string {
	matches := titleRe.FindStringSubmatch(html)
	if len(matches) > 1 {
		title := strings.TrimSpace(matches[1])
		if len(title) > 200 {
			title = title[:200]
		}
		return title
	}
	return ""
}

func extractFavicon(html, baseURL string) string {
	matches := faviconRe.FindStringSubmatch(html)
	if len(matches) > 1 {
		href := strings.TrimSpace(matches[1])
		if strings.HasPrefix(href, "http") {
			return href
		}
		// Resolve relative URL
		if strings.HasPrefix(href, "//") {
			return "https:" + href
		}
		// Extract origin from base URL
		parts := strings.SplitN(baseURL, "//", 2)
		if len(parts) == 2 {
			host := strings.SplitN(parts[1], "/", 2)[0]
			scheme := parts[0]
			if strings.HasPrefix(href, "/") {
				return scheme + "//" + host + href
			}
			return scheme + "//" + host + "/" + href
		}
	}
	return ""
}
