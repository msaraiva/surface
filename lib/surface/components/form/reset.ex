defmodule Surface.Components.Form.Reset do
  @moduledoc """
  Defines a reset button.

  Provides a wrapper for Phoenix.HTML.Form's `reset/2` function.

  All options passed via `opts` will be sent to `reset/2`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <Reset value="Reset" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [reset: 2]
  import Surface.Components.Form.Utils

  @doc "Value to pre-populated the input"
  prop value, :string, default: "Reset"

  @doc "Class or classes to apply to the input"
  prop class, :css_class

  @doc "Keyword list with options to be passed down to `reset/2`"
  prop opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  prop blur, :event

  @doc "Triggered when the component receives focus"
  prop focus, :event

  @doc "Triggered when the component receives click"
  prop capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  prop keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  prop keyup, :event

  def render(assigns) do
    props = get_non_nil_props(assigns, [:class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ reset(assigns[:value], props ++ @opts ++ event_opts)}}
    """
  end
end
