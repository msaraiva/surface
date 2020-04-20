defmodule Surface.Components.Form.Submit do
  @moduledoc """
  Generates a submit button to send the form.

  All options are forwarded to the underlying `Phoenix.HTML.Form.submit/3`
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [submit: 2]

  @doc "The label to be used in the button"
  property label, :string

  @doc "Class or classes to apply to the button"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `submit/3`"
  property opts, :keyword, default: []

  @doc "Slot used for having children other than plain text in the button"
  slot default

  def render(assigns) do
    children = ~H"<slot>{{ @label }}</slot>"

    ~H"""
    {{
      submit [class: @class] ++ @opts, do: children
    }}
    """
  end
end
