package main

import (
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/log"
	"github.com/gofiber/fiber/v2/middleware/logger"
	_ "github.com/joho/godotenv/autoload"
	"go_tracker/api/group_order"
	"go_tracker/api/provider"
	"go_tracker/internal/database"
	"time"
)

func main() {
	app := fiber.New(fiber.Config{
		AppName:           "GO Tracker",
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      5 * time.Second,
		EnablePrintRoutes: true,
	})

	database.Init()

	app.Use(logger.New())

	app.Get("/", func(ctx *fiber.Ctx) error {
		return ctx.SendString("ok")
	})

	app.Get("/health", func(ctx *fiber.Ctx) error {
		return ctx.SendString("ok")
	})

	provider.Router(app)
	group_order.Router(app)

	log.Fatal(app.Listen("0.0.0.0:5000"))
}
