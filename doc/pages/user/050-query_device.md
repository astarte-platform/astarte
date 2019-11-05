# Querying a Device

Once you have your devices connected, up and running in Astarte, you can start interacting with them.

## Using AppEngine API

First things first, you can check if your device is correctly registered in Astarte, and its current status. Let's assume our Device has `f0VMRgIBAQAAAAAAAAAAAA` as its id.

_Sample Request_
```
GET appengine.api.<your astarte domain>/v1/test/devices/f0VMRgIBAQAAAAAAAAAAAA
```

_Sample Response_
```json
{
    "data": {
        "total_received_msgs": 221,
        "total_received_bytes": 11660,
        "last_seen_ip": "203.0.113.89",
        "last_credentials_request_ip": "203.0.113.201",
        "last_disconnection": "2018-02-07T18:38:57.266Z",
        "last_connection": "2018-02-08T09:49:26.556Z",
        "id": "f0VMRgIBAQAAAAAAAAAAAA",
        "first_registration": "2018-01-31T17:10:59.270Z",
        "connected": true,
        "introspection": {
            "com.example.ExampleInterface" : {
                "major" : 1,
                "minor" : 0,
                "exchanged_msgs": 20,
                "exchanged_bytes": 200
            },
            "org.example.TestInterface" : {
                "major" : 0,
                "minor" : 2,
                "exchanged_msgs": 8,
                "exchanged_bytes": 147
            }
        },
        "aliases": {
            "name": "device_a"
        },
        "groups": [
            "my_group",
        ],
        "previous_interfaces": [
            {
                "name": "com.example.ExampleInterface",
                "major" : 0,
                "minor" : 2,
                "exchanged_msgs": 3,
                "exchanged_bytes": 120 
            }
        ]
    }
}
```

A Device's status includes a number of useful information, among which whether it is connected or not to its Transport. From there on, we can check on its Introspection.

_Sample Request_
```
GET appengine.api.<your astarte domain>/v1/test/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces
```

_Sample Response_
```json
{
    "data": [
        "com.example.ExampleInterface",
        "com.example.TestInterface"
    ]
}
```

This returns the Interfaces which the device reported in its Introspection *and* which are known to the Realm.

Depending on the aggregation and ownership of the Interface, you can `GET`/`PUT`/`POST` on the interface itself or one of its mappings. Some examples are:

Get data from an `aggregate` `device` `properties` interface:
```
GET appengine.api.<your astarte domain>/v1/test/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.example.ExampleInterface
```

Get last sent value from an `individual` `device` `datastream` interface:
```
GET appengine.api.<your astarte domain>/v1/test/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.example.TestInterface/myValue?limit=1
```

Set values in an `individual` `server` `datastream` interface:
```
POST appengine.api.<your astarte domain>/v1/test/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.example.OtherTestInterface/myOtherValue
```

In general, to query AppEngine, the following things must be kept in mind

* When sending data, use `PUT` if dealing with `properties`, `POST` if dealing with `datastream`.
* When `GET`ting, if you are querying an `aggregate` interface, make sure to query the interface itself rather than its mappings.
* When `GET`ting `datastream`, keep in mind that AppEngine's default behavior is to return a large as possible timeseries.

## Navigating and retrieving Datastream results

The Datastream case is significant, as it might be common to have *a lot* of values for each endpoint/interface. As such, returning all of them in a single API call is most of the times not desirable nor recommended.

To avoid putting the cluster under excessive pressure, AppEngine API is configured with a hard cap on the maximum number of returned results for each single call, with a sane default of `10000`. Although this hard cap is entirely configurable, please be aware that AppEngine API is designed to process a lot of reasonably small requests in the shortest possible time, and hence is **not optimised nor strongly tested against big requests**. Make sure that AppEngine API has enough resources available to cope with the maximum dataset size.

AppEngine API provides you with a variety of mechanisms to make retrieval and navigation of large data sets as smooth and efficient as possible.

### Limit

