import _ from 'lodash';
import * as yup from 'yup';

import { AstarteDeviceEvent, AstarteDeviceEventDTO } from './AstarteDeviceEvent';

type AstarteDeviceRegistrationEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_registered';
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceRegistrationEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_registered']).required(),
  })
  .required();

export class AstarteDeviceRegistrationEvent extends AstarteDeviceEvent {
  private constructor(arg: unknown) {
    super(arg);
    validationSchema.validateSync(_.get(arg, 'event'));
  }

  static fromJSON(arg: unknown): AstarteDeviceRegistrationEvent {
    return new AstarteDeviceRegistrationEvent(arg);
  }
}
