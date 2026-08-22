import { Injectable } from '@nestjs/common';
import {
  OpenWaTransientDeliveryRejectedError,
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from '../../../platform/otp-transport/openwa-transient-text';
import {
  IdentityTransientDeliveryInput,
  IdentityTransientDeliveryPort,
  IdentityTransientDeliveryRejectedError,
  IdentityTransientDeliveryUncertainError,
} from '../public/identity-transient-delivery.port';

@Injectable()
export class IdentityTransientDeliveryAdapter
  implements IdentityTransientDeliveryPort
{
  async send(input: IdentityTransientDeliveryInput): Promise<void> {
    try {
      await sendOpenWaTransientText(input);
    } catch (error) {
      if (error instanceof OpenWaTransientDeliveryUncertainError) {
        throw new IdentityTransientDeliveryUncertainError();
      }
      if (error instanceof OpenWaTransientDeliveryRejectedError) {
        throw new IdentityTransientDeliveryRejectedError();
      }
      throw error;
    }
  }
}
