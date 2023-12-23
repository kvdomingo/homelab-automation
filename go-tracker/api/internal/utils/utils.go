package utils

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"net/http"
)

func GetAndValidatePathId(ctx *fiber.Ctx) (*string, error) {
	id := ctx.Params("id")
	if id == "" {
		return nil, &fiber.Error{
			Code:    http.StatusBadRequest,
			Message: "No id was received",
		}
	}

	_, err := uuid.Parse(id)
	if err != nil {
		return nil, &fiber.Error{
			Code:    http.StatusBadRequest,
			Message: "Invalid UUID",
		}
	}

	return &id, nil
}
