%% -------------------------------------------------------------------
%%
%% Copyright (c) 2018 Vitor Enes. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(cal_exp).
-author("Vitor Enes <vitorenesduarte@gmail.com>").

-include("cal.hrl").

%% API
-export([exp_id/0,
         pod_body/3,
         label_selector/1]).

-define(SEP, <<"-">>).

%% @doc Generate experiment identifier.
-spec exp_id() -> integer().
exp_id() ->
    erlang:system_time(millisecond).

%% @doc Body for Kubernetes pod creation.
-spec pod_body(integer() | binary(), integer() | binary(), maps:map()) ->
    maps:map().
pod_body(ExpId, PodId, EntrySpec) when is_integer(ExpId) ->
    pod_body(integer_to_binary(ExpId), PodId, EntrySpec);
pod_body(ExpId, PodId, EntrySpec) when is_integer(PodId) ->
    pod_body(ExpId, integer_to_binary(PodId), EntrySpec);
pod_body(ExpId, PodId, #{<<"tag">> := Tag}=EntrySpec0)
  when is_binary(ExpId), is_binary(PodId) ->

    %% create pod name
    PodName = pod_name(Tag, ExpId, PodId),

    %% update entry spec
    EntrySpec = EntrySpec0#{<<"expId">> => ExpId,
                            <<"podId">> => PodId,
                            <<"name">> => PodName},

    %% create pod metadata
    Metadata = metadata(EntrySpec),

    %% create pod spec
    Spec = spec(EntrySpec),

    %% create request body
    #{<<"apiVersion">> => <<"v1">>,
      <<"kind">> => <<"Pod">>,
      <<"metadata">> => Metadata,
      <<"spec">> => Spec}.

%% @doc Compute pod label selector.
-spec label_selector(maps:map()) -> binary().
label_selector(#{<<"metadata">> := #{<<"labels">> := Labels}}=_PodBody) ->
    Selectors = maps:fold(
        fun(Label, Value, Acc) ->
            [cal_util:binary_join(<<"=">>, [Label, Value]) | Acc]
        end,
        [],
        Labels
    ),
    cal_util:binary_join(<<",">>, Selectors).

%% @private Generate pod name.
%%          Given it's entry name/tag (x), experiment id (y), and pod (z),
%%          and a separator -,
%%          the pod name will be x-y-z
-spec pod_name(binary(), binary(), binary()) -> binary().
pod_name(Tag, ExpId, PodId) ->
    <<Tag/binary, ?SEP/binary, ExpId/binary, ?SEP/binary, PodId/binary>>.

%% @private Generate pod metadata.
-spec metadata(maps:map()) -> maps:map().
metadata(#{<<"tag">> := Tag,
           <<"expId">> := ExpId,
           <<"podId">> := PodId,
           <<"name">> := PodName}) ->
    #{<<"name">> => PodName,
      <<"labels">> => #{<<"tag">> => Tag,
                        <<"expId">> => ExpId,
                        <<"podId">> => PodId}}.

%% @private Generate pod spec.
-spec spec(map:map()) -> maps:map().
spec(#{<<"name">> := PodName,
       <<"image">> := Image}=EntrySpec) ->
    #{<<"restartPolicy">> => <<"Never">>,
      <<"containers">> => [#{<<"name">> => PodName,
                             <<"image">> => Image,
                             <<"imagePullPolicy">> => <<"Always">>,
                             <<"env">> => env(EntrySpec)}]}.

%% @private Append env vars:
%%   - TAG
%%   - EXP_ID
%%   - POD_ID
%%   - POD_IP
-spec env(maps:map()) -> maps:map().
env(#{<<"tag">> := Tag,
      <<"expId">> := ExpId,
      <<"podId">> := PodId,
      <<"env">> := Env}) ->
    [#{<<"name">> => <<"TAG">>,
       <<"value">> => Tag},
     #{<<"name">> => <<"EXP_ID">>,
       <<"value">> => ExpId},
     #{<<"name">> => <<"POD_ID">>,
       <<"value">> => PodId},
     #{<<"name">> => <<"POD_IP">>,
       <<"valueFrom">> => #{<<"fieldRef">>
                            => #{<<"fieldPath">>
                                 => <<"status.podIP">>}}
      } | Env].