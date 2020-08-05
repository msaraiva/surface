defmodule Surface.Directive.Debug do
  use Surface.Directive

  def extract({":debug", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :debug,
      value: directive_value(value, Map.merge(meta, expr_meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract({":debug", _, attr_meta}, meta) do
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :debug,
      value: %AST.AttributeExpr{
        original: "",
        value: [:code],
        meta: attr_meta
      },
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.AttributeExpr{value: debug}}, node) do
    node = %{node | debug: Keyword.merge(node.debug || [], debug)}

    if Enum.member?(node.debug, :ast) do
      IO.puts(">>> DEBUG(AST): #{node.meta.file}:#{node.meta.line}")
      IO.puts(inspect(node, pretty: true))
      IO.puts("<<<")
    end

    node
  end

  defp directive_value(value, meta) do
    expr =
      case Helpers.attribute_expr_to_quoted!(value, :debug, :bindings, meta) do
        value when is_atom(value) ->
          [value]

        list when is_list(list) ->
          list

        _ ->
          invalid_debug_value(value, meta)
      end

    for name <- expr do
      if not is_atom(name) do
        invalid_debug_value(value, meta)
      end
    end

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end

  defp invalid_debug_value(value, meta) do
    message = """
    invalid value for directive :debug. Expected a list of atoms, \
    got: #{String.trim(value)}.\
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end
end
