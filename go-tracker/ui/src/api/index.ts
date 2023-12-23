import { QueryClient } from "@tanstack/react-query";
import axios, { AxiosResponse } from "axios";

import { GroupOrder, GroupOrderBody } from "@/types/groupOrder";
import { Provider, ProviderForm } from "@/types/provider";

const baseURL = "/api";

const axi = axios.create({ baseURL });

const api = {
  provider: {
    list(): Promise<AxiosResponse<Provider[]>> {
      return axi.get("/provider");
    },
    get(pk: string): Promise<AxiosResponse<Provider>> {
      return axi.get(`/provider/${pk}`);
    },
    create(data: ProviderForm): Promise<AxiosResponse<Provider>> {
      return axi.post("/provider", data);
    },
    delete(pk: string): Promise<AxiosResponse<null>> {
      return axi.delete(`/provider/${pk}`);
    },
    partialUpdate(
      pk: string,
      key: keyof Provider,
      value: Provider[keyof Provider],
    ): Promise<AxiosResponse<Provider>> {
      return axi.patch(`/provider/${pk}`, { [key]: value });
    },
  },
  groupOrder: {
    list(showCompleted = false): Promise<AxiosResponse<GroupOrder[]>> {
      return axi.get(`/order${showCompleted ? "?showCompleted=true" : ""}`);
    },
    get(pk: string): Promise<AxiosResponse<GroupOrder>> {
      return axi.get(`/order/${pk}`);
    },
    create(data: GroupOrderBody): Promise<AxiosResponse<GroupOrder>> {
      return axi.post("/order", data);
    },
    delete(pk: string): Promise<AxiosResponse<null>> {
      return axi.delete(`/order/${pk}`);
    },
    partialUpdate(
      pk: string,
      key: keyof GroupOrderBody,
      value: GroupOrderBody[keyof GroupOrderBody],
    ): Promise<AxiosResponse<GroupOrder>> {
      return axi.patch(`/order/${pk}`, { [key]: value });
    },
    update(
      pk: string,
      data: GroupOrderBody,
    ): Promise<AxiosResponse<GroupOrder>> {
      return axi.patch(`/order/${pk}`, data);
    },
  },
};

export default api;

export const queryClient = new QueryClient();
