package provider

import (
	"fmt"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"go_tracker/internal/database"
	"go_tracker/internal/models"
	"go_tracker/internal/utils"
)

func Router(app *fiber.App) {
	app.Get("/api/provider", List)
	app.Post("/api/provider", Create)
	app.Get("/api/provider/:id", Retrieve)
	app.Patch("/api/provider/:id", Update)
	app.Delete("/api/provider/:id", Delete)
}

func Retrieve(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	db := database.Get()
	provider := models.Provider{ID: *id}
	result := db.Find(&provider)
	if result.Error != nil {
		return &fiber.Error{
			Code:    fiber.StatusNotFound,
			Message: fmt.Sprintf("User with id %s not found", id),
		}
	}

	return ctx.JSON(&provider)
}

func List(ctx *fiber.Ctx) error {
	db := database.Get()
	providers := new([]models.Provider)
	db.Find(providers)
	return ctx.JSON(providers)
}

func Create(ctx *fiber.Ctx) error {
	var provider models.Provider
	err := ctx.BodyParser(&provider)
	if err != nil {
		return err
	}
	provider.ID = uuid.New().String()

	db := database.Get()
	result := db.Create(&provider)
	if result.Error != nil {
		return result.Error
	}

	return ctx.Status(fiber.StatusCreated).JSON(&provider)
}

func Update(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	provider := models.Provider{ID: *id}
	patch := models.Provider{ID: *id}
	err = ctx.BodyParser(&patch)
	if err != nil {
		return err
	}

	db := database.Get()
	result := db.Find(&provider)
	if result.Error != nil {
		return &fiber.Error{
			Code:    fiber.StatusNotFound,
			Message: fmt.Sprintf("User with id %s not found", id),
		}
	}

	if patch.Name != "" {
		provider.Name = patch.Name
	}
	if patch.Website != "" {
		provider.Website = patch.Website
	}

	db.Save(&provider)

	return ctx.Status(fiber.StatusAccepted).JSON(&provider)
}

func Delete(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	db := database.Get()
	provider := models.Provider{ID: *id}
	result := db.Delete(&provider)
	if result.Error != nil {
		return &fiber.Error{
			Code:    fiber.StatusNotFound,
			Message: "User with id %s not found",
		}
	}

	return ctx.SendStatus(fiber.StatusNoContent)
}
