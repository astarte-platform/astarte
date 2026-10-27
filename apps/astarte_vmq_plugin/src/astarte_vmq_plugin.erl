%%
%% This file is part of Astarte
%%
%% Copyright 2021 Ispirata Srl
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%

-module(astarte_vmq_plugin).
-export([start/0, stop/0]).

start() ->
    % We want to start the plugin as permanent to make sure that if the plugin
    % application crashes, VerneMQ comes down with it (and gets restarted by
    % K8s).
    % To do so, we need to define this erlang wrapper since right now VerneMQ
    % assumes the custom start function is contained in a module with the same
    % name as the application, which can't be an Elixir module due to naming
    % constraints.
    {ok, _} = application:ensure_all_started(astarte_vmq_plugin, permanent),
    ok = logger:update_handler_config(default, #{level => info}),
    ok = logger:set_handler_config(default, formatter, {flatlog,
                                #{template =>
                                ["level=", level, " "
                                 "time=", time, " ",
                                 "pid=", pid, " ",
                                 "mfa=", mfa, " ",
                                 "line=", line, " ",
                                 {realm, ["realm=", realm], []}, " ",
                                 {device_id, ["device_id=", device_id], []}, " ",
                                 msg, "\n"
                                ],
                              single_line => true}
                            }),
    ok.

stop() ->
    application:stop(astarte_vmq_plugin).
