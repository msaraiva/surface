defmodule Surface.Compiler.ParserTest do
  use ExUnit.Case, async: true

  import Surface.Compiler.Parser
  alias Surface.Compiler.ParseError

  test "empty node" do
    assert parse!("") == []
  end

  test "only text" do
    assert parse!("Some text") == ["Some text"]
  end

  test "keep spaces before node" do
    assert parse!("\n<div></div>") ==
             [
               "\n",
               {"div", [], [], %{line: 2, file: "nofile", column: 2}}
             ]
  end

  test "keep spaces after node" do
    assert parse!("<div></div>\n") ==
             [
               {"div", [], [], %{line: 1, file: "nofile", column: 2}},
               "\n"
             ]
  end

  test "keep blank chars" do
    assert parse!("\n\r\t\v\b\f\e\d\a") == ["\n\r\t\v\b\f\e\d\a"]
  end

  test "multiple nodes" do
    code = """
    <div>
      Div 1
    </div>
    <div>
      Div 2
    </div>
    """

    assert parse!(code) ==
             [
               {"div", [], ["\n  Div 1\n"], %{line: 1, file: "nofile", column: 2}},
               "\n",
               {"div", [], ["\n  Div 2\n"], %{line: 4, file: "nofile", column: 2}},
               "\n"
             ]
  end

  test "text before and after" do
    assert parse!("hello<foo>bar</foo>world") ==
             ["hello", {"foo", [], ["bar"], %{line: 1, file: "nofile", column: 7}}, "world"]
  end

  test "component" do
    code = ~S(<MyComponent label="My label"/>)
    [node] = parse!(code)

    assert node ==
             {"MyComponent",
              [
                {"label", "My label", %{line: 1, file: "nofile", column: 14}}
              ], [], %{line: 1, file: "nofile", column: 2}}
  end

  test "slot shorthand" do
    code = ~S(<:footer :let={ a: 1 }/>)
    [node] = parse!(code)

    assert {":footer", [{":let", _, _}], [], _} = node
  end

  test "spaces and line break between children" do
    code = """
    <div>
      <span/> <span/>
      <span/>
    </div>
    """

    tree = parse!(code)

    assert tree == [
             {
               "div",
               '',
               [
                 "\n  ",
                 {"span", '', '', %{line: 2, file: "nofile", column: 4}},
                 " ",
                 {"span", [], [], %{line: 2, file: "nofile", column: 12}},
                 "\n  ",
                 {"span", [], [], %{line: 3, file: "nofile", column: 4}},
                 "\n"
               ],
               %{line: 1, file: "nofile", column: 2}
             },
             "\n"
           ]
  end

  test "comments" do
    code = """
    <div>
    <!--
    This is
    a comment
    -->
      <span/>
    </div>
    """

    [{"div", _, [_, {:comment, comment}, _, {"span", _, _, _}, _], _}, _] = parse!(code)

    assert comment == """
           <!--
           This is
           a comment
           -->\
           """
  end

  describe "void elements" do
    test "without attributes" do
      code = """
      <div>
        <hr>
      </div>
      """

      [{"div", [], ["\n  ", node, "\n"], _}, "\n"] = parse!(code)
      assert node == {"hr", [], [], %{line: 2, file: "nofile", column: 4, void_tag?: true}}
    end

    test "with attributes" do
      code = """
      <div>
        <img
          src="file.gif"
          alt="My image"
        >
      </div>
      """

      [{"div", [], ["\n  ", node, "\n"], _}, "\n"] = parse!(code)

      assert node ==
               {"img",
                [
                  {"src", "file.gif", %{line: 3, file: "nofile", column: 5}},
                  {"alt", "My image", %{line: 4, file: "nofile", column: 5}}
                ], [], %{line: 2, file: "nofile", column: 4, void_tag?: true}}
    end
  end

  describe "HTML only" do
    test "single node" do
      assert parse!("<foo>bar</foo>") ==
               [{"foo", [], ["bar"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "Elixir node" do
      assert parse!("<Foo.Bar>bar</Foo.Bar>") ==
               [{"Foo.Bar", [], ["bar"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "mixed nodes" do
      assert parse!("<foo>one<bar>two</bar>three</foo>") ==
               [
                 {"foo", [],
                  ["one", {"bar", [], ["two"], %{line: 1, file: "nofile", column: 10}}, "three"],
                  %{line: 1, file: "nofile", column: 2}}
               ]
    end

    test "self-closing nodes" do
      assert parse!("<foo>one<bar><bat/></bar>three</foo>") ==
               [
                 {"foo", [],
                  [
                    "one",
                    {"bar", [], [{"bat", [], [], %{line: 1, file: "nofile", column: 15}}],
                     %{line: 1, file: "nofile", column: 10}},
                    "three"
                  ], %{line: 1, file: "nofile", column: 2}}
               ]
    end
  end

  describe "interpolation" do
    test "as root" do
      assert parse!("{baz}") ==
               [{:interpolation, "baz", %{line: 1, file: "nofile", column: 2}}]
    end

    test "with curlies embedded" do
      assert parse!("{ {1, 3} }") ==
               [{:interpolation, " {1, 3} ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "with deeply nested curlies" do
      assert parse!("{{{{{{{{{{{}}}}}}}}}}}") ==
               [{:interpolation, "{{{{{{{{{{}}}}}}}}}}", %{line: 1, file: "nofile", column: 2}}]
    end

    test "matched curlies for a map expression" do
      assert parse!("{ %{a: %{b: 1}} }") ==
               [{:interpolation, " %{a: %{b: 1}} ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "tuple without spaces between enclosing curlies" do
      assert parse!("{{:a, :b}}") ==
               [{:interpolation, "{:a, :b}", %{line: 1, file: "nofile", column: 2}}]
    end

    test "without root node but with text" do
      assert parse!("foo {baz} bar") ==
               ["foo ", {:interpolation, "baz", %{line: 1, file: "nofile", column: 6}}, " bar"]
    end

    test "with root node" do
      assert parse!("<foo>{baz}</foo>") ==
               [
                 {"foo", '', [{:interpolation, "baz", %{line: 1, file: "nofile", column: 7}}],
                  %{line: 1, file: "nofile", column: 2}}
               ]
    end

    test "mixed curly bracket" do
      assert parse!("<foo>bar{baz}bat</foo>") ==
               [
                 {"foo", '',
                  [
                    "bar",
                    {:interpolation, "baz", %{line: 1, file: "nofile", column: 10}},
                    "bat"
                  ], %{line: 1, file: "nofile", column: 2}}
               ]
    end

    #  test "single-closing curly bracket" do
    #    assert parse!("<foo>bar{ 'a}b' }bat</foo>") ==
    #
    #              [
    #                {"foo", [], ["bar", {:interpolation, " 'a}b' ", %{line: 1}}, "bat"],
    #                 %{line: 1}}
    #              ]
    #  end

    #  test "charlist with closing curly in tuple" do
    #    assert parse!("{{ 'a}}b' }}") ==
    #              [{:interpolation, " 'a}}b' ", %{line: 1}}]
    #  end

    #   test "binary with closing curly in tuple" do
    #     assert parse!("{{ {{'a}}b'}} }}") ==
    #               [{:interpolation, " {{'a}}b'}} ", %{line: 1}}]
    #   end

    #   test "double closing curly brace inside charlist" do
    #     assert parse!("{{ {{\"a}}b\"}} }}") ==
    #               [{:interpolation, " {{\"a}}b\"}} ", %{line: 1}}]
    #   end

    #   test "double closing curly brace inside binary" do
    #     assert parse!("{{ \"a}}b\" }}") ==
    #               [{:interpolation, " \"a}}b\" ", %{line: 1}}]
    #   end

    #   test "single-opening curly bracket inside single quotes" do
    #     assert parse!("{{ 'a{b' }}") ==
    #               [{:interpolation, " 'a{b' ", %{line: 1}}]
    #   end

    #   test "single-opening curly bracket inside double quotes" do
    #     assert parse!("{{ \"a{b\" }}") ==
    #               [{:interpolation, " \"a{b\" ", %{line: 1}}]
    #   end

    test "containing a charlist with escaped single quote" do
      assert parse!("{ 'a\\'b' }") ==
               [{:interpolation, " 'a\\'b' ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "containing a binary with escaped double quote" do
      assert parse!("{ \"a\\\"b\" }") ==
               [{:interpolation, " \"a\\\"b\" ", %{line: 1, file: "nofile", column: 2}}]
    end

    test "nested multi-element tuples" do
      assert parse!("""
             { {a, {b, c}} <- [{"a", {"b", "c"}}]}
             """) ==
               [
                 {:interpolation, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]",
                  %{line: 1, file: "nofile", column: 2}},
                 "\n"
               ]
    end
  end

  describe "with macros" do
    test "single node" do
      assert parse!("<#Foo>bar</#Foo>") ==
               [{"#Foo", [], ["bar"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "mixed nodes" do
      assert parse!("<#Foo>one<bar>two</baz>three</#Foo>") ==
               [{"#Foo", [], ["one<bar>two</baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "inner text has macro-like tag" do
      assert parse!("<#Foo>one<#bar>two</#baz>three</#Foo>") ==
               [
                 {"#Foo", [], ["one<#bar>two</#baz>three"], %{line: 1, file: "nofile", column: 2}}
               ]
    end

    test "inner text has only open tags (invalid html)" do
      assert parse!("<#Foo>one<bar>two<baz>three</#Foo>") ==
               [{"#Foo", [], ["one<bar>two<baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "inner text has all closing tags (invalid html)" do
      assert parse!("<#Foo>one</bar>two</baz>three</#Foo>") ==
               [{"#Foo", [], ["one</bar>two</baz>three"], %{line: 1, file: "nofile", column: 2}}]
    end

    test "self-closing macro" do
      assert parse!("<#Macro/>") ==
               [{"#Macro", '', [], %{line: 1, file: "nofile", column: 2}}]
    end

    test "keep track of the line of the definition" do
      code = """
      <div>
        one
        <#Foo>
          two
        </#Foo>
      </div>
      """

      [{_, _, children, _} | _] = parse!(code)
      {_, _, _, meta} = Enum.at(children, 1)
      assert meta.line == 3
    end

    test "do not perform interpolation for inner content" do
      assert parse!("<#Foo>one {@var} two</#Foo>") ==
               [{"#Foo", [], ["one {@var} two"], %{line: 1, file: "nofile", column: 2}}]
    end
  end

  describe "errors on" do
    test "expected tag name" do
      code = """
      text
      <>bar</>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      assert %ParseError{message: "expected tag name", line: 2} = exception
    end

    test "invalid closing tag" do
      code = "<foo>bar</a></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <foo> defined on line 1, got </a>"

      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for html node" do
      code = "<foo><bar></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <bar> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node" do
      code = "<foo><Bar></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for fully specified component node" do
      code = "<foo><Bar.Baz></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar.Baz> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node with number" do
      code = "<foo><Bar1></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar1> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for component node with underscore and number" do
      code = "<foo><Bar_1></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <Bar_1> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for html node with dash" do
      code = "<foo><bar-baz></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <bar-baz> defined on line 1, got </foo>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for macro component node" do
      code = "<foo><#Bar></foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <#Bar> defined on line 1, got EOF"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "missing closing tag for html node with surrounding text" do
      code = """
      <foo>
        text before
        <div attr1="1" attr="2">
        text after
      </foo>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <div> defined on line 3, got </foo>"
      assert %ParseError{message: ^message, line: 3} = exception
    end

    test "tag mismatch" do
      code = "<foo>bar</baz>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <foo> defined on line 1, got </baz>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "incomplete tag content" do
      code = "<foo>bar"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <foo> defined on line 1, got EOF"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "incomplete macro content" do
      code = "<#foo>bar</#bar>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing tag for <#foo> defined on line 1, got </#bar>"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "non-closing interpolation" do
      code = "<foo>{bar</foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing `}` for expression"
      assert %ParseError{message: ^message, line: 1} = exception
    end

    test "non-matched curlies inside interpolation" do
      code = "<foo>{bar { }</foo>"

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "expected closing `}` for expression"
      assert %ParseError{message: ^message, line: 1} = exception
    end
  end

  describe "attributes" do
    test "keep blank chars between attributes" do
      code = """
      <foo prop1="1"\n\r\t\fprop2="2"/>\
      """

      [{_, attributes, _, _}] = parse!(code)

      assert attributes == [
               {"prop1", "1", %{line: 1, file: "nofile", column: 6}},
               {"prop2", "2", %{line: 2, file: "nofile", column: 4}}
             ]
    end

    test "regular nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      >
        bar
        <div>{ var }</div>
      </foo>
      """

      attributes = [
        {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
        {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
      ]

      children = [
        "\n  bar\n  ",
        {"div", [], [{:interpolation, " var ", %{line: 6, file: "nofile", column: 9}}],
         %{line: 6, file: "nofile", column: 4}},
        "\n"
      ]

      assert parse!(code) ==
               [{"foo", attributes, children, %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "self-closing nodes" do
      code = """
      <foo
        prop1="value1"
        prop2="value2"
      />
      """

      attributes = [
        {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
        {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "macro nodes" do
      code = """
      <#foo
        prop1="value1"
        prop2="value2"
      >
        bar
      </#foo>
      """

      attributes = [
        {"prop1", "value1", %{line: 2, file: "nofile", column: 3}},
        {"prop2", "value2", %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"#foo", attributes, ["\n  bar\n"], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "regular nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "value 2"
        prop3 =
          { var3 }
        prop4
      ></foo>
      """

      attributes = [
        {"prop1", true, %{line: 2, file: "nofile", column: 3}},
        {"prop2", "value 2", %{line: 3, file: "nofile", column: 3}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5, file: "nofile", column: 6}},
         %{line: 4, file: "nofile", column: 3}},
        {"prop4", true, %{line: 6, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "self-closing nodes with whitespaces" do
      code = """
      <foo
        prop1
        prop2 = "2"
        prop3 =
          { var3 }
        prop4
      />
      """

      attributes = [
        {"prop1", true, %{line: 2, file: "nofile", column: 3}},
        {"prop2", "2", %{line: 3, file: "nofile", column: 3}},
        {"prop3", {:attribute_expr, " var3 ", %{line: 5, file: "nofile", column: 6}},
         %{line: 4, file: "nofile", column: 3}},
        {"prop4", true, %{line: 6, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "value as expression" do
      code = """
      <foo
        prop1={ var1 }
        prop2={ var2 }
      />
      """

      attributes = [
        {"prop1", {:attribute_expr, " var1 ", %{line: 2, file: "nofile", column: 10}},
         %{line: 2, file: "nofile", column: 3}},
        {"prop2", {:attribute_expr, " var2 ", %{line: 3, file: "nofile", column: 10}},
         %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "integer values" do
      code = """
      <foo
        prop1=1
        prop2=2
      />
      """

      attributes = [
        {"prop1", 1, %{line: 2, file: "nofile", column: 3}},
        {"prop2", 2, %{line: 3, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "boolean values" do
      code = """
      <foo
        prop1
        prop2=true
        prop3=false
        prop4
      />
      """

      attributes = [
        {"prop1", true, %{line: 2, file: "nofile", column: 3}},
        {"prop2", true, %{line: 3, file: "nofile", column: 3}},
        {"prop3", false, %{line: 4, file: "nofile", column: 3}},
        {"prop4", true, %{line: 5, file: "nofile", column: 3}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "string values" do
      code = """
      <foo prop="str"/>
      """

      attr_value = "str"

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "empty string" do
      code = """
      <foo prop=""/>
      """

      attr_value = ""

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    # test "string with embedded interpolation" do
    #   code = """
    #   <foo prop="before { var } after"/>
    #   """

    #   attr_value = ["before ", {:attribute_expr, " var ", %{line: 1}}, " after"]

    #   attributes = [
    #     {"prop", attr_value, %{line: 1}}
    #   ]

    #   assert parse!(code) ==  [{"foo", attributes, [], %{line: 1}}, "\n"]
    # end

    #   test "string with only an embedded interpolation" do
    #     code = """
    #     <foo prop="{ var }"/>
    #     """

    #     attr_value = [{:attribute_expr, " var ", %{line: 1}}]

    #     attributes = [
    #       {"prop", attr_value, %{line: 1}}
    #     ]

    #     assert parse!(code) ==  [{"foo", attributes, [], %{line: 1}}, "\n"]
    #   end

    test "interpolation with nested curlies" do
      code = """
      <foo prop={ {{}} }/>
      """

      attr_value = {:attribute_expr, " {{}} ", %{line: 1, file: "nofile", column: 12}}

      attributes = [
        {"prop", attr_value, %{line: 1, file: "nofile", column: 6}}
      ]

      assert parse!(code) ==
               [{"foo", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end

    test "attribute expression with nested tuples" do
      code = """
      <li :for={ {a, {b, c}} <- [{"a", {"b", "c"}}]} />
      """

      attr_value =
        {:attribute_expr, " {a, {b, c}} <- [{\"a\", {\"b\", \"c\"}}]",
         %{line: 1, file: "nofile", column: 11}}

      attributes = [
        {":for", attr_value, %{line: 1, file: "nofile", column: 5}}
      ]

      assert parse!(code) ==
               [{"li", attributes, [], %{line: 1, file: "nofile", column: 2}}, "\n"]
    end
  end

  describe "sub-blocks" do
    test "single sub-block" do
      code = """
      <#if {true}>
        1
      <#else>
        2
      </#if>\
      """

      assert parse!(code) ==
               [
                 {"#if",
                  [
                    {:root, {:attribute_expr, "true", %{line: 1, file: "nofile", column: 7}},
                     %{line: 1, file: "nofile", column: 7}}
                  ],
                  [
                    {:default, [], ["\n  1\n"], %{}},
                    {"#else", [], ["\n  2\n"], %{line: 3, file: "nofile", column: 2}}
                  ], %{line: 1, file: "nofile", column: 2, has_sub_blocks?: true}}
               ]
    end

    test "multiple sub-blocks" do
      code = """
      <#if {true}>
        1
      <#elseif>
        2
      <#elseif>
        3
      <#else>
        4
      </#if>\
      """

      assert parse!(code) ==
               [
                 {"#if",
                  [
                    {:root, {:attribute_expr, "true", %{line: 1, file: "nofile", column: 7}},
                     %{line: 1, file: "nofile", column: 7}}
                  ],
                  [
                    {:default, [], ["\n  1\n"], %{}},
                    {"#elseif", [], ["\n  2\n"], %{line: 3, file: "nofile", column: 2}},
                    {"#elseif", [], ["\n  3\n"], %{line: 5, file: "nofile", column: 2}},
                    {"#else", [], ["\n  4\n"], %{line: 7, file: "nofile", column: 2}}
                  ], %{line: 1, file: "nofile", column: 2, has_sub_blocks?: true}}
               ]
    end

    test "nested sub-blocks" do
      code = """
      <#if {1}>
        111
      <#elseif {2}>
        222
        <#if {3}>
          333
        <#else>
          444
        </#if>
      <#else>
        555
      </#if>\
      """

      assert parse!(code) ==
               [
                 {"#if",
                  [
                    {:root, {:attribute_expr, "1", %{line: 1, file: "nofile", column: 7}},
                     %{line: 1, file: "nofile", column: 7}}
                  ],
                  [
                    {:default, [], ["\n  111\n"], %{}},
                    {"#elseif",
                     [
                       {:root, {:attribute_expr, "2", %{line: 3, file: "nofile", column: 11}},
                        %{line: 3, file: "nofile", column: 11}}
                     ],
                     [
                       "\n  222\n  ",
                       {"#if",
                        [
                          {:root, {:attribute_expr, "3", %{line: 5, file: "nofile", column: 9}},
                           %{line: 5, file: "nofile", column: 9}}
                        ],
                        [
                          {:default, [], ["\n    333\n  "], %{}},
                          {"#else", [], ["\n    444\n  "], %{line: 7, file: "nofile", column: 4}}
                        ], %{has_sub_blocks?: true, line: 5, file: "nofile", column: 4}},
                       "\n"
                     ], %{line: 3, file: "nofile", column: 2}},
                    {"#else", [], ["\n  555\n"], %{line: 10, file: "nofile", column: 2}}
                  ], %{has_sub_blocks?: true, line: 1, file: "nofile", column: 2}}
               ]
    end

    test "handle invalid parents for #else" do
      code = """
      <div>
      <#else>
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message = "cannot use <#else> inside <div>. Possible parents are \"<#if>\" and \"<#for>\""
      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "handle invalid parents for #elseif" do
      code = """
      <div>
      <#elseif>
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message =
        "cannot use <#elseif> inside <div>. The <#elseif> construct can only be used inside a \"<#if>\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "handle invalid parents for #match" do
      code = """
      <div>
      <#match>
      </div>
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message =
        "cannot use <#match> inside <div>. The <#match> construct can only be used inside a \"<#case>\""

      assert %ParseError{message: ^message, line: 2} = exception
    end

    test "raise error on sub-blocks without parent node" do
      code = """
        1
      <#else>
        2
      """

      exception = assert_raise ParseError, fn -> parse!(code) end

      message =
        "no valid parent node defined for <#else>. Possible parents are \"<#if>\" and \"<#for>\""

      assert %ParseError{message: ^message, line: 2} = exception
    end
  end
end
