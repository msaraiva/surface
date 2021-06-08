defmodule Surface.MacroComponentTest do
  use Surface.ConnCase

  defmodule Upcase do
    use Surface.MacroComponent

    prop class, :css_class

    slot default

    def expand(attributes, children, meta) do
      # String
      content = children |> List.to_string() |> String.trim() |> String.upcase()
      title = "Some title"

      # Boolean
      disabled = true
      hidden = false

      # Integer
      tabindex = 1

      # AST
      id = %Surface.AST.Literal{value: "123"}
      class = Surface.AST.find_attribute_value(attributes, :class) || ""

      # AST generated by `quote_surface`
      span =
        quote_surface do
          ~F"""
          <span
            title={^title}
            disabled={^disabled}
            hidden={^hidden}
            tabindex={^tabindex}
            id={^id}
            class={^class}
          >
            {^content}
          </span>
          """
        end

      quote_surface do
        ~F"""
        <div>
        {^span}
        </div>
        """
      end
    end
  end

  test "parses its own content" do
    html =
      render_surface do
        ~F"""
        <#Upcase>
          This text is not parsed by Surface. The following should not be translated:
            - {no interpolation}
            - `</#Surface.Components.Raw>`
        </#Upcase>
        """
      end

    assert html =~ ~r"""
           <div>
           <span (.+)>
             THIS TEXT IS NOT PARSED BY SURFACE. THE FOLLOWING SHOULD NOT BE TRANSLATED:
               - {NO INTERPOLATION}
               - `</#SURFACE.COMPONENTS.RAW>`
           </span>
           </div>
           """
  end

  test "generates attributes from strings, booleans, integers and AST" do
    assigns = %{class: "some_class"}

    html =
      render_surface do
        ~F"""
        <#Upcase>
          content
        </#Upcase>
        """
      end

    assert html =~ """
           <div>
           <span title="Some title" disabled tabindex="1" id="123">
             CONTENT
           </span>
           </div>
           """
  end

  test "accept attributes values passed as dynamic expressions" do
    assigns = %{class: "some_class"}

    html =
      render_surface do
        ~F"""
        <#Upcase class={@class}>
          content
        </#Upcase>
        """
      end

    assert html =~ ~r"""
           <div>
           <span (.+) class="some_class">
             CONTENT
           </span>
           </div>
           """
  end

  test "errors in dynamic expressions are reported at the right line" do
    code =
      quote do
        ~F"""
        <#Upcase
          class={,}
        >
          content
        </#Upcase>
        """
      end

    assert_raise(SyntaxError, ~r/code:2: syntax error before: ','/, fn ->
      compile_surface(code)
    end)
  end
end
