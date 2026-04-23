import _ from 'lodash';
import * as yup from 'yup';

import { AstarteDeviceEvent, AstarteDeviceEventDTO } from './AstarteDeviceEvent';

type AstarteDeviceDeletionFinishedEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_deletion_finished';
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceDeletionFinishedEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_deletion_finished']).required(),
  })
  .required();

export class AstarteDeviceDeletionFinishedEvent extends AstarteDeviceEvent {
  private constructor(arg: unknown) {
    super(arg);
    validationSchema.validateSync(_.get(arg, 'event'));
  }

  static fromJSON(arg: unknown): AstarteDeviceDeletionFinishedEvent {
    return new AstarteDeviceDeletionFinishedEvent(arg);
  }
}
