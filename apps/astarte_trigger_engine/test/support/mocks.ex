# Copyright 2018-2022 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

Mox.defmock(MockEventsConsumer, for: Astarte.TriggerEngine.EventsConsumer.Behaviour)
Mox.defmock(MockAdapter, for: ExRabbitPool.Clients.Adapter)
