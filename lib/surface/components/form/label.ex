defmodule Surface.Components.Form.Label do
  @moduledoc """
  Generates a label.

  Provides a wrapper for Phoenix.HTML.Form's `label/3` function.

  All options passed via `opts` will be sent to `label/3`, `class` can
  be set directly and will override anything in `opts`.
  """

  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.Field

  import Phoenix.HTML.Form, only: [label: 4]
  import Surface.Components.Form.Utils

  @doc "The form identifier"
  property form, :form

  @doc "The field name"
  property field, :string

  @doc "The CSS class for the underlying tag"
  property class, :css_class

  @doc "Options list"
  property opts, :keyword, default: []

  context get form, from: Form, as: :form_context
  context get field, from: Field, as: :field_context

  @doc """
  The content for the label
  """
  slot default

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:class])
    children = ~H"<slot>{{ Phoenix.Naming.humanize(field) }}</slot>"

    ~H"""
    {{ label(form, field, props ++ @opts, do: children) }}
    """
  end
end
