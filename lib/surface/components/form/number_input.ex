defmodule Surface.Components.Form.NumberInput do
  @moduledoc """
  An input field that let the user to enter a **number**.

  Provides a wrapper for Phoenix.HTML.Form's `number_input/3` function.

  All options passed via `opts` will be sent to `number_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <NumberInput form="user" field="age" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [number_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    props = get_non_nil_props(assigns, [:value, class: @default_class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ number_input(form, field, props ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
