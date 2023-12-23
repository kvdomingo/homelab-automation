package database

import (
	"fmt"
	"go_tracker/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"os"
)

var db *gorm.DB

func Init() *gorm.DB {
	host := os.Getenv("POSTGRESQL_HOST")
	port := os.Getenv("POSTGRESQL_PORT")
	user := os.Getenv("POSTGRESQL_USERNAME")
	password := os.Getenv("POSTGRESQL_PASSWORD")
	dbname := os.Getenv("POSTGRESQL_DATABASE")

	if host == "" || port == "" || user == "" || password == "" || dbname == "" {
		panic("Incomplete database configuration")
	}

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s", host, user, password, dbname, port)

	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		panic(err)
	}

	err = db.AutoMigrate(&models.Provider{}, &models.GroupOrder{})
	if err != nil {
		panic(err)
	}

	return db
}

func Get() *gorm.DB {
	return db
}
