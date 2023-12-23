import { Moment } from "moment";
import { Provider } from "./provider";

export enum OrderStatus {
  UNPAID,
  PARTIALLY_PAID,
  FULLY_PAID,
  SHIPPED,
  DELIVERED,
}

export const ReverseOrderStatus = [
  {
    label: "UNPAID",
    color: "error.main",
  },
  {
    label: "PARTIALLY_PAID",
    color: "warning.main",
  },
  {
    label: "FULLY_PAID",
    color: "success.main",
  },
  {
    label: "SHIPPED",
    color: "secondary.main",
  },
  {
    label: "DELIVERED",
    color: "primary.main",
  },
];

export interface GroupOrder {
  pk: string;
  item: string;
  provider: Provider;
  order_number: string;
  order_date: number;
  downpayment_deadline: number;
  payment_deadline: number;
  status: OrderStatus;
  total_balance: number;
  remaining_balance: number;
}

export interface GroupOrderForm {
  pk?: string;
  item: string;
  provider: Provider | null;
  order_number: string;
  order_date: Moment | null;
  downpayment_deadline: Moment | null;
  payment_deadline: Moment | null;
  status: OrderStatus;
  total_balance: number;
  remaining_balance: number;
}

export interface GroupOrderBody {
  pk?: string;
  item: string;
  provider: Provider | null;
  order_number: string;
  order_date: number;
  downpayment_deadline: number | null;
  payment_deadline: number;
  status: OrderStatus;
  total_balance: number;
  remaining_balance: number;
}
