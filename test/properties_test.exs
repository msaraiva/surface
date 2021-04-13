defmodule Surface.PropertiesTest do
  use Surface.ConnCase, async: true

  defmodule StringProp do
    use Surface.Component

    prop label, :string

    def render(assigns) do
      ~H"""
      {{ @label }}
      """
    end
  end

  defmodule MapProp do
    use Surface.Component

    prop prop, :map

    def render(assigns) do
      ~H"""
      Map?: {{ is_map(@prop) }}
      <span :for={{ {k, v} <- @prop }}>key: {{k}}, value: {{v}}</span>
      """
    end
  end

  defmodule ListProp do
    use Surface.Component

    prop prop, :list

    def render(assigns) do
      ~H"""
      List?: {{ is_list(@prop) }}
      <span :for={{ v <- @prop }}>value: {{inspect(v)}}</span>
      """
    end
  end

  defmodule KeywordProp do
    use Surface.Component

    prop prop, :keyword

    def render(assigns) do
      ~H"""
      Keyword?: {{ Keyword.keyword?(@prop) }}
      <span :for={{ {k, v} <- @prop }}>key: {{k}}, value: {{v}}</span>
      """
    end
  end

  defmodule CSSClassProp do
    use Surface.Component

    prop prop, :css_class

    def render(assigns) do
      ~H"""
      <span class={{ @prop }}/>
      """
    end
  end

  defmodule CSSClassPropInspect do
    use Surface.Component

    prop prop, :css_class

    def render(assigns) do
      ~H"""
      <div :for={{ c <- @prop }}>{{ c }}</div>
      """
    end
  end

  defmodule AccumulateProp do
    use Surface.Component

    prop prop, :string, accumulate: true, default: ["default"]

    def render(assigns) do
      ~H"""
      List?: {{ is_list(@prop) }}
      <span :for={{ v <- @prop }}>value: {{v}}</span>
      """
    end
  end

  describe "string" do
    test "passing a string with interpolation" do
      assigns = %{a: 1, b: "two"}

      html =
        render_surface do
          ~H"""
          <StringProp label="begin {{ @a }} {{ @b }} end"/>
          """
        end

      assert html =~ "begin 1 two end"
    end
  end

  describe "keyword" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~H"""
          <KeywordProp prop={{ [option1: 1, option2: 2] }}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~H"""
          <KeywordProp prop={{ option1: 1, option2: 2 }}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list as an expression" do
      assigns = %{submit: [option1: 1, option2: 2]}

      html =
        render_surface do
          ~H"""
          <KeywordProp prop={{ @submit }}/>
          """
        end

      assert html =~ """
             Keyword?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~H"""
          <KeywordProp prop="some string"/>
          """
        end

      message =
        ~S(code:1: invalid value for property "prop". Expected a :keyword, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = """
      invalid value for property "prop". Expected a :keyword, got: 1.

      Original expression: {{ @var }}
      """

      assert_raise(RuntimeError, message, fn ->
        assigns = %{var: 1}

        render_surface do
          ~H"""
          <KeywordProp prop={{ @var }}/>
          """
        end
      end)
    end
  end

  describe "map" do
    test "passing a map" do
      html =
        render_surface do
          ~H"""
          <MapProp prop={{ %{option1: 1, option2: 2} }}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list" do
      html =
        render_surface do
          ~H"""
          <MapProp prop={{ [option1: 1, option2: 2] }}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~H"""
          <MapProp prop={{ option1: 1, option2: 2 }}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a map as an expression" do
      assigns = %{submit: %{option1: 1, option2: 2}}

      html =
        render_surface do
          ~H"""
          <MapProp prop={{ @submit }}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "passing a keyword list as an expression" do
      assigns = %{submit: [option1: 1, option2: 2]}

      html =
        render_surface do
          ~H"""
          <MapProp prop={{ @submit }}/>
          """
        end

      assert html =~ """
             Map?: true
             <span>key: option1, value: 1</span>\
             <span>key: option2, value: 2</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~H"""
          <MapProp prop="some string"/>
          """
        end

      message =
        ~S(code:1: invalid value for property "prop". Expected a :map, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = """
      invalid value for property "prop". Expected a :map, got: 1.

      Original expression: {{ @var }}
      """

      assert_raise(RuntimeError, message, fn ->
        assigns = %{var: 1}

        render_surface do
          ~H"""
          <MapProp prop={{ @var }}/>
          """
        end
      end)
    end
  end

  describe "list" do
    test "passing a list" do
      html =
        render_surface do
          ~H"""
          <ListProp prop={{ [1, 2] }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>\
             <span>value: 2</span>
             """
    end

    test "passing a list as an expression" do
      assigns = %{submit: [1, 2]}

      html =
        render_surface do
          ~H"""
          <ListProp prop={{ @submit }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>\
             <span>value: 2</span>
             """
    end

    test "passing a list with a single value as an expression" do
      assigns = %{submit: [1]}

      html =
        render_surface do
          ~H"""
          <ListProp prop={{ @submit }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: 1</span>
             """
    end

    test "passing a list without brackets is invalid" do
      code =
        quote do
          ~H"""
          <ListProp prop={{ 1, 2 }}/>
          """
        end

      message = ~S(code:1: invalid value for property "prop". Expected a :list, got: {{ 1, 2 }}.)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "passing a list with a single value without brackets is invalid" do
      message = "invalid value for property \"prop\". Expected a :list, got: 1"

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~H"""
          <ListProp prop={{ 1 }}/>
          """
        end
      end)
    end

    test "passing a keyword list" do
      html =
        render_surface do
          ~H"""
          <ListProp prop={{ [a: 1, b: 2] }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: {:a, 1}</span><span>value: {:b, 2}</span>
             """
    end

    test "passing a keyword list without brackets" do
      html =
        render_surface do
          ~H"""
          <ListProp prop={{ a: 1, b: 2 }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: {:a, 1}</span><span>value: {:b, 2}</span>
             """
    end

    test "validate invalid literals at compile-time" do
      code =
        quote do
          ~H"""
          <ListProp prop="some string"/>
          """
        end

      message =
        ~S(code:1: invalid value for property "prop". Expected a :list, got: "some string".)

      assert_raise(CompileError, message, fn ->
        compile_surface(code)
      end)
    end

    test "validate invalid values at runtime" do
      message = "invalid value for property \"prop\". Expected a :list, got: %{test: 1}"

      assert_raise(RuntimeError, message, fn ->
        render_surface do
          ~H"""
          <ListProp prop={{ %{test: 1} }}/>
          """
        end
      end)
    end
  end

  describe "css_class" do
    test "passing a string" do
      html =
        render_surface do
          ~H"""
          <CSSClassProp prop="class1 class2"/>
          """
        end

      assert html =~ """
             <span class="class1 class2"></span>
             """
    end

    test "passing a keywod list" do
      html =
        render_surface do
          ~H"""
          <CSSClassProp prop={{ [class1: true, class2: false, class3: "truthy"] }}/>
          """
        end

      assert html =~ """
             <span class="class1 class3"></span>
             """
    end

    test "passing a keywod list without brackets" do
      html =
        render_surface do
          ~H"""
          <CSSClassProp prop={{ class1: true, class2: false, class3: "truthy" }}/>
          """
        end

      assert html =~ """
             <span class="class1 class3"></span>
             """
    end

    test "trim class items" do
      html =
        render_surface do
          ~H"""
          <CSSClassProp prop={{ "", " class1 " , "", " ", "  ", " class2 class3 ", "" }}/>
          """
        end

      assert html =~ """
             <span class="class1 class2 class3"></span>
             """
    end

    test "values are always converted to a list of strings" do
      html =
        render_surface do
          ~H"""
          <CSSClassPropInspect prop="class1 class2   class3"/>
          """
        end

      assert html =~ """
             <div>class1</div><div>class2</div><div>class3</div>
             """

      html =
        render_surface do
          ~H"""
          <CSSClassPropInspect prop={{ ["class1"] ++ ["class2 class3", :class4, class5: true] }}/>
          """
        end

      assert html =~ """
             <div>class1</div><div>class2</div><div>class3</div><div>class4</div><div>class5</div>
             """
    end
  end

  describe "accumulate" do
    test "if true, groups all props with the same name in a single list" do
      html =
        render_surface do
          ~H"""
          <AccumulateProp prop="str_1" prop={{ "str_2" }}/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: str_1</span>\
             <span>value: str_2</span>
             """
    end

    test "if true and there's a single prop, it stills creates a list" do
      html =
        render_surface do
          ~H"""
          <AccumulateProp prop="str_1"/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: str_1</span>
             """
    end

    test "without any props, takes the default value" do
      html =
        render_surface do
          ~H"""
          <AccumulateProp/>
          """
        end

      assert html =~ """
             List?: true
             <span>value: default</span>
             """
    end
  end
