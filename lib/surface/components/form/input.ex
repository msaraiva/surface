defmodule Surface.Components.Form.Input do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Surface.Component

      alias Surface.Components.Form.Input.InputContext

      @doc "An identifier for the form"
      prop form, :form

      @doc "An identifier for the input"
      prop field, :atom

      @doc "Value to pre-populated the input"
      prop value, :string

      @doc "Class or classes to apply to the input"
      prop class, :css_class

      @doc "Options list"
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

      @default_class get_config(:default_class) || get_config(unquote(__MODULE__), :default_class)
    end
  end

  defmodule InputContext do
    use Surface.Component

    @doc "The assigns of the host component"
    prop assigns, :map

    slot default, props: [:form, :field]

    def render(assigns) do
      ~H"""
      <Context
        get={{ Surface.Components.Form, form: form }}
        get={{ Surface.Components.Form.Field, field: field }}>
        <slot :props={{ form: @assigns[:form] || form, field: @assigns[:field] || field }}/>
      </Context>
      """
    end
  end
end
