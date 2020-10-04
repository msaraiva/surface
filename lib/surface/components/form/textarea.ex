defmodule Surface.Components.Form.TextArea do
  @moduledoc """
  An input field that let the user enter a **multi-line** text.

  Provides a wrapper for Phoenix.HTML.Form's `textarea/3` function.

  All options passed via `opts` will be sent to `textarea/3`. Explicitly
  defined properties like `value` and `class` can be set directly and will
  override anything in `opts`.

  ## Examples

  ```
  <TextArea form="user" field="summary" cols="5" rows="10" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [textarea: 3]
  import Surface.Components.Form.Utils

  @doc "Specifies the visible number of lines in a text area"
  prop rows, :string

  @doc "Specifies the visible width of a text area"
  prop cols, :string

  def render(assigns) do
    props = get_non_nil_props(assigns, [:value, :rows, :cols, class: @default_class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ textarea(form, field, props ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