end

defmodule Surface.PropertiesSyncTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO
  alias Surface.PropertiesTest.StringProp, warn: false

  test "raise error on the right line for string with interpolation" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "Surface.PropertiesTest_#{id}"

    code = """
    defmodule #{module} do
      use Elixir.Surface.Component

      def render(assigns) do
        ~H"\""
        <StringProp
          label="Undefined func {{ func }}"
        />
        "\""
      end
    end
    """

    error_message = "code.exs:7: undefined function func/0"

    output =
      capture_io(:standard_error, fn ->
        assert_raise(CompileError, error_message, fn ->
          {{:module, _, _, _}, _} =
            Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
        end)
      end)

    assert output =~ ~r/variable "func" does not exist/
    assert output =~ ~r"  code.exs:7"
  end

  test "warn if prop is required and has default value" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithRequiredAndDefaultProp_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      prop label, :string, default: "My Label", required: true

      def render(assigns) do
        ~H""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           setting a default value on a required prop has no effect. Either set the default value or set the prop as required, but not both.
             code.exs:4:\
           """
  end

  test "warn if props are specified multiple times, but accumulate is false" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentWithPropSpecifiedMultipleTimes_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component

      def render(assigns) do
        ~H"\""
        <StringProp
          label="first
          label" label="second label"
        />
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           The prop `label` has been passed multiple times. Considering only the last value.

           Hint: Either remove all redundant definitions or set option `accumulate` to `true`:

           ```
             prop label, :string, accumulate: true
           ```

           This way the values will be accumulated in a list.

             code.exs:8:\
           """
  end
end
