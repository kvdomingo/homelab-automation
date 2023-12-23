import { useEffect, useMemo, useState } from "react";

import { Delete as DeleteIcon, Edit as EditIcon } from "@mui/icons-material";
import { Box } from "@mui/material";
import { GridActionsCellItem, GridColDef } from "@mui/x-data-grid";
import { useMutation } from "@tanstack/react-query";
import { AxiosError } from "axios";
import dateFormat from "dateformat";

import api, { queryClient } from "@/api";
import OrderDialog from "@/components/orderDialog/OrderDialog";
import OrderTable from "@/components/orderTable/OrderTable";
import ProviderDialog from "@/components/providerDialog/ProviderDialog";
import { ReverseOrderStatus } from "@/types/groupOrder";

function App() {
  const deleteOrderMutation = useMutation(["orders"], api.groupOrder.delete);

  const [showCompleted, setShowCompleted] = useState(false);
  const [showOrderDialog, setShowOrderDialog] = useState(false);
  const [showProviderDialog, setShowProviderDialog] = useState(false);
  const [editing, setEditing] = useState("");

  useEffect(() => {
    void queryClient.invalidateQueries(["orders"]);
  }, [showCompleted]);

  const columns: GridColDef[] = useMemo(
    () => [
      {
        field: "item",
        headerName: "Item",
        flex: 2,
        type: "string",
      },
      {
        field: "provider",
        headerName: "Provider",
        flex: 1,
        type: "string",
        valueGetter: params => params.value.name,
      },
      {
        field: "order_number",
        headerName: "Order Number",
        flex: 1,
        type: "string",
      },
      {
        field: "order_date",
        headerName: "Order Date",
        flex: 1,
        type: "date",
        valueFormatter: params =>
          dateFormat(new Date(params.value), "dd mmm yyyy"),
      },
      {
        field: "downpayment_deadline",
        headerName: "Downpayment Deadline",
        flex: 1,
        type: "date",
        valueFormatter: params =>
          params.value
            ? dateFormat(new Date(params.value), "dd mmm yyyy")
            : "N/A",
      },
      {
        field: "payment_deadline",
        headerName: "Payment Deadline",
        flex: 1,
        type: "date",
        valueFormatter: params =>
          dateFormat(new Date(params.value), "dd mmm yyyy"),
      },
      {
        field: "total_balance",
        headerName: "Total Balance",
        flex: 1,
        type: "number",
        valueFormatter: ({ value }) => `P ${value.toFixed(2)}`,
      },
      {
        field: "remaining_balance",
        headerName: "Remaining Balance",
        flex: 1,
        type: "number",
        valueFormatter: ({ value }) => `P ${value.toFixed(2)}`,
      },
      {
        field: "status",
        headerName: "Status",
        flex: 1,
        type: "string",
        renderCell: params => (
          <Box
            className="flex h-full w-full items-center justify-center text-white"
            sx={{
              backgroundColor: ReverseOrderStatus[params.value].color,
            }}
          >
            {ReverseOrderStatus[params.value].label.replace("_", " ")}
          </Box>
        ),
      },
      {
        field: "pk",
        headerName: "Actions",
        type: "actions",
        getActions: params => [
          <GridActionsCellItem
            key={`edit-${params.id}`}
            icon={<EditIcon />}
            label="Edit"
            onClick={() => {
              setEditing(params.id as string);
              setShowOrderDialog(true);
            }}
          />,
          <GridActionsCellItem
            key={`delete-${params.id}`}
            icon={<DeleteIcon />}
            label="Delete"
            onClick={() => handleDelete(params.id as string)}
          />,
        ],
      },
    ],
    [],
  );

  function handleDelete(pk: string) {
    deleteOrderMutation.mutate(pk, {
      onError: err => {
        console.error((err as AxiosError).message);
        alert("A network error occurred.");
      },
    });
  }

  return (
    <div className="mx-auto h-screen w-full px-8">
      <OrderTable
        columns={columns}
        showOrderDialog={() => {
          setEditing("");
          setShowOrderDialog(true);
        }}
        showProviderDialog={() => setShowProviderDialog(true)}
        showCompleted={showCompleted}
        setShowCompleted={setShowCompleted}
      />
      <OrderDialog
        open={showOrderDialog}
        onClose={() => {
          setShowOrderDialog(false);
          setEditing("");
        }}
        maxWidth="md"
        fullWidth
        editing={editing}
        showCompleted={showCompleted}
      />
      <ProviderDialog
        open={showProviderDialog}
        onClose={() => setShowProviderDialog(false)}
        maxWidth="md"
        fullWidth
      />
    </div>
  );
}

export default App;
