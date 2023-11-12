package main

import (
	"crypto/tls"
	"encoding/json"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/log"
	"github.com/gofiber/fiber/v2/middleware/cache"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/storage/memory/v2"
	_ "github.com/joho/godotenv/autoload"
	"io"
	"net/http"
	"os"
	"time"
)

type ApodResponse struct {
	Copyright      string `json:"copyright"`
	Date           string `json:"date"`
	Explanation    string `json:"explanation"`
	HdUrl          string `json:"hdurl"`
	MediaType      string `json:"media_type"`
	ServiceVersion string `json:"service_version"`
	Title          string `json:"title"`
	Url            string `json:"url"`
}

func main() {
	app := fiber.New(fiber.Config{
		AppName:           "APOD",
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      5 * time.Second,
		StreamRequestBody: true,
		EnablePrintRoutes: true,
	})

	app.Use(logger.New())

	store := memory.New()
	app.Use(cache.New(cache.Config{
		Expiration: time.Hour * 6,
		Storage:    store,
		MaxBytes:   0,
		Methods:    []string{http.MethodGet},
	}))

	apodKey := os.Getenv("NASA_APOD_API_KEY")
	if apodKey == "" {
		panic("NASA_APOD_API_KEY not set")
	}

	app.Get("/health", func(ctx *fiber.Ctx) error {
		return ctx.SendString("ok")
	})

	app.Get("/", func(ctx *fiber.Ctx) error {
		transport := &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
		client := &http.Client{Transport: transport}

		res, err := client.Get("https://api.nasa.gov/planetary/apod?api_key=" + apodKey)
		if err != nil {
			return err
		}
		defer res.Body.Close()

		body, err := io.ReadAll(res.Body)
		if err != nil {
			return err
		}

		var obj ApodResponse
		err = json.Unmarshal(body, &obj)
		if err != nil {
			return err
		}

		return ctx.Redirect(obj.HdUrl, http.StatusFound)
	})

	log.Fatal(app.Listen("0.0.0.0:5000"))
}
