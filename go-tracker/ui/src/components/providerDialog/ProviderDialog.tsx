import { ChangeEvent, FormEvent, useState } from "react";

import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogProps,
  DialogTitle,
  Grid,
  TextField,
} from "@mui/material";
import { useMutation } from "@tanstack/react-query";
import { AxiosError } from "axios";

import api, { queryClient } from "@/api";
import { ProviderForm } from "@/types/provider";

function ProviderDialog({ ...props }: DialogProps) {
  const mutation = useMutation(["providers"], api.provider.create);

  const initialFormState = {
    name: "",
    website: "",
  };
  const initialErrorsState = {
    name: false,
    website: false,
  };
  const [form, setForm] = useState<ProviderForm>({ ...initialFormState });
  const [errors, setErrors] = useState<{
    [key in keyof ProviderForm]: boolean;
  }>({ ...initialErrorsState });

  function preSubmitValidate(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const errors_ = { ...errors };
    (Object.keys(errors_) as (keyof ProviderForm)[]).forEach(key => {
      errors_[key] = !form[key];
    });
    if (Object.values(errors_).some(Boolean)) setErrors(errors_);
    else handleSubmit(e);
  }

  function handleChange(
    e: ChangeEvent<HTMLTextAreaElement | HTMLInputElement>,
  ) {
    const { name, value } = e.target;
    setForm(form => ({ ...form, [name]: value }));
  }

  function handleSubmit(e: any) {
    mutation.mutate(form, {
      onSuccess: () => handleClose(e),
      onError: err => {
        console.error((err as AxiosError).message);
        alert("A network error occurred.");
      },
      onSettled: () => queryClient.invalidateQueries(["providers"]),
    });
  }

  function handleClose(e: any) {
    props.onClose!(e, "backdropClick");
    setForm({ ...initialFormState });
    setErrors({ ...initialErrorsState });
  }

  return (
    <Dialog {...props} onClose={handleClose}>
      <DialogTitle>Add Shop</DialogTitle>
      <form onSubmit={preSubmitValidate}>
        <DialogContent>
          <Grid container spacing={1}>
            <Grid item xs={12}>
              <TextField
                variant="filled"
                value={form.name}
                error={errors.name}
                helperText={errors.name && "This field is required"}
                fullWidth
                label="Name"
                name="name"
                onChange={handleChange}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                variant="filled"
                value={form.website}
                error={errors.website}
                helperText={errors.website && "This field is required"}
                fullWidth
                label="Website"
                name="website"
                onChange={handleChange}
                required
              />
            </Grid>
          </Grid>
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

export default ProviderDialog;
