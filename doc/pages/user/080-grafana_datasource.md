# Astarte Datasource Plugin for Grafana

Astarte Datasource Plugin conveys data from Astarte to
[Grafana](https://github.com/grafana/grafana), the open-source platform for
monitoring and observability, developed by [Grafana Labs](https://grafana.com/).
Actual data visualisation is provided by Grafana via its
[plugins](https://grafana.com/grafana/plugins/?type=panel).

You can browse the source code of this plugin on its
[GitHub repository](https://github.com/astarte-platform/grafana-astarte-datasource).

![Sample Grafana dashboard](assets/astarte-grafana-dashboard-overview.png)

## Try it!

When deploying locally using `docker-compose` as mentioned in the
[Astarte in 5 mins
tutorial](https://docs.astarte-platform.org/astarte/1.1/010-astarte_in_5_minutes.html#install-astarte),
Astarte Datasource Plugin will be automatically installed. You may then access Grafana
by visiting http://grafana.astarte.localhost.

When first logging into Grafana, you will be prompted to change default
credentials user `admin`, password: `admin`.

# Configure the datasource

In order to get data from Astarte, you will need to create a new datasource
referring to your own Astarte instance.

![Add a Grafana Datasource](assets/astarte-grafana-add-datasource.png)

You will need to provide Astarte API URLs, the realm name and Astarte AppEngine token.

![Datasource configuration fields](assets/astarte-grafana-datasource-fields.png)

Save the configuration by clicking on Save & Test

## Setting up a graph

After successfully configuring your datasources, you will be able to select
them as a source for your graph as depicted below.

![Configure a device query](assets/astarte-grafana-device-query.png)

You will then be able to choose which device and interface data should be retrieved from.

## Data manipulation

Grafana offers data-aggregation features, for more information check the official
[Grafana documentation](https://grafana.com/docs/grafana/latest/panels/transformations)
