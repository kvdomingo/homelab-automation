import { Dispatch, SetStateAction } from "react";

import { DataGrid, GridColDef } from "@mui/x-data-grid";
import { useQuery } from "@tanstack/react-query";

import api from "@/api";
import { GroupOrder } from "@/types/groupOrder";

import OrderTableToolbar from "./OrderTableToolbar";

interface Props {
  columns: GridColDef[];
  showOrderDialog: () => void;
  showProviderDialog: () => void;
  showCompleted: boolean;
  setShowCompleted: Dispatch<SetStateAction<boolean>>;
}

function OrderTable({
  columns,
  showOrderDialog,
  showProviderDialog,
  showCompleted,
  setShowCompleted,
}: Props) {
  const query = useQuery(["orders", { showCompleted }], () =>
    api.groupOrder.list(showCompleted),
  );
  const orders = query.data?.data ?? [];

  return (
    <DataGrid
      className="h-full w-full"
      autoPageSize
      disableRowSelectionOnClick
      columns={columns}
      rows={orders}
      slots={{ toolbar: OrderTableToolbar }}
      slotProps={{
        toolbar: {
          showOrderDialog,
          showProviderDialog,
          showCompleted,
          setShowCompleted,
        },
      }}
      getRowId={(row: GroupOrder) => row.pk}
    />
  );
}

export default OrderTable;
