package group_order

import (
	"fmt"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"go_tracker/internal/database"
	"go_tracker/internal/models"
	"go_tracker/internal/utils"
)

func Router(app *fiber.App) {
	app.Get("/api/order", List)
	app.Post("/api/order", Create)
	app.Get("/api/order/:id", Get)
	app.Patch("/api/order/:id", Update)
	app.Delete("/api/order/:id", Delete)
}

func Get(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	order := models.GroupOrder{ID: *id}
	db := database.Get()
	result := db.Find(&order)
	if result.Error != nil {
		return &fiber.Error{
			Code:    fiber.StatusNotFound,
			Message: fmt.Sprintf("Order id %s not found", *id),
		}
	}

	return ctx.JSON(&order)
}

func List(ctx *fiber.Ctx) error {
	showCompleted := ctx.QueryBool("showCompleted", false)

	db := database.Get()
	orders := new([]models.GroupOrder)
	if showCompleted {
		db.Find(orders).Order("order_date DESC")
	} else {
		db.Find(orders).Where("status != ?", models.OrderDelivered).Order("order_date DESC")
	}

	return ctx.JSON(&orders)
}

func Create(ctx *fiber.Ctx) error {
	var order models.GroupOrder
	err := ctx.BodyParser(order)
	if err != nil {
		return err
	}
	order.ID = uuid.New().String()

	db := database.Get()
	result := db.Create(&order)
	if result.Error != nil {
		return result.Error
	}

	return ctx.Status(fiber.StatusCreated).JSON(&order)
}

func Update(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	order := models.GroupOrder{ID: *id}
	patch := models.GroupOrder{ID: *id}

	db := database.Get()
	result := db.Find(&order)
	if result.Error != nil {
		return result.Error
	}

	if patch.OrderDate != nil {
		order.OrderDate = patch.OrderDate
	}
	if patch.OrderNumber != "" {
		order.OrderNumber = patch.OrderNumber
	}
	if patch.Status != nil {
		order.Status = patch.Status
	}
	if patch.Item != "" {
		order.Item = patch.Item
	}
	if patch.DownpaymentDeadline != nil {
		order.DownpaymentDeadline = patch.DownpaymentDeadline
	}
	if patch.PaymentDeadline != nil {
		order.PaymentDeadline = patch.PaymentDeadline
	}
	if patch.ProviderID != nil {
		order.ProviderID = patch.ProviderID
	}
	if patch.RemainingBalance != nil {
		order.RemainingBalance = patch.RemainingBalance
	}
	if patch.TotalBalance != nil {
		order.TotalBalance = patch.TotalBalance
	}

	db.Save(&order)

	return ctx.Status(fiber.StatusAccepted).JSON(&order)
}

func Delete(ctx *fiber.Ctx) error {
	id, err := utils.GetAndValidatePathId(ctx)
	if err != nil {
		return err
	}

	db := database.Get()
	order := models.Provider{ID: *id}
	result := db.Delete(&order)
	if result.Error != nil {
		return &fiber.Error{
			Code:    fiber.StatusNotFound,
			Message: fmt.Sprintf("Order id %s not found", *id),
		}
	}

	return ctx.SendStatus(fiber.StatusNoContent)
}
