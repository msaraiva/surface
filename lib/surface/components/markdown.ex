defmodule Surface.Components.Markdown do
  @moduledoc """
  A simple macro component that converts **markdown** into **HTML** at compile-time.

  ## Global configuration (optional)

  A set of global options you can set in `config.exs`. Available options are:

    * `default_class` - The default CSS class for the wrapping `<div>`. It
    can be overridden using propety `class`.

    * `default_opts` - The default set of options to be passed down to `Earmark.as_html/2`.
    It can be overridden using propety `opts`.

  ## CSS Styling

  Some CSS libs define their own styles for tags like `<p>`, `<ul>`, `<ol>`, `<strong>`,
  `<h1>` to `<h6>`, etc. This can make the rendered HTML look different from what you
  expect. One way to fix that is to customize the CSS class on the outer `<div>` of the
  generated code.

  For instance, in `Bulma`, you can use the class `content` to handle WYSIWYG content
  like the HTML generated by the Markdown component.

  You can have a default class applied globally using the `default_class` config:

  ```
  config :surface, :components, [
    {Surface.Components.Markdown, default_class: "content"}
  ]
  ```

  Or you can set/override it individually for each `<#Markdown>` instance using
  the `class` property.
  """

  use Surface.MacroComponent

  alias Surface.MacroComponent
  alias Surface.IOHelper

  @doc "The CSS class for the wrapping `<div>`"
  property class, :string

  @doc "Removes the wrapping `<div>`, if `true`"
  property unwrap, :boolean, default: false

  @doc """
  Keyword list with options to be passed down to `Earmark.as_html/2`.

  For a full list of available options, please refer to the
  [Earmark.as_html/2](https://hexdocs.pm/earmark/Earmark.html#as_html/2)
  documentation.
  """
  property opts, :keyword, default: []

  @doc "The markdown text to be translated to HTML"
  slot default

  @impl true
  def translate({_, attributes, children, %{line: tag_line}}, caller) do
    props = MacroComponent.eval_static_props!(__MODULE__, attributes, caller)
    class = props[:class] || get_config(:default_class)
    unwrap = props[:unwrap] || false
    config_opts = get_config(:default_opts) || []
    opts = Keyword.merge(config_opts, props[:opts] || [])

    html =
      children
      |> IO.iodata_to_binary()
      |> trim_leading_space()
      |> markdown_as_html!(caller, tag_line, opts)

    class_attr = if class, do: ~s( class="#{class}"), else: ""

    {open_div, close_div} =
      if unwrap do
        {[], []}
      else
        {"<div#{class_attr}>\n", "</div>"}
      end

    open = [
      "<% require(#{inspect(__MODULE__)}) %>",
      open_div
    ]

    close = [close_div]

    {open, html, close}
  end

  def expand(attributes, children, meta) do
    props = MacroComponent.eval_static_props!(__MODULE__, attributes, meta.caller)
    class = props[:class] || get_config(:default_class)
    unwrap = props[:unwrap] || false
    config_opts = get_config(:default_opts) || []
    opts = Keyword.merge(config_opts, props[:opts] || [])

    html =
      children
      |> IO.iodata_to_binary()
      |> trim_leading_space()
      # Need to reconstruct the relative line
      |> markdown_as_html!(meta.caller, meta.line, opts)

    node = %Surface.AST.Text{value: html}

    cond do
      unwrap ->
        node

      class ->
        %Surface.AST.Tag{
          element: "div",
          directives: [],
          attributes: [
            %Surface.AST.Attribute{
              name: "class",
              value: %Surface.AST.Text{value: class}
            }
          ],
          children: [node],
          meta: meta
        }

      true ->
        %Surface.AST.Tag{
          element: "div",
          directives: [],
          attributes: [],
          children: [node],
          meta: meta
        }
    end
  end

  defp trim_leading_space(markdown) do
    lines =
      markdown
      |> String.split("\n")
      |> Enum.drop_while(fn str -> String.trim(str) == "" end)

    case lines do
      [first | _] ->
        [space] = Regex.run(~r/^\s*/, first)

        lines
        |> Enum.map(fn line -> String.replace_prefix(line, space, "") end)
        |> Enum.join("\n")

      _ ->
        ""
    end
  end

  defp markdown_as_html!(markdown, caller, tag_line, opts) do
    markdown
    |> Earmark.as_html(struct(Earmark.Options, opts))
    |> handle_result!(caller, tag_line)
  end

  defp handle_result!({_, html, messages}, caller, tag_line) do
    {errors, warnings_and_deprecations} =
      Enum.split_with(messages, fn {type, _line, _message} -> type == :error end)

    Enum.each(warnings_and_deprecations, fn {_type, line, message} ->
      actual_line = tag_line + line - 1
      IOHelper.warn(message, caller, fn _ -> actual_line end)
    end)

    if errors != [] do
      [{_type, line, message} | _] = errors
      actual_line = tag_line + line - 1
      IOHelper.compile_error(message, caller.file, actual_line)
    end

    html
  end
end
