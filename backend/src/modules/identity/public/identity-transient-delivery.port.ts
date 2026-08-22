export type IdentityTransientDeliveryInput = {
  phone: string;
  text: string;
};

export interface IdentityTransientDeliveryPort {
  send(input: IdentityTransientDeliveryInput): Promise<void>;
}

export const IDENTITY_TRANSIENT_DELIVERY_PORT = Symbol(
  'IDENTITY_TRANSIENT_DELIVERY_PORT',
);

export class IdentityTransientDeliveryUncertainError extends Error {}

export class IdentityTransientDeliveryRejectedError extends Error {}
