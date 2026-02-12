package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/otel/attribute"
)

type Cache struct {
	client *redis.Client
}

func NewCache(addr string) *Cache {
	if addr == "" {
		return nil
	}
	client := redis.NewClient(&redis.Options{
		Addr:         addr,
		DialTimeout:  2 * time.Second,
		ReadTimeout:  1 * time.Second,
		WriteTimeout: 1 * time.Second,
	})
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("WARN: Redis unavailable at %s: %v (continuing without cache)", addr, err)
		return nil
	}
	log.Printf("Redis connected at %s", addr)
	return &Cache{client: client}
}

func (c *Cache) GetClickCount(ctx context.Context, shortCode string) (int64, error) {
	if c == nil {
		return 0, fmt.Errorf("cache disabled")
	}
	ctx, span := tracer.Start(ctx, "cache.GetClickCount")
	defer span.End()
	span.SetAttributes(attribute.String("short_code", shortCode))

	val, err := c.client.Get(ctx, "clicks:"+shortCode).Int64()
	if err != nil {
		span.SetAttributes(attribute.Bool("cache.hit", false))
		return 0, err
	}
	span.SetAttributes(attribute.Bool("cache.hit", true))
	return val, nil
}

func (c *Cache) GetRecentClicks(ctx context.Context, shortCode string) ([]string, error) {
	if c == nil {
		return nil, fmt.Errorf("cache disabled")
	}
	ctx, span := tracer.Start(ctx, "cache.GetRecentClicks")
	defer span.End()
	span.SetAttributes(attribute.String("short_code", shortCode))

	vals, err := c.client.LRange(ctx, "recent:"+shortCode, 0, 49).Result()
	if err != nil || len(vals) == 0 {
		span.SetAttributes(attribute.Bool("cache.hit", false))
		return nil, fmt.Errorf("cache miss")
	}
	span.SetAttributes(attribute.Bool("cache.hit", true))
	return vals, nil
}

func (c *Cache) SetClickData(ctx context.Context, shortCode string, count int64, recentClicks []string) {
	if c == nil {
		return
	}
	ctx, span := tracer.Start(ctx, "cache.SetClickData")
	defer span.End()

	pipe := c.client.Pipeline()
	pipe.Set(ctx, "clicks:"+shortCode, count, 5*time.Minute)
	if len(recentClicks) > 0 {
		pipe.Del(ctx, "recent:"+shortCode)
		vals := make([]interface{}, len(recentClicks))
		for i, v := range recentClicks {
			vals[i] = v
		}
		pipe.RPush(ctx, "recent:"+shortCode, vals...)
		pipe.Expire(ctx, "recent:"+shortCode, 5*time.Minute)
	}
	if _, err := pipe.Exec(ctx); err != nil {
		log.Printf("WARN: cache set click data %s failed: %v", shortCode, err)
	}
}
