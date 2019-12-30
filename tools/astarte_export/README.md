# astarte_export

Astarte Export is an easy to use tool that allows to exporting all the devices and data from an existing Astarte realm to XML format.





```iex
ex(astarte_export@127.0.0.1)2> Astarte.Export.export_realm_data("test", "/home/harika/MyApplication/final_package/astarte_export-master/_build/dev/rel/astarte_export")
8:45:23.131     |INFO | Export started.                                         | module=Elixir.Astarte.Export function=generate_xml/2 realm=test
8:45:23.146     |INFO | Connected to database.                                  | module=Elixir.Astarte.Export function=get_value/2 realm=test 
8:45:23.236     |INFO | Extracted devices information from realm                | module=Elixir.Astarte.Export function=get_value/2 realm=test 
8:45:23.489     |INFO | XML Seralization completed                              | module=Elixir.Astarte.Export function=generate_xml/2 realm=test
8:45:23.490     |INFO | Export completed into file: /home/harika/MyApplication/final_package/astarte_export-master/_build/dev/rel/astarte_export/test_2019_12_30_8_45_23.xml    | module=Elixir.Astarte.Export function=generate_xml/2 realm=test
:ok
iex(astarte_export@127.0.0.1)3>
```


