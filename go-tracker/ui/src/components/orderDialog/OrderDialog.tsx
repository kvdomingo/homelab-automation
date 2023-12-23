import { ChangeEvent, FormEvent, useEffect, useState } from "react";

import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogProps,
  DialogTitle,
  FormControl,
  Grid,
  InputAdornment,
  InputLabel,
  MenuItem,
  Select,
  TextField,
} from "@mui/material";
import { DatePicker, LocalizationProvider } from "@mui/x-date-pickers";
import { AdapterMoment } from "@mui/x-date-pickers/AdapterMoment";
import { useMutation, useQuery } from "@tanstack/react-query";
import { AxiosError } from "axios";
import moment from "moment";

import api, { queryClient } from "@/api";
import {
  GroupOrderBody,
  GroupOrderForm,
  OrderStatus,
  ReverseOrderStatus,
} from "@/types/groupOrder";

interface Props extends DialogProps {
  editing: string;
  showCompleted: boolean;
}

function OrderDialog({ editing, showCompleted, ...props }: Props) {
  const providerQuery = useQuery(["providers"], api.provider.list);
  const orderQuery = useQuery(["orders"], () =>
    api.groupOrder.list(showCompleted),
  );
  const createOrderMutation = useMutation(["orders"], api.groupOrder.create);
  const updateOrderMutation = useMutation(
    ["orders"],
    ({ pk, data }: { pk: string; data: GroupOrderBody }) =>
      api.groupOrder.update(pk, data),
  );

  const providers = providerQuery.data?.data ?? [];
  const orders = orderQuery.data?.data ?? [];

  const initialFormState = {
    order_number: "",
    item: "",
    order_date: moment(new Date()),
    downpayment_deadline: null,
    payment_deadline: null,
    provider: null,
    status: 0,
    total_balance: 0.0,
    remaining_balance: 0.0,
  };
  const initialErrorsState = {
    order_number: false,
    item: false,
    order_date: false,
    downpayment_deadline: false,
    payment_deadline: false,
    provider: false,
    status: false,
    total_balance: false,
    remaining_balance: false,
  };
  const [form, setForm] = useState<GroupOrderForm>({ ...initialFormState });
  const [errors, setErrors] = useState<{
    [key in keyof GroupOrderForm]: boolean;
  }>({ ...initialErrorsState });

  useEffect(() => {
    if (editing) {
      const init_ = orders.find(o => o.pk === editing)!;
      const editingInitialFormState: GroupOrderForm = {
        ...orders.find(o => o.pk === editing)!,
        order_date: moment(init_.order_date),
        downpayment_deadline: init_.downpayment_deadline
          ? moment(init_.downpayment_deadline)
          : null,
        payment_deadline: moment(init_.payment_deadline),
      };
      delete editingInitialFormState.pk;
      setForm(editingInitialFormState);
    }
  }, [editing, orders]);

  function handleChange(
    e: ChangeEvent<HTMLTextAreaElement | HTMLInputElement>,
  ) {
    const { name, value } = e.target;
    if (["total_balance", "remaining_balance"].includes(name)) {
      setForm(form => ({ ...form, [name]: parseFloat(value) }));
    } else {
      setForm(form => ({ ...form, [name]: value }));
    }
  }

  function preSubmitValidate(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const errors_ = { ...errors };
    (Object.keys(errors_) as (keyof GroupOrderForm)[]).forEach(key => {
      if (typeof form[key] === "number") {
        errors_[key] = (form[key] as number) < 0;
      } else {
        errors_[key] = !form[key];
      }
    });
    errors_.downpayment_deadline = false;
    if (Object.values(errors_).some(Boolean)) setErrors(errors_);
    else editing ? handleUpdateOrder(e) : handleSubmit(e);
  }

  function handleClose(e: any) {
    props.onClose!(e, "backdropClick");
    setForm({ ...initialFormState });
    setErrors({ ...initialErrorsState });
  }

  function handleSubmit(e: any) {
    const form_: GroupOrderBody = {
      ...form,
      order_date: form.order_date!.unix().valueOf() * 1000,
      downpayment_deadline: form.downpayment_deadline
        ? form.downpayment_deadline.unix().valueOf() * 1000
        : null,
      payment_deadline: form.payment_deadline!.unix().valueOf() * 1000,
    };

    createOrderMutation.mutate(form_, {
      onSuccess: () => handleClose(e),
      onError: err => console.error((err as AxiosError).message),
      onSettled: () => queryClient.invalidateQueries(["orders"]),
    });
  }

  function handleUpdateOrder(e: any) {
    const form_: GroupOrderBody = {
      ...form,
      order_date: form.order_date!.unix().valueOf() * 1000,
      downpayment_deadline: form.downpayment_deadline
        ? form.downpayment_deadline.unix().valueOf() * 1000
        : null,
      payment_deadline: form.payment_deadline!.unix().valueOf() * 1000,
    };

    updateOrderMutation.mutate(
      { pk: editing, data: form_ },
      {
        onSuccess: () => handleClose(e),
        onError: err => console.error((err as AxiosError).message),
        onSettled: () => queryClient.invalidateQueries(["orders"]),
      },
    );
  }

  return (
    <Dialog {...props} onClose={handleClose}>
      <DialogTitle>{editing ? "Edit Order" : "Add Order"}</DialogTitle>
      <form onSubmit={preSubmitValidate}>
        <DialogContent>
          <DialogContentText>
            <LocalizationProvider dateAdapter={AdapterMoment}>
              <Grid container spacing={1}>
                <Grid item xs={12}>
                  <TextField
                    variant="filled"
                    value={form.item}
                    error={errors.item}
                    helperText={errors.item && "This field is required"}
                    fullWidth
                    label="Item"
                    name="item"
                    onChange={handleChange}
                    required
                  />
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    variant="filled"
                    value={form.order_number}
                    error={errors.order_number}
                    helperText={errors.order_number && "This field is required"}
                    fullWidth
                    label="Order Number"
                    name="order_number"
                    onChange={handleChange}
                    required
                  />
                </Grid>
                <Grid item xs={6}>
                  <FormControl
                    fullWidth
                    variant="filled"
                    required
                    error={errors.provider}
                  >
                    <InputLabel id="provider-label">Shop</InputLabel>
                    <Select
                      labelId="provider-label"
                      value={form.provider?.pk || ""}
                      label="Shop"
                      name="provider"
                      onChange={e =>
                        setForm({
                          ...form,
                          provider: providers.find(
                            p => p.pk === e.target.value,
                          )!,
                        })
                      }
                    >
                      {providers.length === 0 && (
                        <MenuItem value="noop" disabled>
                          No shops available
                        </MenuItem>
                      )}
                      {providers.map(provider => (
                        <MenuItem key={provider.pk} value={provider.pk}>
                          {provider.name}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                </Grid>
                <Grid item xs={6}>
                  <DatePicker
                    disableFuture
                    label="Order Date"
                    onChange={value =>
                      setForm({
                        ...form,
                        order_date: value,
                      })
                    }
                    value={form.order_date}
                    slotProps={{
                      textField: {
                        name: "order_date",
                        variant: "filled",
                        fullWidth: true,
                        required: true,
                        error: errors.order_date,
                        helperText:
                          errors.order_date && "This field is required",
                      },
                    }}
                  />
                </Grid>
                <Grid item xs={6}>
                  <DatePicker
                    label="Downpayment Deadline"
                    onChange={value =>
                      setForm({
                        ...form,
                        downpayment_deadline: value,
                      })
                    }
                    value={form.downpayment_deadline}
                    slotProps={{
                      textField: {
                        name: "downpayment_deadline",
                        variant: "filled",
                        fullWidth: true,
                      },
                    }}
                    disablePast
                  />
                </Grid>
                <Grid item xs={6}>
                  <DatePicker
                    label="Payment Deadline"
                    onChange={value =>
                      setForm({
                        ...form,
                        payment_deadline: value,
                      })
                    }
                    value={form.payment_deadline}
                    slotProps={{
                      textField: {
                        name: "payment_deadline",
                        variant: "filled",
                        fullWidth: true,
                        required: true,
                        error: errors.payment_deadline,
                        helperText:
                          errors.payment_deadline && "This field is required",
                      },
                    }}
                    disablePast
                  />
                </Grid>
                <Grid item xs={6}>
                  <FormControl
                    fullWidth
                    variant="filled"
                    required
                    error={errors.status}
                  >
                    <InputLabel id="status-label">Status</InputLabel>
                    <Select
                      labelId="status-label"
                      value={form.status}
                      label="Status"
                      name="status"
                      onChange={e =>
                        setForm({
                          ...form,
                          status: parseInt(e.target.value as string),
                        })
                      }
                    >
                      {ReverseOrderStatus.map((status, index) => (
                        <MenuItem
                          key={status.label}
                          value={index as OrderStatus}
                        >
                          {status.label.replace(/_/g, " ")}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    type="number"
                    variant="filled"
                    value={form.total_balance.toFixed(2)}
                    error={errors.total_balance}
                    helperText={
                      errors.total_balance && "This field is required"
                    }
                    fullWidth
                    label="Total Amount"
                    name="total_balance"
                    onChange={handleChange}
                    required
                    inputMode="decimal"
                    InputProps={{
                      "inputMode": "decimal",
                      "aria-valuemin": 0,
                      "startAdornment": (
                        <InputAdornment position="start">P</InputAdornment>
                      ),
                    }}
                  />
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    type="number"
                    variant="filled"
                    value={form.remaining_balance.toFixed(2)}
                    error={errors.remaining_balance}
                    helperText={
                      errors.remaining_balance && "This field is required"
                    }
                    fullWidth
                    label="Remaining Balance"
                    name="remaining_balance"
                    onChange={handleChange}
                    required
                    InputProps={{
                      "inputMode": "decimal",
                      "aria-valuemin": 0,
                      "startAdornment": (
                        <InputAdornment position="start">P</InputAdornment>
                      ),
                    }}
                  />
                </Grid>
              </Grid>
            </LocalizationProvider>
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button
            color="inherit"
            variant="text"
            sx={{ color: "text.secondary" }}
            onClick={handleClose}
          >
            Cancel
          </Button>
          <Button color="primary" variant="text" type="submit">
            Save
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}

export default OrderDialog;