Adding a `limit=n` to the URL query tells AppEngine to return no more than `n` results. This acts similarly to a `LIMIT` SQL statement, but, as it stands, it does not impose a hard limit on the whole retrieved dataset but on the amount of the results displayed by the API call - see [Pagination and Time Windows](#pagination-and-time-windows) for more details on this topic and the performance implications of different limits in queries.

If the specified `limit` is beyond the hard cap, the query won't fail, but will return at most the amount set by the hard cap, without further warnings.

### Since/To/Since After

Results can be limited to a specific time window. `since` and `to` can be set to a ISO 8601 valid timestamp to limit on an upper and lower bound the result set. This can also be combined with `limit` to make sure that no more than `n` results are returned. Also, `since` and `to` can as well be set independently to provide only an upper or lower bound.

In case you're dealing with a very large dataset and you want to dump it, it is likely that you need to go beyond what a reasonable default limit looks like. In those cases, you can use the `since_after` query parameter to retrieve parameters within a time window. `since_after` slices the time window just like `since` does, but it does not include values matching the specified timestamp, if any. This is especially useful when paginating, to start right after a returned result.

### Pagination and time windows

AppEngine API provides you automatically with a time window-based pagination. When `GET`ting a `datastream`, if more results are available beyond the chosen time window/limit, a `links` map will be provided, in JSON-API style, to allow the user to paginate the results accordingly using `since_after`.

You can use `limit` to determine each page's size. When specifying a valid `limit`, the `links` will keep the page size consistent over the next calls.

However, `limit` should be used wisely to lower the pressure on the cluster. Each API call maps to a query that, no matter how efficient, has a computational cost. A few mid-sized queries should **always** be preferred over a large amount of smaller queries. Given your cluster is configured correctly, `limit` should be omitted in most cases when paginating, and you should rather trust your cluster's hard cap to be the sweet spot in efficiency and cluster pressure.

### Downsampling

Especially when plotting graphs, retrieving all points in a time series isn't desirable. Astarte provides you with an implementation of the [LTTB Downsampling Algorithm](https://skemman.is/bitstream/1946/15343/3/SS_MSthesis.pdf), which is used to return only a fixed number of samples from a time series. When setting `downsample_to=n`, AppEngine will return a maximum of `n` results, which are the most significant over the considered time series according to the algorithm.

Due to how LTTB works, `downsample_to` **must** be `>2`, as the algorithm will return the two ends of the considered value bucket, and `n-2` values which are the picked samples. Please refer to the [LTTB implementation used by Astarte](https://github.com/ispirata/ex_lttb) to learn more about how this algorithm affects samples and its limitations.

`downsample_to=x` can be used in conjunction with other query parameters, including `limit=y`. When doing so, Astarte will downsample to `x` samples the dataset composed of the last `y` values. Every feature previously outlined is in fact available with downsampling, including pagination - bear in mind, though, that for how the algorithm works, some options have drastically different semantic effects.

Also, the hard cap has a very different meaning in downsampling. In this case, the hard cap applies to `downsample_to` instead of `limit`. `limit` can be an arbitrarly large amount of samples taken out of the DB, and can be used mainly to alleviate pressure in case of *extremely* large datasets which would require a lot of time for being processed by LTTB - even though, most of the time, you might want to define a time window to downsample instead.

Astarte is also capable of downsampling aggregated interfaces, as long as a `downsample_key` is specified, which has to match the last token of an `endpoint` of the queried `interface` (i.e. in case the interface has a `/%{id}/myValue` mapping which should be used as the `downsample_key`, you should specify `downsample_key=myValue` in the query). When doing so, the aggregate will be downsampled using the chosen `endpoint` value as the `y` axis value, whereas its other `endpoints` will be disregarded when applying the algorithm. Please note that, no matter what `downsample_key` is used, a sample will be composed by the whole aggregation.

If there is no way an interface can be downsampled (this is true, for example, if no `downsample_key` has been specified for `aggregations`, or for types such as `strings`), AppEngine API will return a `4xx` error. In general, downsampling is a powerful mechanism with a lot of limitations which really shines when plotting. Once again, this is a fundamental factor to consider when [designing your interfaces](029-interface_design_guide.html).
