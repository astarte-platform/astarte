import _ from 'lodash';
import * as yup from 'yup';

import { AstarteDeviceEvent, AstarteDeviceEventDTO } from './AstarteDeviceEvent';

type AstarteDeviceDeletionStartedEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_deletion_started';
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceDeletionStartedEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_deletion_started']).required(),
  })
  .required();

export class AstarteDeviceDeletionStartedEvent extends AstarteDeviceEvent {
  private constructor(arg: unknown) {
    super(arg);
    validationSchema.validateSync(_.get(arg, 'event'));
  }

  static fromJSON(arg: unknown): AstarteDeviceDeletionStartedEvent {
    return new AstarteDeviceDeletionStartedEvent(arg);
  }
}
