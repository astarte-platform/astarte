defmodule Astarte.Export.XMLGenerate do
  def xml_write_default_header(fd) do
    {:ok, _doc, state} = XMLStreamWriter.new_document()
    {:ok, header, state} = XMLStreamWriter.start_document(state)
    IO.puts(fd, header)
    {:ok, state}
  end

  def xml_write_empty_element(fd, {tag, attributes, []}, state) do
    {:ok, empty_tag, state} = XMLStreamWriter.empty_element(state, tag, attributes)
    IO.puts(fd, empty_tag)
    {:ok, state}
  end

  def xml_write_full_element(fd, {tag, attributes, value}, state) do
    if is_list(value) do
      {:ok, start_tag, state} = XMLStreamWriter.start_element(state, tag, attributes)
      IO.puts(fd, start_tag)

      Enum.each(value, fn element ->
        {:ok, element_start, state} = XMLStreamWriter.start_element(state, "element", [])
        {:ok, element_data, state} = XMLStreamWriter.characters(state, to_string(element))
        {:ok, element_end, state} = XMLStreamWriter.end_element(state)
        IO.puts(fd, [element_start, element_data, element_end])
      end)

      {:ok, end_tag, state} = XMLStreamWriter.end_element(state)
      IO.puts(fd, end_tag)
      {:ok, state}
    else
      {:ok, start_tag, state} = XMLStreamWriter.start_element(state, tag, attributes)
      {:ok, data, state} = XMLStreamWriter.characters(state, to_string(value))
      {:ok, end_tag, state} = XMLStreamWriter.end_element(state)
      xml_data = [start_tag, data, end_tag]
      IO.puts(fd, xml_data)
      {:ok, state}
    end
  end

  def xml_write_start_tag(fd, {tag, attributes}, state) do
    {:ok, start_tag, state} = XMLStreamWriter.start_element(state, tag, attributes)
    IO.puts(fd, start_tag)
    {:ok, state}
  end

  def xml_write_end_tag(fd, state) do
    {:ok, end_tag, state} = XMLStreamWriter.end_element(state)
    IO.puts(fd, end_tag)
    {:ok, state}
  end
end
