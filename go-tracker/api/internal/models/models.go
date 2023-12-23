package models

import (
	"time"
)

type Provider struct {
	ID          string       `gorm:"primaryKey,type:uuid,default:gen_random_uuid()" json:"id"`
	Name        string       `gorm:"unique" json:"name"`
	Website     string       `json:"website"`
	GroupOrders []GroupOrder `gorm:"constraint:OnDelete:CASCADE;" json:"group_orders"`
}

type OrderStatus uint8

const (
	OrderUnpaid OrderStatus = iota
	OrderPartiallyPaid
	OrderFullyPaid
	OrderShipped
	OrderDelivered
)

type GroupOrder struct {
	ID                  string       `gorm:"primaryKey,type:uuid,default:gen_random_uuid()" json:"id"`
	Item                string       `json:"item"`
	ProviderID          *uint        `json:"provider_id"`
	OrderNumber         string       `json:"order_number"`
	OrderDate           *time.Time   `gorm:"autoCreateTime" json:"order_date"`
	DownpaymentDeadline *time.Time   `json:"downpayment_deadline"`
	PaymentDeadline     *time.Time   `json:"payment_deadline"`
	Status              *OrderStatus `gorm:"default:0" json:"status"`
	TotalBalance        *float32     `json:"total_balance"`
	RemainingBalance    *float32     `json:"remaining_balance"`
}
