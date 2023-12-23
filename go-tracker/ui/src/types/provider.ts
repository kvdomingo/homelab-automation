export interface ProviderForm {
  name: string;
  website: string;
}

export interface Provider extends ProviderForm {
  pk: string;
}
