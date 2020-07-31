defmodule Surface.Compiler.Helpers do
  alias Surface.AST
  alias Surface.Compiler.CompileMeta
  alias Surface.IOHelper

  def interpolation_to_quoted!(text, meta) do
    with {:ok, expr} <- Code.string_to_quoted(text, file: meta.file, line: meta.line),
         :ok <- validate_interpolation(expr, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(error <> token, meta.file, line)

      {:error, message} ->
        IOHelper.compile_error(message, meta.file, meta.line - 1)

      _ ->
        IOHelper.syntax_error(
          "invalid interpolation '#{text}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, :css_class, meta) do
    with {:ok, expr} <-
           Code.string_to_quoted("Surface.css_class(#{value})", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, :css_class, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid css class expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid css class expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, type, meta) when type in [:keyword, :list, :map, :event] do
    with {:ok, {:identity, _, expr}} <-
           Code.string_to_quoted("identity(#{value})", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, type, meta) do
      if Enum.count(expr) == 1 do
        Enum.at(expr, 0)
      else
        expr
      end
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid #{to_string(type)} expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid #{to_string(type)} expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, :generator, meta) do
    with {:ok, {:for, _, expr}} when is_list(expr) <-
           Code.string_to_quoted("for #{value}", line: meta.line, file: meta.file),
         :ok <- validate_attribute_expression(expr, :generator, meta) do
      expr
    else
      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )

      # Once we do validation
      # {:error, message} ->
      #   IOHelper.syntax_error(
      #     "invalid generator expression '#{value}' (#{message})",
      #     meta.file,
      #     meta.line
      #   )

      _ ->
        IOHelper.syntax_error(
          "invalid generator expression '#{value}'",
          meta.file,
          meta.line
        )
    end
  end

  def attribute_expr_to_quoted!(value, _type, meta) do
    case Code.string_to_quoted(value, line: meta.line, file: meta.file) do
      {:ok, expr} ->
        expr

      {:error, {line, error, token}} ->
        IOHelper.syntax_error(
          error <> token,
          meta.file,
          line
        )
    end
  end

  def validate_attribute_expression(_expr, _, _meta) do
    # TODO: Add any validation here
    :ok
  end

  defp validate_interpolation({:@, _, [{:inner_content, _, args}]}, _meta) when is_list(args) do
    {:error,
     """
     the `inner_content` anonymous function should be called using \
     the dot-notation. Use `@inner_content.([])` instead of `@inner_content([])`\
     """}
  end

  defp validate_interpolation({{:., _, dotted_args} = expr, metadata, args} = expression, meta) do
    if List.last(dotted_args) == :inner_content and !Keyword.get(metadata, :no_parens, false) do
      bad_str = Macro.to_string(expression)

      args = if Enum.empty?(args), do: [args], else: args

      # This constructs the syntax tree for dot-notation access to the inner_content function
      replacement_str =
        Macro.to_string(
          {{:., [line: meta.line, file: meta.file],
            [{expr, Keyword.put(metadata, :no_parens, true), []}]},
           [line: meta.line, file: meta.file], args}
        )

      {:error,
       """
       the `inner_content` anonymous function should be called using \
       the dot-notation. Use `#{replacement_str}` instead of `#{bad_str}`\
       """}
    else
      [expr | args]
      |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
      |> Enum.find(:ok, &match?({:error, _}, &1))
    end
  end

  defp validate_interpolation({func, _, args}, meta) when is_atom(func) and is_list(args) do
    args
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation({func, _, args}, _meta) when is_atom(func) and is_atom(args),
    do: :ok

  defp validate_interpolation({func, _, args}, meta) when is_tuple(func) and is_list(args) do
    [func | args]
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation({func, _, args}, meta) when is_tuple(func) and is_atom(args) do
    validate_interpolation(func, meta)
  end

  defp validate_interpolation(expr, meta) when is_tuple(expr) do
    expr
    |> Tuple.to_list()
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation(expr, meta) when is_list(expr) do
    expr
    |> Enum.map(fn arg -> validate_interpolation(arg, meta) end)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp validate_interpolation(_expr, _meta), do: :ok

  def to_meta(%{line: line} = tree_meta, %CompileMeta{
        line_offset: offset,
        file: file,
        caller: caller
      }) do
    AST.Meta
    |> Kernel.struct(tree_meta)
    |> Map.put(:line, line + offset)
    |> Map.put(:line_offset, offset)
    |> Map.put(:file, file)
    |> Map.put(:caller, caller)
  end

  def to_meta(%{line: line} = tree_meta, %AST.Meta{line_offset: offset} = parent_meta) do
    parent_meta
    |> Map.merge(tree_meta)
    |> Map.put(:line, line + offset)
  end

  def did_you_mean(target, list) do
    Enum.reduce(list, {nil, 0}, &max_similar(&1, to_string(target), &2))
  end

  defp max_similar(source, target, {_, current} = best) do
    score = source |> to_string() |> String.jaro_distance(target)
    if score < current, do: best, else: {source, score}
  end

  def list_to_string(_singular, _plural, []) do
    ""
  end

  def list_to_string(singular, _plural, [item]) do
    "#{singular} #{inspect(item)}"
  end

  def list_to_string(_singular, plural, items) do
    [last | rest] = items |> Enum.map(&inspect/1) |> Enum.reverse()
    "#{plural} #{rest |> Enum.reverse() |> Enum.join(", ")} and #{last}"
  end

  def is_blank_or_empty(%AST.Text{value: value}),
    do: Surface.Translator.ComponentTranslatorHelper.blank?(value)

  def is_blank_or_empty(%AST.Template{children: children}),
    do: Enum.all?(children, &is_blank_or_empty/1)

  def is_blank_or_empty(_node), do: false

  def actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)

    case Macro.expand(ast, env) do
      mod when is_atom(mod) ->
        {:ok, mod}

      _ ->
        {:error, "#{mod_str} is not a valid module name"}
    end
  end

  def check_module_loaded(module, mod_str) do
    case Code.ensure_compiled(module) do
      {:module, mod} ->
        {:ok, mod}

      {:error, _reason} ->
        {:error, "module #{mod_str} could not be loaded"}
    end
  end

  def check_module_is_component(module, mod_str) do
    if function_exported?(module, :translator, 0) do
      {:ok, module}
    else
      {:error, "module #{mod_str} is not a component"}
    end
  end

  def module_name(name, caller) do
    with {:ok, mod} <- actual_module(name, caller),
         {:ok, mod} <- check_module_loaded(mod, name) do
      check_module_is_component(mod, name)
    end
  end
end
