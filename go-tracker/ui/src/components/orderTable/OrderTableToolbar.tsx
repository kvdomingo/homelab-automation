import { Dispatch, SetStateAction } from "react";

import { Add as AddIcon } from "@mui/icons-material";
import {
  Box,
  Button,
  FormControlLabel,
  Grid,
  Switch,
  Typography,
} from "@mui/material";
import {
  GridToolbarColumnsButton,
  GridToolbarContainer,
  GridToolbarDensitySelector,
  GridToolbarExport,
  GridToolbarFilterButton,
} from "@mui/x-data-grid";

interface Props {
  showOrderDialog: () => void;
  showProviderDialog: () => void;
  showCompleted: boolean;
  setShowCompleted: Dispatch<SetStateAction<boolean>>;
}

function OrderTableToolbar({
  showOrderDialog,
  showProviderDialog,
  showCompleted,
  setShowCompleted,
}: Props) {
  return (
    <GridToolbarContainer>
      <Grid item xs>
        <GridToolbarColumnsButton />
        <GridToolbarFilterButton />
        <GridToolbarDensitySelector />
        <GridToolbarExport />
        <Box sx={{ display: "inline", mx: 2 }}>
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={showCompleted}
                onChange={() => setShowCompleted(prev => !prev)}
              />
            }
            label={
              <Typography variant="button">Show delivered orders</Typography>
            }
          />
        </Box>
      </Grid>
      <Grid item xs container justifyContent="flex-end">
        <Button
          variant="text"
          size="small"
          startIcon={<AddIcon />}
          className="mr-2"
          onClick={showProviderDialog}
        >
          Add Shop
        </Button>
        <Button
          variant="text"
          size="small"
          className="mr-2"
          startIcon={<AddIcon />}
          onClick={showOrderDialog}
        >
          Add Order
        </Button>
      </Grid>
    </GridToolbarContainer>
  );
}

export default OrderTableToolbar;
